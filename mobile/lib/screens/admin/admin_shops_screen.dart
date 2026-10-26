import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import '../../repositories/shop_contact_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/admin/admin_shop_contacts.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

/// Matches src/pages/admin/Shops.jsx: list every shop with owner details and
/// approve / reject / suspend / reactivate actions.
///
/// Address and phone are loaded lazily, for the shops on screen only, through
/// the contact repository (admins may see them); they are never read from the
/// shop rows themselves.
class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

const _filters = <StatusFilter>[
  StatusFilter('pending', 'Pending'),
  StatusFilter('approved', 'Approved'),
  StatusFilter('suspended', 'Suspended'),
  StatusFilter('all', 'All'),
];

const _statusLabels = {
  'pending': 'Pending approval',
  'approved': 'Approved',
  'suspended': 'Suspended',
};

String _statusOf(AdminShopRow shop) => shop.status;

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  late final SellerQuery<List<AdminShopRow>> _query;
  final ShopContactsLoader _contacts = ShopContactsLoader();
  String? _filter;
  int _limit = kPageSize;
  String? _busyId;
  String? _busyStatus;

  @override
  void initState() {
    super.initState();
    _query = SellerQuery<List<AdminShopRow>>(fetchAdminShops);
  }

  @override
  void dispose() {
    _query.dispose();
    _contacts.dispose();
    super.dispose();
  }

  /// Asks for the contact details of the shops now on screen, after the frame
  /// (so the loader may notify without touching a build in progress).
  void _loadContactsFor(List<String> ids) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _contacts.ensure(ids);
    });
  }

  Future<bool> _confirm(AdminShopRow shop, String next) {
    if (next == 'suspended') {
      final rejecting = shop.status == 'pending';
      return confirmAction(
        context,
        title: rejecting ? 'Reject ${_nameOf(shop)}?' : 'Suspend ${_nameOf(shop)}?',
        message: rejecting
            ? 'This shop will not be approved. It is marked as suspended and can be reactivated later.'
            : 'The shop and its listings will no longer be visible to customers.',
        confirmLabel: rejecting ? 'Reject' : 'Suspend',
        destructive: true,
      );
    }
    if (next == 'approved' && !shop.hasAcceptedContract) {
      return confirmAction(
        context,
        title: 'Approve ${_nameOf(shop)}?',
        message: "This shop hasn't accepted the seller contract yet. Approve it anyway?",
        confirmLabel: 'Approve',
      );
    }
    return Future.value(true);
  }

  Future<void> _update(AdminShopRow shop, String next) async {
    if (_busyId != null) return;
    final confirmed = await _confirm(shop, next);
    if (!confirmed || !mounted) return;

    setState(() {
      _busyId = shop.id;
      _busyStatus = next;
    });
    // Guard on the status the card showed so a newer decision isn't overwritten.
    final failure = await updateRow('shops', shop.id, {'status': next}, match: {'status': shop.status});
    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, error: true);
      // The shop probably moved on (another admin, a trigger): show what is true now.
      if (failure == kNothingChanged) await _query.reload();
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _busyStatus = null;
      });
      return;
    }
    showSnack(
      context,
      next == 'approved'
          ? '${_nameOf(shop)} is approved.'
          : shop.status == 'pending'
              ? '${_nameOf(shop)} was rejected.'
              : '${_nameOf(shop)} is suspended.',
    );
    await _query.reload();
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _busyStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Shops',
      heading: 'Manage shops',
      subtitle: 'Approve, suspend, or reactivate shops on the platform.',
      onRefresh: _refresh,
      child: SellerQueryPanel<List<AdminShopRow>>(
        query: _query,
        what: 'shops',
        builder: (context, shops) {
          final pendingCount = shops.where((shop) => shop.status == 'pending').length;
          final active = _filter ?? (pendingCount > 0 ? 'pending' : 'all');
          final visible = applyStatusFilter(_filters, active, shops, _statusOf);
          final shown = math.min(_limit, visible.length);
          final onScreen = visible.take(shown).toList();
          _loadContactsFor([for (final shop in onScreen) shop.id]);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (shops.isNotEmpty) ...[
                FilterChipBar<String>(
                  options: filterOptions(_filters, shops, _statusOf),
                  selected: active,
                  onSelected: (value) => setState(() {
                    _filter = value;
                    _limit = kPageSize;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (shops.isEmpty)
                const CardBox(
                  child: EmptyState(
                    title: 'No shops yet',
                    description: 'Shops will appear here once sellers register.',
                  ),
                )
              else if (visible.isEmpty)
                const CardBox(
                  child: EmptyState(title: 'Nothing here', description: 'No shops match this filter.'),
                )
              else
                ListenableBuilder(
                  listenable: _contacts,
                  builder: (context, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final shop in onScreen)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ShopCard(
                            key: ValueKey(shop.id),
                            shop: shop,
                            contact: _contacts.contactFor(shop.id),
                            contactLoading: _contacts.isLoading(shop.id),
                            contactFailed: _contacts.hasFailed(shop.id),
                            onRetryContact: () => _contacts.retry(shop.id),
                            busyStatus: _busyId == shop.id ? _busyStatus : null,
                            locked: _busyId != null,
                            onUpdate: (next) => _update(shop, next),
                          ),
                        ),
                    ],
                  ),
                ),
              if (visible.isNotEmpty)
                LoadMoreButton(
                  shown: shown,
                  total: visible.length,
                  onPressed: () => setState(() => _limit += kPageSize),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    await _query.reload();
    if (!mounted) return;
    // Contact details may have changed too: forget them so the rebuild fetches
    // the shops on screen again.
    _contacts.reset();
    setState(() {});
  }
}

String _nameOf(AdminShopRow shop) => shop.name.isEmpty ? 'this shop' : shop.name;

class _ShopCard extends StatelessWidget {
  final AdminShopRow shop;
  final ShopContact? contact;
  final bool contactLoading;
  final bool contactFailed;
  final VoidCallback onRetryContact;

  /// The status being applied to this shop right now (null when idle).
  final String? busyStatus;

  /// True while any shop is being updated; all actions wait.
  final bool locked;
  final void Function(String status) onUpdate;

  const _ShopCard({
    super.key,
    required this.shop,
    required this.contact,
    required this.contactLoading,
    required this.contactFailed,
    required this.onRetryContact,
    required this.busyStatus,
    required this.locked,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final owner = [
      if (shop.ownerName.isNotEmpty) shop.ownerName,
      if (shop.ownerEmail.isNotEmpty) shop.ownerEmail,
    ].join(' · ');
    final version = shop.contractVersion;
    final contract = shop.hasAcceptedContract
        ? 'Accepted${version == null ? '' : ' v$version'} on ${formatOrderDate(shop.contractAcceptedAt!)}'
        : 'Not accepted yet';

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  shop.name.isEmpty ? 'Unnamed shop' : shop.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: shop.status, label: _statusLabels[shop.status] ?? titleCase(shop.status)),
            ],
          ),
          const SizedBox(height: 8),
          SellerMetaRow('Owner', text: owner.isEmpty ? 'Unknown owner' : owner),
          SellerMetaRow('License', text: shop.licenseNumber.isEmpty ? '–' : shop.licenseNumber),
          SellerMetaRow('Contract', text: contract),
          SellerMetaRow('Address', child: _contactValue(context, (c) => c.address, 'No address on file')),
          SellerMetaRow('Phone', child: _phoneValue(context)),
          SellerMetaRow('Registered', text: formatOrderDate(shop.createdAt)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions(),
          ),
        ],
      ),
    );
  }

  /// A contact line: "Loading…", a retry prompt, or the value (or [fallback]
  /// when the shop has none on file).
  Widget _contactValue(BuildContext context, String Function(ShopContact contact) read, String fallback) {
    final style = AppTheme.body(fontSize: 14);
    final softStyle = AppTheme.body(fontSize: 14, color: AppColors.inkSoft);
    final loaded = contact;
    if (loaded != null) {
      final value = read(loaded).trim();
      return value.isEmpty ? Text(fallback, style: softStyle) : Text(value, style: style);
    }
    if (contactFailed) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text("Couldn't load", style: AppTheme.body(fontSize: 14, color: AppColors.error)),
          TextButton(onPressed: onRetryContact, child: const Text('Retry')),
        ],
      );
    }
    return Text(contactLoading ? 'Loading…' : '–', style: softStyle);
  }

  /// The phone number as a tap-to-call link (48dp tall target).
  Widget _phoneValue(BuildContext context) {
    final loaded = contact;
    final phone = (loaded?.phone ?? '').trim();
    if (loaded == null || phone.isEmpty) return _contactValue(context, (c) => c.phone, 'No phone on file');
    void call() => openExternal(
          context,
          Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')),
          mode: LaunchMode.platformDefault,
        );
    return Semantics(
      button: true,
      label: 'Call $phone',
      onTap: call,
      excludeSemantics: true,
      child: InkWell(
        onTap: call,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(child: Text(phone, style: AppTheme.body(fontSize: 14, color: AppColors.primary))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions() {
    Widget approve(String label) => LoadingButton(
          label: label,
          loading: busyStatus == 'approved',
          onPressed: locked ? null : () => onUpdate('approved'),
        );
    Widget stop(String label) => LoadingButton(
          label: label,
          outlined: true,
          loading: busyStatus == 'suspended',
          onPressed: locked ? null : () => onUpdate('suspended'),
        );

    switch (shop.status) {
      case 'pending':
        return [approve('Approve'), stop('Reject')];
      case 'approved':
        return [stop('Suspend')];
      default:
        return [approve('Reactivate')];
    }
  }
}
