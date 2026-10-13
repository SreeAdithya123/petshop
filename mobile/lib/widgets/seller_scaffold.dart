import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/my_shop_provider.dart';
import 'role_shell.dart';
import 'shared_widgets.dart';
import 'ui_kit.dart';

/// Chrome for the new seller screens: RoleShell + the "no shop yet" /
/// "awaiting approval" gating the web seller pages do with useMyShop().
///
/// [builder] receives the shop and is placed in a SingleChildScrollView, so
/// return non-scrolling content (Column / shrinkWrapped lists).
/// Pull-to-refresh re-reads the shop and calls [onRefresh] if given.
class SellerScaffold extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Widget? headerTrailing;
  final Widget Function(BuildContext context, Shop shop) builder;

  const SellerScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.headerTrailing,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return RoleShell(
      title: title,
      child: shopAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: 'Could not load your shop: $error'),
        data: (shop) {
          if (shop == null) {
            return Padding(
              padding: kScreenPadding,
              child: EmptyState(
                title: 'Set up your shop first',
                description: 'Create your store profile to unlock this page.',
                action: ElevatedButton(
                  onPressed: () => context.go('/seller/store'),
                  child: const Text('Go to My store'),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myShopProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: kScreenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScreenHeader(title: title, subtitle: subtitle, trailing: headerTrailing),
                  const SizedBox(height: 16),
                  if (shop.status != 'approved') ...[
                    NoticeBox.warning(
                      message: shop.status == 'suspended'
                          ? 'Your shop is suspended. Contact PETSTA support.'
                          : 'Your shop is awaiting admin approval. These features unlock once it is approved.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  builder(context, shop),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
