import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Matches src/pages/admin/Contracts.jsx: which shops have accepted the
/// current seller contract version.
class AdminContractsScreen extends ConsumerStatefulWidget {
  const AdminContractsScreen({super.key});

  @override
  ConsumerState<AdminContractsScreen> createState() => _AdminContractsScreenState();
}

const _defaultVersion = '1.0';

const _contractBody = "This agreement sets out the terms under which a shop lists pets and "
    "products on PETSTA, including listing standards, pricing responsibilities, and "
    "payment handling between the shop and its customers. It also confirms PETSTA's "
    "role as a marketplace connecting local buyers and sellers, rather than a party to any "
    "individual sale. Shop owners are expected to review and accept the current version to "
    "keep selling on the platform.";

String _mostCommonVersion(List<Shop> shops) {
  final counts = <String, int>{};
  for (final shop in shops) {
    final version = shop.contractVersion;
    if (version == null || version.isEmpty) continue;
    counts[version] = (counts[version] ?? 0) + 1;
  }

  String? best;
  var bestCount = 0;
  counts.forEach((version, count) {
    if (count > bestCount) {
      best = version;
      bestCount = count;
    }
  });
  return best ?? _defaultVersion;
}

class _AdminContractsScreenState extends ConsumerState<AdminContractsScreen> {
  bool _loading = true;
  String? _error;
  List<Shop> _shops = [];
  String _currentVersion = _defaultVersion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shops = await ShopsRepository().listAllWithOwner();
      shops.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _currentVersion = _mostCommonVersion(shops);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(title: 'Contracts', child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(label: 'Loading shops…');
    }
    if (_error != null) {
      return ErrorView(message: "Couldn't load shops: $_error");
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: kScreenPadding,
        children: [
          Text('Contract compliance', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Track which shops have accepted the current seller contract.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contract version $_currentVersion',
                  style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  _contractBody,
                  style: AppTheme.body(color: AppColors.inkSoft, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Shop acceptance status', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Whether each shop has accepted the current contract version.',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          if (_shops.isEmpty)
            const EmptyState(
              title: 'No shops yet',
              description: 'Shops will appear here once sellers register.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _shops.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _ShopAcceptanceRow(shop: _shops[i], currentVersion: _currentVersion),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopAcceptanceRow extends StatelessWidget {
  final Shop shop;
  final String currentVersion;
  const _ShopAcceptanceRow({required this.shop, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    final accepted = shop.contractAcceptedAt != null && shop.contractVersion == currentVersion;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  shop.contractVersion != null && shop.contractVersion!.isNotEmpty
                      ? 'Version ${shop.contractVersion}'
                      : 'No version on file',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            accepted ? 'Accepted' : 'Not accepted',
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accepted ? AppColors.trust : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
