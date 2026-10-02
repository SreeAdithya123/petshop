import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';

class _NavItem {
  final String label;
  final String path;
  const _NavItem(this.label, this.path);
}

const _customerNavItems = [
  _NavItem('Shop pets', '/pets'),
  _NavItem('Store', '/store'),
  _NavItem('Shops', '/sellers'),
  _NavItem('Gifting', '/gifting'),
  _NavItem('Learn', '/learn'),
  _NavItem('Support', '/support'),
  _NavItem('Sell on PETSTA', '/for-store-owners'),
];

const _sellerNavItems = [
  _NavItem('Dashboard', '/seller/dashboard'),
  _NavItem('My Store', '/seller/store'),
  _NavItem('Pets', '/seller/pets'),
  _NavItem('Products', '/seller/products'),
  _NavItem('Orders', '/seller/orders'),
  _NavItem('Support', '/seller/support'),
  _NavItem('Contract', '/seller/contract'),
];

const _adminNavItems = [
  _NavItem('Dashboard', '/admin/dashboard'),
  _NavItem('Shops', '/admin/shops'),
  _NavItem('Orders', '/admin/orders'),
  _NavItem('Videos', '/admin/videos'),
  _NavItem('Support', '/admin/support'),
  _NavItem('Contracts', '/admin/contracts'),
];

/// Role-aware app chrome: AppBar + Drawer, mirroring the web app's
/// Header.jsx role-based nav (customer/signed-out vs shop_owner vs admin).
/// A Drawer (not a bottom nav bar) is used because the customer and seller
/// item lists (6-7 entries) don't fit a bottom nav well.
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
    final brandAccent = isAdmin ? AppColors.adminAccent : AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      drawer: Drawer(
        backgroundColor: isAdmin ? AppColors.ink : AppColors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    Container(
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
                    const SizedBox(width: 10),
                    Text(
                      'PETSTA',
                      style: AppTheme.display(
                        fontSize: 18,
                        color: isAdmin ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isAdmin ? Colors.white24 : AppColors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final item in navItems)
                      ListTile(
                        title: Text(
                          item.label,
                          style: AppTheme.body(color: isAdmin ? Colors.white : AppColors.ink),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.push(item.path);
                        },
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: isAdmin ? Colors.white24 : AppColors.border),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: isSignedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(
                                auth.profile!.name.isNotEmpty ? auth.profile!.name : 'Account',
                                style: AppTheme.body(
                                  fontWeight: FontWeight.w600,
                                  color: isAdmin ? Colors.white : AppColors.ink,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push(roleHomePath(role));
                              },
                            ),
                            ListTile(
                              title: Text(
                                'Log out',
                                style: AppTheme.body(color: isAdmin ? Colors.white70 : AppColors.inkSoft),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await ref.read(authControllerProvider).signOut();
                                if (context.mounted) context.go('/');
                              },
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text('Log in', style: AppTheme.body()),
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/login');
                              },
                            ),
                            ListTile(
                              title: Text(
                                'Sign up',
                                style: AppTheme.body(fontWeight: FontWeight.w600, color: brandAccent),
                              ),
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push('/signup');
                              },
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}
