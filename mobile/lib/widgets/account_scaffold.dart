import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import 'account/account_widgets.dart';
import 'content_width.dart';
import 'role_shell.dart';
import 'shared_widgets.dart';
import 'skeletons.dart';
import 'ui_kit.dart';

class _AccountSection {
  final String label;
  final String path;
  final IconData icon;
  final bool customersOnly;
  const _AccountSection(this.label, this.path, this.icon, {this.customersOnly = false});
}

/// The "My account" sidebar from the web app, as a horizontally scrolling
/// chip strip pinned under the app bar on every account screen.
const _accountSections = [
  _AccountSection('Profile', '/account', Icons.person_outline),
  _AccountSection('My orders', '/account/orders', Icons.receipt_long_outlined),
  _AccountSection('Wishlist', '/account/wishlist', Icons.favorite_border),
  _AccountSection('Refunds', '/account/refunds', Icons.currency_exchange),
  _AccountSection('Addresses', '/account/addresses', Icons.location_on_outlined),
  _AccountSection('Demo requests', '/account/demos', Icons.videocam_outlined),
  _AccountSection('Learn', '/account/learn', Icons.menu_book_outlined),
  _AccountSection('Sell on PETSTA', '/account/sell', Icons.storefront_outlined, customersOnly: true),
];

class AccountNav extends StatefulWidget {
  final String currentPath;
  final bool isCustomer;
  const AccountNav({super.key, required this.currentPath, required this.isCustomer});

  @override
  State<AccountNav> createState() => _AccountNavState();
}

class _AccountNavState extends State<AccountNav> {
  final GlobalKey _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Bring the current section's chip into view (e.g. "Learn" sits off-screen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = _activeKey.currentContext;
      if (!mounted || activeContext == null) return;
      Scrollable.ensureVisible(
        activeContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = _accountSections.where((s) => !s.customersOnly || widget.isCustomer).toList();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (var index = 0; index < sections.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              _buildChip(context, sections[index]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, _AccountSection section) {
    final active = section.path == widget.currentPath;
    // The tappable area is 48dp tall; the visible pill inside it is 36dp.
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        key: active ? _activeKey : null,
        customBorder: const StadiumBorder(),
        onTap: active ? null : () => context.go(section.path),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? AppColors.primary : AppColors.border),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(section.icon, size: 16, color: active ? AppColors.primary : AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    section.label,
                    style: AppTheme.body(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? AppColors.primary : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The action behind an [AccountScaffold]'s pull-to-refresh. The screen body
/// registers its reload function here (see [AccountRefreshMixin]).
class AccountRefreshHandle {
  Future<void> Function()? _action;

  void attach(Future<void> Function() action) => _action = action;

  void detach(Future<void> Function() action) {
    if (_action == action) _action = null;
  }

  /// Runs the registered reload; completes at once when nothing is registered.
  Future<void> run() async {
    final action = _action;
    if (action != null) await action();
  }
}

/// Makes the [AccountRefreshHandle] of the enclosing [AccountScaffold]
/// available to its body.
class AccountRefreshScope extends InheritedWidget {
  final AccountRefreshHandle handle;

  const AccountRefreshScope({super.key, required this.handle, required super.child});

  static AccountRefreshHandle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountRefreshScope>()?.handle;

  @override
  bool updateShouldNotify(AccountRefreshScope oldWidget) => handle != oldWidget.handle;
}

/// Mix into the [State] of an [AccountScaffold] body to make pull-to-refresh
/// reload that screen: implement [refreshAccountData] and return the future
/// that finishes when the data is up to date (it ends the spinner).
mixin AccountRefreshMixin<T extends StatefulWidget> on State<T> {
  AccountRefreshHandle? _refreshHandle;

  Future<void> refreshAccountData();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handle = AccountRefreshScope.maybeOf(context);
    if (!identical(handle, _refreshHandle)) {
      _refreshHandle?.detach(refreshAccountData);
      _refreshHandle = handle;
      handle?.attach(refreshAccountData);
    }
  }

  @override
  void dispose() {
    _refreshHandle?.detach(refreshAccountData);
    super.dispose();
  }
}

/// Chrome for every "My account" screen: app bar + drawer (RoleShell), the
/// account section chips, a login gate for signed-out visitors, and a
/// pull-to-refresh scrollable body with a heading.
///
/// [builder] output is placed inside a SingleChildScrollView, so return
/// non-scrolling content (Column, or a shrinkWrapped ListView with
/// NeverScrollableScrollPhysics) -- no Expanded/Flexible at the top level.
class AccountScaffold extends ConsumerStatefulWidget {
  /// Route path of the screen, used to highlight its chip (e.g. '/account/orders').
  final String path;
  final String title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget Function(BuildContext context, Profile profile) builder;

  const AccountScaffold({
    super.key,
    required this.path,
    required this.title,
    this.subtitle,
    this.headerTrailing,
    required this.builder,
  });

  @override
  ConsumerState<AccountScaffold> createState() => _AccountScaffoldState();
}

class _AccountScaffoldState extends ConsumerState<AccountScaffold> {
  final AccountRefreshHandle _refresh = AccountRefreshHandle();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.status == AuthStatus.loading) {
      return RoleShell(
        title: 'My account',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: ContentWidth(
            // The session is fine but the profile could not be loaded (for
            // example no connection): say so and let the user retry.
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
        title: 'My account',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: const ContentWidth(
            child: LoginPromptCard(
              title: 'Log in to see your account',
              description: 'Your orders, wishlist, refunds, addresses and demo requests live here.',
            ),
          ),
        ),
      );
    }

    return RoleShell(
      title: 'My account',
      child: Column(
        children: [
          AccountNav(currentPath: widget.path, isCustomer: profile.role == 'customer'),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh.run,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: kScreenPadding,
                child: ContentWidth(
                  child: SizedBox(
                    width: double.infinity,
                    child: AccountRefreshScope(
                      handle: _refresh,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ScreenHeader(
                            title: widget.title,
                            subtitle: widget.subtitle,
                            trailing: widget.headerTrailing,
                          ),
                          const SizedBox(height: 18),
                          widget.builder(context, profile),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
