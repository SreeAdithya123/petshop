import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/account/account_widgets.dart';
import '../widgets/account/new_ticket_form.dart';
import '../widgets/account/support_thread.dart';
import '../widgets/content_width.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';
import '../widgets/ui_kit.dart';

final _shopParamPattern = RegExp(r'^[0-9a-fA-F-]{32,36}$');
final _orderParamPattern = RegExp(r'^[0-9a-fA-F-]{8,36}$');

/// Query parameters of the current route (`/support?shop=<id>&order=<id>`),
/// or an empty map when the screen is shown outside the router.
Map<String, String> _routeQuery(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.queryParameters;
  } catch (_) {
    return const {};
  }
}

/// The subject a ticket about [orderId] starts with, e.g. "Order #1A2B3C4D".
String _orderSubject(String orderId) => 'Order ${orderRef(orderId)}';

/// Matches src/pages/Support.jsx, extended for the app: tickets with a status,
/// a new-ticket sheet and a message thread for each ticket. Customers use it
/// to coordinate pickup with a shop (shop contact details are private), so
/// `/support?shop=<shopId>&order=<orderId>` opens a new ticket with that shop
/// selected and "Order #XXXXXXXX" as the subject (or the existing ticket for
/// that order, if there is one).
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.status == AuthStatus.loading) {
      return RoleShell(
        title: 'Support',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: ContentWidth(
            child: auth.profileFailed
                ? AccountErrorNote(
                    message: "We couldn't load your account. Check your connection and try again.",
                    onRetry: () => ref.read(authControllerProvider).refreshProfile(),
                  )
                : const ListSkeleton(),
          ),
        ),
      );
    }

    final profile = auth.profile;
    if (auth.status != AuthStatus.signedIn || profile == null) {
      return RoleShell(
        title: 'Support',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: const ContentWidth(
            child: LoginPromptCard(
              title: 'Log in to get support',
              description: 'Message a shop about an order, or ask the PETSTA team for help.',
            ),
          ),
        ),
      );
    }

    final query = _routeQuery(context);
    final shop = query['shop'];
    final order = query['order'];
    return RoleShell(
      title: 'Support',
      child: _SupportBody(
        key: ValueKey(profile.id),
        profile: profile,
        shopParam: shop != null && _shopParamPattern.hasMatch(shop) ? shop : null,
        orderParam: order != null && _orderParamPattern.hasMatch(order) ? order : null,
      ),
    );
  }
}

class _SupportBody extends StatefulWidget {
  final Profile profile;
  final String? shopParam;
  final String? orderParam;

  const _SupportBody({super.key, required this.profile, this.shopParam, this.orderParam});

  @override
  State<_SupportBody> createState() => _SupportBodyState();
}

class _SupportBodyState extends State<_SupportBody> {
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _generation = 0;
  List<SupportTicket> _tickets = const [];
  List<Shop> _shops = const [];

  /// The `shop` / `order` deep link is acted on once, after the first load.
  late bool _deepLinkPending = widget.shopParam != null || widget.orderParam != null;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Shops a ticket can be addressed to. A failure here is not fatal: tickets
  /// can still be raised for the PETSTA team.
  Future<List<Shop>?> _fetchShops() async {
    try {
      return await ShopsRepository().listApproved();
    } catch (_) {
      return null;
    }
  }

