import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import 'role_shell.dart';
import 'shared_widgets.dart';
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

class AccountNav extends StatelessWidget {
  final String currentPath;
  final bool isCustomer;
  const AccountNav({super.key, required this.currentPath, required this.isCustomer});

  @override
  Widget build(BuildContext context) {
    final sections = _accountSections.where((s) => !s.customersOnly || isCustomer).toList();
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final section = sections[index];
          final active = section.path == currentPath;
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: active ? null : () => context.go(section.path),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? AppColors.primary : AppColors.border),
              ),
              alignment: Alignment.center,
              child: Row(
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
          );
        },
      ),
    );
  }
}

/// Chrome for every "My account" screen: app bar + drawer (RoleShell), the
/// account section chips, a login gate for signed-out visitors, and a
/// scrollable body with a heading.
///
/// [builder] output is placed inside a SingleChildScrollView, so return
/// non-scrolling content (Column, or a shrinkWrapped ListView with
/// NeverScrollableScrollPhysics) -- no Expanded/Flexible at the top level.
class AccountScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.status == AuthStatus.loading) {
      return const RoleShell(title: 'My account', child: LoadingView());
    }

    final profile = auth.profile;
    if (auth.status != AuthStatus.signedIn || profile == null) {
      return RoleShell(
        title: 'My account',
        child: Padding(
          padding: kScreenPadding,
          child: const Align(
            alignment: Alignment.topCenter,
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
          AccountNav(currentPath: path, isCustomer: profile.role == 'customer'),
          Expanded(
            child: SingleChildScrollView(
              padding: kScreenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(title: title, subtitle: subtitle, trailing: headerTrailing),
                  const SizedBox(height: 18),
                  builder(context, profile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
