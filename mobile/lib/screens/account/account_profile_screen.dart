import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/account/about_legal_card.dart';
import '../../widgets/account/account_widgets.dart';
import '../../widgets/account/danger_zone.dart';
import '../../widgets/account/order_items.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/ui_kit.dart';

const _roleLabels = {
  'customer': 'Customer',
  'shop_owner': 'Shop owner',
  'admin': 'Admin',
};

final _phonePattern = RegExp(r'^[\d\s()+-]{7,}$');

class _QuickLink {
  final String path;
  final String label;
  final String description;
  final IconData icon;
  const _QuickLink(this.path, this.label, this.description, this.icon);
}

const _sectionLinks = [
  _QuickLink('/account/orders', 'My orders', 'Purchases, reservations and gifts.', Icons.receipt_long_outlined),
  _QuickLink('/account/wishlist', 'Wishlist', "Pets you've saved for later.", Icons.favorite_border),
  _QuickLink('/account/refunds', 'Refunds', 'Request a refund and track its status.', Icons.currency_exchange),
  _QuickLink('/account/addresses', 'Addresses', 'Where your orders and gifts go.', Icons.location_on_outlined),
  _QuickLink('/account/demos', 'Demo requests', 'Meet a pet before you decide.', Icons.videocam_outlined),
  _QuickLink('/account/learn', 'Learn', 'Pet care videos.', Icons.menu_book_outlined),
];

const _sellLink = _QuickLink('/account/sell', 'Sell on PETSTA', 'Apply to list your shop.', Icons.storefront_outlined);

List<_QuickLink> _quickLinksFor(String role) {
  if (role == 'customer') return [..._sectionLinks, _sellLink];
  final isAdmin = role == 'admin';
  final dashboard = _QuickLink(
    roleHomePath(role),
    isAdmin ? 'Admin dashboard' : 'Seller dashboard',
    isAdmin ? 'Manage shops, services and orders.' : 'Manage your shop.',
    isAdmin ? Icons.admin_panel_settings_outlined : Icons.dashboard_outlined,
  );
  return [dashboard, ..._sectionLinks];
}