  Future<void> _load({bool showSkeleton = false}) async {
    final generation = ++_generation;
    if (showSkeleton) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final shopsFuture = _fetchShops();
      final tickets = await SupportTicketsRepository().listForCustomer(widget.profile.id);
      final shops = await shopsFuture;
      if (!mounted || generation != _generation) return;
      setState(() {
        _tickets = tickets;
        if (shops != null) _shops = shops;
        _hasLoaded = true;
        _loading = false;
        _error = null;
      });
      if (_deepLinkPending) {
        _deepLinkPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleDeepLink();
        });
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (_hasLoaded) {
        // A refresh failed: keep the tickets that are already on screen.
        setState(() => _loading = false);
        showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() {
        _loading = false;
        _error = errorText(error);
      });
    }
  }

  /// `/support?shop=..&order=..`: continue the conversation about that order
  /// if there already is one, otherwise start a new ticket for it.
  void _handleDeepLink() {
    final shopId = widget.shopParam;
    final orderId = widget.orderParam;
    final subject = orderId == null ? null : _orderSubject(orderId);
    if (subject != null) {
      for (final ticket in _tickets) {
        if (ticket.subject == subject && ticket.shopId == shopId && ticket.status != 'closed') {
          _openThread(ticket);
          return;
        }
      }
    }
    _openNewTicket(shopId: shopId, subject: subject, orderLabel: orderId == null ? null : 'Order ${orderRef(orderId)}');
  }

  Future<void> _openThread(SupportTicket ticket) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SupportThreadPage(ticket: ticket, userId: widget.profile.id),
        ),
      );
    } finally {
      _opening = false;
    }
    // The status may have changed while the conversation was open.
    if (mounted) _load();
  }

  Future<void> _openNewTicket({String? shopId, String? subject, String? orderLabel}) async {
    if (_opening) return;
    _opening = true;
    NewTicketResult? result;
    try {
      result = await showFormSheet<NewTicketResult>(
        context,
        title: 'New ticket',
        description: 'Ask a shop about an order, or get help from the PETSTA team.',
        builder: (sheetContext) => NewTicketForm(
          customerId: widget.profile.id,
          shops: _shops,
          initialShopId: shopId,
          initialSubject: subject,
          orderLabel: orderLabel,
        ),
      );
    } finally {
      _opening = false;
    }
    if (result == null || !mounted) return;

    final created = result;
    await _load();
    if (!mounted) return;
    if (created.messageFailed) {
      showSnack(context, "Your ticket was created, but your message didn't send. Open it to try again.", error: true);
    }
    for (final ticket in _tickets) {
      if (ticket.id == created.ticketId) {
        _openThread(ticket);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profile.role;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kScreenPadding,
        child: ContentWidth(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeader(
                  title: 'Support',
                  subtitle: 'Message a shop about an order, or ask the PETSTA team for help.',
                ),
                const SizedBox(height: 16),
                if (role != 'customer') ...[
                  _StaffNote(role: role),
                  const SizedBox(height: 16),
                ],
                ElevatedButton.icon(
                  onPressed: _loading || _error != null ? null : () => _openNewTicket(),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('New ticket'),
                ),
                const SizedBox(height: 28),
                RefreshHeading(
                  title: 'Your tickets',
                  onRefresh: _loading ? null : () => _load(),
                ),
                const SizedBox(height: 12),
                _buildTickets(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTickets() {
    if (_loading) return const ListSkeleton(count: 3, itemHeight: 76);
    if (_error != null) {
      return AccountErrorNote(message: _error!, onRetry: () => _load(showSkeleton: true));
    }
    if (_tickets.isEmpty) {
      return EmptyState(
        title: 'No tickets yet',
        description: 'Open a ticket to message a shop about an order or to ask the PETSTA team for help.',
        action: ElevatedButton.icon(
          onPressed: () => _openNewTicket(),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('New ticket'),
        ),
      );
    }
    return Column(
      children: [
        for (final ticket in _tickets) ...[
          _TicketTile(ticket: ticket, onTap: () => _openThread(ticket)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Shop owners and admins can raise tickets here too, but customer questions
/// about their shop live in their own Support screen.
class _StaffNote extends StatelessWidget {
  final String role;
  const _StaffNote({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoticeBox(
          message: isAdmin
              ? 'You are signed in as an admin. Tickets from customers are in your admin Support screen. '
                  'Tickets you open here go to the PETSTA team.'
              : 'You are signed in as a shop owner. Customer questions about your shop are in your seller Support '
                  'screen. Tickets you open here go to the PETSTA team.',
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go(isAdmin ? '/admin/support' : '/seller/support'),
          child: Text(isAdmin ? 'Open admin Support' : 'Open seller Support'),
        ),
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;
  const _TicketTile({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shopName = ticket.shop?.name;
    final about = (shopName == null || shopName.isEmpty) ? 'General' : shopName;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$about · ${formatOrderDate(ticket.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(status: ticket.status),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
