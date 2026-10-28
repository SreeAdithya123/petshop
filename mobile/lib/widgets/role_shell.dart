import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_provider.dart';
import '../state/cart_provider.dart';
import '../state/wishlist_provider.dart';
import '../theme/app_theme.dart';
import 'content_width.dart';

class _NavItem {
  final String label;
  final String path;
  const _NavItem(this.label, this.path);
}

const _customerNavItems = [
  _NavItem('Shop pets', '/pets'),
  _NavItem('Store', '/store'),
  _NavItem('Shops', '/sellers'),
  _NavItem('Services', '/services'),
  _NavItem('Health', '/health'),
  _NavItem('Gifting', '/gifting'),
  _NavItem('Wishlist', '/account/wishlist'),
  _NavItem('Support', '/support'),
];

// Learn and "Sell on PETSTA" now live inside My account (see AccountNav).
const _sellerNavItems = [
  _NavItem('Dashboard', '/seller/dashboard'),
  _NavItem('Analytics', '/seller/analytics'),
  _NavItem('Orders', '/seller/orders'),
  _NavItem('Pets', '/seller/pets'),
  _NavItem('Products', '/seller/products'),
  _NavItem('Services', '/seller/services'),
  _NavItem('Demo requests', '/seller/demos'),
  _NavItem('Refunds', '/seller/refunds'),
  _NavItem('Support', '/seller/support'),
  _NavItem('My store', '/seller/store'),
  _NavItem('Contract', '/seller/contract'),
];

const _adminNavItems = [
  _NavItem('Dashboard', '/admin/dashboard'),
  _NavItem('Shops', '/admin/shops'),
  _NavItem('Services', '/admin/services'),
  _NavItem('Orders', '/admin/orders'),
  _NavItem('Videos', '/admin/videos'),
  _NavItem('Support', '/admin/support'),
  _NavItem('Contracts', '/admin/contracts'),
];

/// Screens wider than this (tablets, landscape) get a centred column instead
/// of stretching edge to edge.
const double _kShellMaxWidth = 900;

/// The route currently on screen, or null when the shell is used outside a
/// route builder (previews, tests).
String? _currentPath(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } catch (_) {
    return null;
  }
}

/// Role-aware app chrome: AppBar + Drawer, mirroring the web app's
/// Header.jsx role-based nav (customer/signed-out vs shop_owner vs admin).
/// A Drawer (not a bottom nav bar) is used because the customer and seller
/// item lists (6-7 entries) don't fit a bottom nav well.
///
/// Customers and signed-out visitors also get a cart button (with an item
/// count badge) in the app bar; shop owners and admins don't have a cart.
class RoleShell extends ConsumerWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const RoleShell({super.key, required this.title, required this.child, this.actions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final isSignedIn = auth.status == AuthStatus.signedIn && auth.profile != null;
    final role = auth.profile?.role;

    final isAdmin = role == 'admin';
    final navItems = role == 'shop_owner'
        ? _sellerNavItems
        : isAdmin
            ? _adminNavItems
            : _customerNavItems;

    // Customers and visitors have a cart. While a session's profile is still
    // loading the role is unknown, so no cart is shown until it is.
    final hasCart = role == null ? auth.session == null : role == 'customer';
    final path = _currentPath(context);
    final showCart = hasCart && path != '/cart' && path != '/checkout';
    final showWishlist = hasCart && path != '/account/wishlist';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          if (showWishlist) const _WishlistButton(),
          if (showCart) const _CartButton(),
        ],
      ),
      drawer: _ShellDrawer(
        navItems: navItems,
        currentPath: path,
        isAdmin: isAdmin,
        isSignedIn: isSignedIn,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Always the first child, so the body below keeps its state when
            // the banner appears and disappears.
            auth.profileFailed ? const _ProfileBanner() : const SizedBox.shrink(),
            Expanded(child: _BodyFrame(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Keeps the body full-size on phones (it receives the same tight constraints
/// as always) and caps it at [_kShellMaxWidth], centred, on wide screens.
class _BodyFrame extends StatelessWidget {
  final Widget child;
  const _BodyFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _kShellMaxWidth) return child;
        return ContentWidth(maxWidth: _kShellMaxWidth, child: SizedBox.expand(child: child));
      },
    );
  }
}

/// App-bar heart that opens the wishlist (with a count of saved pets).
/// Visitors who are not logged in are sent to log in first.
class _WishlistButton extends ConsumerWidget {
  const _WishlistButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(wishlistControllerProvider.select((wishlist) => wishlist.petIds.length));
    final label = count == 0 ? 'Wishlist' : 'Wishlist, $count saved ${count == 1 ? 'pet' : 'pets'}';
    return IconButton(
      tooltip: label,
      onPressed: () {
        final auth = ref.read(authControllerProvider);
        final isCustomer = auth.status == AuthStatus.signedIn && auth.profile?.role == 'customer';
        context.push(isCustomer ? '/account/wishlist' : '/login?from=${Uri.encodeComponent('/account/wishlist')}');
      },
      icon: ExcludeSemantics(
        child: Badge.count(
          count: count,
          isLabelVisible: count > 0,
          child: const Icon(Icons.favorite_border),
        ),
      ),
    );
  }
}

