import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/my_shop_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/ui_kit.dart';

const _contractTerms =
    "By accepting this contract, you agree to list only pets and products you're licensed to sell, "
    'to keep your inventory and pricing accurate, to fulfill paid orders promptly, and to respond to '
    'customer support requests in good faith. PETSTA may suspend shops that violate these terms.';

/// Mirrors src/pages/seller/Contract.jsx: shows the seller contract terms
/// and lets the shop owner accept them.
class SellerContractScreen extends StatelessWidget {
  const SellerContractScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Contract',
      subtitle: 'The terms your shop operates under on PETSTA.',
      builder: (context, shop) => _ContractView(shop: shop),
    );
  }
}

class _ContractView extends ConsumerStatefulWidget {
  final Shop shop;
  const _ContractView({required this.shop});

  @override
  ConsumerState<_ContractView> createState() => _ContractViewState();
}

class _ContractViewState extends ConsumerState<_ContractView> {
  bool _accepting = false;
  String? _error;

  Future<void> _accept() async {
    if (_accepting) return;
    final shop = widget.shop;
    if (shop.contractAcceptedAt != null) return;

    final confirmed = await confirmAction(
      context,
      title: 'Accept the seller contract?',
      message: 'You confirm that you have read the terms and agree to follow them for ${shop.name}.',
      confirmLabel: 'Accept contract',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _accepting = true;
      _error = null;
    });
    final failure = await updateRow('shops', shop.id, {
      'contract_accepted_at': DateTime.now().toUtc().toIso8601String(),
      if (shop.contractVersion == null) 'contract_version': '1.0',
    });
    if (!mounted) return;
    setState(() {
      _accepting = false;
      _error = failure;
    });
    if (failure != null) return;

    showSnack(context, 'Contract accepted. Thank you!');
    ref.invalidate(myShopProvider);
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final acceptedAt = shop.contractAcceptedAt;
    final accepted = acceptedAt != null;
    final version = (shop.contractVersion ?? '').trim();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SellerMetaRow('Contract version', text: version.isEmpty ? 'No version on file yet' : version),
          SellerMetaRow('Accepted on', text: acceptedAt != null ? formatOrderDate(acceptedAt) : 'Not yet accepted'),
          const SizedBox(height: 16),
          if (accepted) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.check_circle, size: 20, color: AppColors.trust),
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
            const SizedBox(height: 16),
          ],
          // The terms stay readable after acceptance.
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Text(_contractTerms, style: AppTheme.body()),
          if (!accepted) ...[
            if (_error != null) ...[
              const SizedBox(height: 16),
              NoticeBox.error(message: _error!),
            ],
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: LoadingButton(
                label: 'Accept contract',
                loading: _accepting,
                onPressed: _accept,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