/// Mirrors src/pages/account/AccountProfile.jsx: who you are, edit name and
/// phone, sign out, and shortcuts to the rest of "My account" -- plus the
/// store-required extras: legal links, support and account deletion.
class AccountProfileScreen extends StatelessWidget {
  const AccountProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account',
      title: 'Profile',
      subtitle: 'Your details, and shortcuts to everything in your account.',
      builder: (context, profile) => _ProfileBody(key: ValueKey(profile.id), profile: profile),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final Profile profile;
  const _ProfileBody({super.key, required this.profile});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> with AccountRefreshMixin<_ProfileBody> {
  late Profile _profile = widget.profile;
  bool _signingOut = false;
  String _signOutError = '';
  bool _deleting = false;
  String _deleteError = '';

  @override
  void didUpdateWidget(_ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The auth profile was reloaded elsewhere; follow it.
    if (!identical(oldWidget.profile, widget.profile)) _profile = widget.profile;
  }

  @override
  Future<void> refreshAccountData() async {
    try {
      await ref.read(authControllerProvider).refreshProfile();
    } catch (_) {
      // Keep showing the details we already have.
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You can log back in any time with your email and password.',
      confirmLabel: 'Sign out',
    );
    if (!confirmed || !mounted) return;

    // Signing out swaps this whole screen for the login gate, so grab the
    // router before the await instead of relying on this widget staying mounted.
    final router = GoRouter.of(context);
    final auth = ref.read(authControllerProvider);
    setState(() {
      _signingOut = true;
      _signOutError = '';
    });
    try {
      await auth.signOut();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _signingOut = false;
        _signOutError = errorText(error);
      });
      return;
    }
    clearOrderItemsCache();
    router.go('/');
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    final confirmed = await showDeleteAccountDialog(context);
    if (!confirmed || !mounted) return;

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final auth = ref.read(authControllerProvider);
    setState(() {
      _deleting = true;
      _deleteError = '';
    });
    try {
      await SupabaseService.client.rpc('delete_my_account');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _deleteError = rpcErrorText(error);
      });
      return;
    }

    try {
      await auth.signOut();
    } catch (_) {
      // The account is already gone on the server; the local session is
      // cleared either way.
    }
    clearOrderItemsCache();
    router.go('/');
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Your account has been deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Keeps the rest of the app (drawer, Sell prefill, ...) in step with the
  /// saved row, like `useAuthStore.setState({ profile })` on the web.
  Future<void> _handleSaved(Profile saved) async {
    final auth = ref.read(authControllerProvider);
    if (mounted) setState(() => _profile = saved);
    try {
      await auth.refreshProfile();
    } catch (_) {
      // The row is saved; the header catches up on the next profile load.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final profile = _profile;
    final email = auth.session?.user.email ?? profile.email ?? '';
    final memberSince = asDate(auth.session?.user.createdAt);
    final initialSource = profile.name.trim().isNotEmpty ? profile.name.trim() : (email.isNotEmpty ? email : '?');
    final initial = String.fromCharCode(initialSource.runes.first).toUpperCase();
    final links = _quickLinksFor(profile.role);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CardBox(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(initial, style: AppTheme.display(fontSize: 22, color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isNotEmpty ? profile.name : 'Your account',
                          style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _roleLabels[profile.role] ?? profile.role,
                      style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                  if (memberSince != null)
                    Text(
                      'Member since ${formatDate(memberSince.toLocal())}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              LoadingButton(
                label: 'Sign out',
                icon: Icons.logout,
                outlined: true,
                loading: _signingOut,
                onPressed: _signOut,
              ),
              if (_signOutError.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_signOutError, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle('Your details'),
        const SizedBox(height: 14),
        _DetailsForm(profile: profile, email: email, onSaved: _handleSaved),
        const SizedBox(height: 32),
        const SectionTitle('Quick links'),
        const SizedBox(height: 14),
        for (final link in links) ...[
          _QuickLinkTile(link: link),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 22),
        const SectionTitle('About & legal'),
        const SizedBox(height: 14),
        const AboutLegalCard(),
        const SizedBox(height: 32),
        DangerZoneCard(
          role: profile.role,
          busy: _deleting,
          error: _deleteError,
          onDelete: _deleteAccount,
          onContactSupport: () => context.push('/support'),
        ),
      ],
    );
  }
}

class _DetailsForm extends StatefulWidget {
  final Profile profile;
  final String email;
  final Future<void> Function(Profile saved) onSaved;

  const _DetailsForm({required this.profile, required this.email, required this.onSaved});

  @override
  State<_DetailsForm> createState() => _DetailsFormState();
}

class _DetailsFormState extends State<_DetailsForm> {
  late final TextEditingController _nameController = TextEditingController(text: widget.profile.name);
  late final TextEditingController _phoneController = TextEditingController(text: widget.profile.phone ?? '');

  String? _nameError;
  String? _phoneError;
  String _formError = '';
  bool _saved = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _nameController.text.trim() != widget.profile.name || _phoneController.text.trim() != (widget.profile.phone ?? '');

  void _edited(String _) => setState(() => _saved = false);

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final nameError = name.isEmpty ? 'Enter your name.' : null;
    final phoneError = phone.isNotEmpty && !_phonePattern.hasMatch(phone) ? 'Enter a valid phone number.' : null;
    setState(() {
      _formError = '';
      _saved = false;
      _nameError = nameError;
      _phoneError = phoneError;
    });
    if (nameError != null || phoneError != null) return;

    setState(() => _saving = true);
    try {
      final row = await SupabaseService.client
          .from('profiles')
          .update({'name': name, 'phone': phone})
          .eq('id', widget.profile.id)
          .select('id, role, name, phone, email, created_at')
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() {
          _saving = false;
          _formError = "Couldn't save your changes. Please try again.";
        });
        return;
      }
      final saved = Profile.fromJson(row);
      _nameController.text = saved.name;
      _phoneController.text = saved.phone ?? '';
      await widget.onSaved(saved);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      showSnack(context, 'Profile updated.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = errorText(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FormLabel('Name'),
        TextField(
          controller: _nameController,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [LengthLimitingTextInputFormatter(80)],
          onChanged: _edited,
          decoration: InputDecoration(errorText: _nameError),
        ),
        const SizedBox(height: 16),
        const FormLabel('Phone', optional: true),
        TextField(
          controller: _phoneController,
          enabled: !_saving,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [LengthLimitingTextInputFormatter(24)],
          onChanged: _edited,
          onSubmitted: (_) {
            if (_dirty) _submit();
          },
          decoration: InputDecoration(errorText: _phoneError),
        ),
        const SizedBox(height: 16),
        const FormLabel('Email'),
        TextFormField(
          key: ValueKey(widget.email),
          initialValue: widget.email,
          readOnly: true,
          enabled: false,
          decoration: const InputDecoration(helperText: "Your email is your login, so it can't be changed here."),
        ),
        if (_formError.isNotEmpty) ...[
          const SizedBox(height: 14),
          NoticeBox.error(message: _formError),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LoadingButton(
              label: 'Save changes',
              loading: _saving,
              onPressed: _dirty ? _submit : null,
            ),
            if (_saved)
              Text('Profile updated.', style: AppTheme.body(fontSize: 13.5, color: AppColors.trust)),
          ],
        ),
      ],
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  final _QuickLink link;
  const _QuickLinkTile({required this.link});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(link.path),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(link.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(link.label, style: AppTheme.body(fontWeight: FontWeight.w600)),
                    Text(link.description, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