/// App-bar cart icon with an item-count badge.
class _CartButton extends ConsumerWidget {
  const _CartButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartControllerProvider.select((cart) => cart.items.length));
    final label = count == 0 ? 'Cart' : 'Cart, $count ${count == 1 ? 'item' : 'items'}';
    return IconButton(
      tooltip: label,
      onPressed: () => context.push('/cart'),
      icon: ExcludeSemantics(
        child: Badge.count(
          count: count,
          isLabelVisible: count > 0,
          child: const Icon(Icons.shopping_cart_outlined),
        ),
      ),
    );
  }
}

/// Shown while a signed-in user's profile could not be loaded (no connection,
/// server hiccup). The session is kept and loading is retried automatically.
class _ProfileBanner extends ConsumerWidget {
  const _ProfileBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: const Color(0xFFFEF3C7),
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 18, color: Color(0xFF92400E)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "Can't load your account right now. Retrying…",
                    style: AppTheme.body(fontSize: 13, color: const Color(0xFF92400E)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => ref.read(authControllerProvider).refreshProfile(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  minimumSize: const Size(64, 48),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellDrawer extends ConsumerWidget {
  final List<_NavItem> navItems;
  final String? currentPath;
  final bool isAdmin;
  final bool isSignedIn;

  const _ShellDrawer({
    required this.navItems,
    required this.currentPath,
    required this.isAdmin,
    required this.isSignedIn,
  });

  bool _isCurrent(String path) {
    final here = currentPath;
    if (here == null) return false;
    return here == path || here.startsWith('$path/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final role = auth.profile?.role;
    final brandAccent = isAdmin ? AppColors.adminAccent : AppColors.primary;
    final textColor = isAdmin ? Colors.white : AppColors.ink;
    final softColor = isAdmin ? Colors.white70 : AppColors.inkSoft;
    final dividerColor = isAdmin ? Colors.white24 : AppColors.border;
    final hasSessionWithoutProfile = !isSignedIn && auth.session != null;

    /// Closes the drawer, then runs [action].
    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    Widget tile({
      required String label,
      required VoidCallback onTap,
      TextStyle? style,
      bool selected = false,
      Widget? leading,
    }) {
      return ListTile(
        minVerticalPadding: 8,
        leading: leading,
        title: Text(label, style: style ?? AppTheme.body(color: textColor)),
        selected: selected,
        selectedColor: brandAccent,
        selectedTileColor: brandAccent.withValues(alpha: 0.08),
        onTap: onTap,
      );
    }

    return Drawer(
      backgroundColor: isAdmin ? AppColors.ink : AppColors.surface,
      semanticLabel: 'Main menu',
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: isAdmin ? null : AppColors.heroGradient,
                          color: isAdmin ? AppColors.adminAccent : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.pets, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('PETSTA', style: AppTheme.display(fontSize: 18, color: textColor)),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 8),
            for (final item in navItems)
              tile(
                label: item.label,
                selected: _isCurrent(item.path),
                onTap: () => closeThen(() {
                  if (!_isCurrent(item.path)) context.push(item.path);
                }),
              ),
            const SizedBox(height: 8),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 8),
            if (isSignedIn) ...[
              tile(
                label: role == 'customer'
                    ? 'My account'
                    : (auth.profile!.name.isNotEmpty ? auth.profile!.name : 'Account'),
                style: AppTheme.body(fontWeight: FontWeight.w600, color: textColor),
                onTap: () => closeThen(() => context.push(roleHomePath(role))),
              ),
              tile(
                label: 'Log out',
                style: AppTheme.body(color: softColor),
                onTap: () => closeThen(() => _signOut(context, ref)),
              ),
            ] else if (hasSessionWithoutProfile) ...[
              tile(
                label: auth.profileFailed ? "Couldn't load your account. Tap to retry" : 'Loading your account…',
                style: AppTheme.body(color: softColor),
                leading: auth.profileFailed
                    ? Icon(Icons.refresh, color: softColor)
                    : SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: softColor),
                      ),
                onTap: () {
                  if (auth.profileFailed) auth.refreshProfile();
                },
              ),
              tile(
                label: 'Log out',
                style: AppTheme.body(color: softColor),
                onTap: () => closeThen(() => _signOut(context, ref)),
              ),
            ] else ...[
              tile(
                label: 'Log in',
                onTap: () => closeThen(() => context.push('/login')),
              ),
              tile(
                label: 'Sign up',
                style: AppTheme.body(fontWeight: FontWeight.w600, color: brandAccent),
                onTap: () => closeThen(() => context.push('/signup')),
              ),
            ],
            const SizedBox(height: 8),
            Divider(height: 1, color: dividerColor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                alignment: WrapAlignment.start,
                children: [
                  _LegalLink(
                    label: 'Privacy',
                    color: softColor,
                    onTap: () => closeThen(() => context.push('/legal/privacy')),
                  ),
                  _LegalLink(
                    label: 'Terms',
                    color: softColor,
                    onTap: () => closeThen(() => context.push('/legal/terms')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider).signOut();
    if (context.mounted) context.go('/');
  }
}

/// Small text link at the bottom of the drawer (48dp tall tap target).
class _LegalLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LegalLink({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label, style: AppTheme.body(fontSize: 13, color: color)),
    );
  }
}
