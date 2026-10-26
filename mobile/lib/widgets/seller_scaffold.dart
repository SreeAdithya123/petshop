import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/my_shop_provider.dart';
import '../theme/app_theme.dart';
import 'content_width.dart';
import 'role_shell.dart';
import 'seller/seller_common.dart';
import 'shared_widgets.dart';
import 'skeletons.dart';
import 'ui_kit.dart';

/// Chrome for the seller screens: RoleShell + the "no shop yet" / "awaiting
/// approval" gating the web seller pages do with useMyShop().
///
/// [builder] receives the shop and is placed in a SingleChildScrollView, so
/// return non-scrolling content (Column / shrinkWrapped lists).
/// Pull-to-refresh re-reads the shop; workspaces re-run their queries by
/// calling [listenForShopRefresh]. While the shop loads, a skeleton is shown;
/// a failed load shows a retry button.
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

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(myShopProvider);
      await ref.read(myShopProvider.future);
    } catch (_) {
      // The error state reports it.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return RoleShell(
      title: title,
      child: shopAsync.when(
        skipLoadingOnReload: true,
        loading: () => const _ScaffoldSkeleton(),
        error: (error, _) => _ShopLoadError(
          message: describeError(error),
          onRetry: () => ref.invalidate(myShopProvider),
        ),
        data: (shop) {
          if (shop == null) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: kScreenPadding,
                child: ContentWidth(
                  child: EmptyState(
                    title: 'Set up your shop first',
                    description: 'Create your store profile to unlock this page.',
                    action: ElevatedButton(
                      onPressed: () => context.go('/seller/store'),
                      child: const Text('Go to My store'),
                    ),
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: kScreenPadding,
              child: ContentWidth(
                maxWidth: 760,
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
            ),
          );
        },
      ),
    );
  }
}

/// Header + list skeleton shown while the shop row loads.
class _ScaffoldSkeleton extends StatelessWidget {
  const _ScaffoldSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: kScreenPadding,
      child: ContentWidth(
        maxWidth: 760,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 180, height: 26),
            SizedBox(height: 10),
            SkeletonBox(height: 14),
            SizedBox(height: 24),
            ListSkeleton(count: 3),
          ],
        ),
      ),
    );
  }
}

class _ShopLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ShopLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: kScreenPadding,
      child: ContentWidth(
        child: CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Couldn't load your shop", style: AppTheme.display(fontSize: 16)),
              const SizedBox(height: 6),
              Text(message, style: AppTheme.body(fontSize: 13.5, color: AppColors.error)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
