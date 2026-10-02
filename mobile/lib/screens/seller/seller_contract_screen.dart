import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

const _contractTerms =
    "By accepting this contract, you agree to list only pets and products you're licensed to sell, "
    'to keep your inventory and pricing accurate, to fulfill paid orders promptly, and to respond to '
    'customer support requests in good faith. PETSTA may suspend shops that violate these terms.';

/// Mirrors src/pages/seller/Contract.jsx: shows the seller contract terms
/// and lets the shop owner accept them.
class SellerContractScreen extends ConsumerStatefulWidget {
  const SellerContractScreen({super.key});

  @override
  ConsumerState<SellerContractScreen> createState() => _SellerContractScreenState();
}

class _SellerContractScreenState extends ConsumerState<SellerContractScreen> {
  Shop? _shop;
  bool _loading = true;
  bool _accepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      if (!mounted) return;
      setState(() {
        _shop = null;
        _loading = false;
      });
      return;
    }

    final shop = await ShopsRepository().getByOwnerId(profile.id);
    if (!mounted) return;
    setState(() {
      _shop = shop;
      _loading = false;
    });
  }

  Future<void> _handleAccept() async {
    final shop = _shop;
    if (shop == null || shop.contractAcceptedAt != null) return;

    setState(() {
      _accepting = true;
      _error = null;
    });

    try {
      final update = <String, dynamic>{
        'contract_accepted_at': DateTime.now().toIso8601String(),
        if (shop.contractVersion == null) 'contract_version': '1.0',
      };
      await ShopsRepository().update(shop.id, update);
      await _loadShop();
    } catch (updateError) {
      if (!mounted) return;
      setState(() => _error = updateError.toString());
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const RoleShell(
        title: 'Contract',
        child: LoadingView(label: 'Loading contract…'),
      );
    }

    if (_shop == null) {
      return RoleShell(
        title: 'Contract',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "You haven't set up your shop yet",
            description: 'Create your shop profile first.',
            action: ElevatedButton(
              onPressed: () => context.push('/seller/store'),
              child: const Text('Set up your shop'),
            ),
          ),
        ),
      );
    }

    final shop = _shop!;
    final isAccepted = shop.contractAcceptedAt != null;

    return RoleShell(
      title: 'Contract',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Seller contract', style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'The terms your shop operates under on PETSTA.',
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Contract version', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                      Text(
                        shop.contractVersion ?? 'No contract version on file yet',
                        style: AppTheme.body(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Accepted on', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                      Text(
                        isAccepted ? formatOrderDate(shop.contractAcceptedAt!) : 'Not yet accepted',
                        style: AppTheme.body(),
                      ),
                    ],
                  ),
                  if (isAccepted) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.trust, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "You've accepted the current seller contract.",
                            style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.trust),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 20),
                    Text(_contractTerms, style: AppTheme.body()),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: AppTheme.body(color: AppColors.error)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _accepting ? null : _handleAccept,
                      child: Text(_accepting ? 'Accepting…' : 'Accept contract'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
