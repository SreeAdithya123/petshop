import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

/// Matches src/pages/admin/Contracts.jsx: which shops have accepted the
/// current seller contract version.
class AdminContractsScreen extends StatefulWidget {
  const AdminContractsScreen({super.key});

  @override
  State<AdminContractsScreen> createState() => _AdminContractsScreenState();
}

const _defaultVersion = '1.0';

const _contractBody = "This agreement sets out the terms under which a shop lists pets and "
    "products on PETSTA, including listing standards, pricing responsibilities, and "
    "payment handling between the shop and its customers. It also confirms PETSTA's "
    "role as a marketplace connecting local buyers and sellers, rather than a party to any "
    "individual sale. Shop owners are expected to review and accept the current version to "
    "keep selling on the platform.";

const _filters = <StatusFilter>[
  StatusFilter('all', 'All'),
  StatusFilter('missing', 'Not accepted'),
  StatusFilter('accepted', 'Accepted'),
];

/// The version most shops have accepted (the web app's rule for "current").
String _mostCommonVersion(List<AdminShopRow> shops) {
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

bool _hasAccepted(AdminShopRow shop, String currentVersion) =>
    shop.hasAcceptedContract && shop.contractVersion == currentVersion;

/// The shops (A to Z) and the version they are measured against.
class _ContractsData {
  final List<AdminShopRow> shops;
  final String currentVersion;
  const _ContractsData(this.shops, this.currentVersion);
}

Future<_ContractsData> _loadContracts() async {
  final shops = await fetchAdminShops();
  shops.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return _ContractsData(shops, _mostCommonVersion(shops));
}

class _AdminContractsScreenState extends State<AdminContractsScreen> {
  late final SellerQuery<_ContractsData> _query;
  String _filter = 'all';
  int _limit = kPageSize;

  @override
  void initState() {
    super.initState();
    _query = SellerQuery<_ContractsData>(_loadContracts);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Contracts',
      heading: 'Contract compliance',
      subtitle: 'Track which shops have accepted the current seller contract.',
      onRefresh: _query.reload,
      child: SellerQueryPanel<_ContractsData>(
        query: _query,
        what: 'contracts',
        builder: (context, data) {
          final shops = data.shops;
          final version = data.currentVersion;
          String statusOf(AdminShopRow shop) => _hasAccepted(shop, version) ? 'accepted' : 'missing';
          final visible = applyStatusFilter(_filters, _filter, shops, statusOf);
          final shown = math.min(_limit, visible.length);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardBox(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Contract version $version',
                        style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_contractBody, style: AppTheme.body(color: AppColors.inkSoft, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  'Shop acceptance status',
                  style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Whether each shop has accepted the current contract version.',
                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              if (shops.isEmpty)
                const CardBox(
                  child: EmptyState(
                    title: 'No shops yet',
                    description: 'Shops will appear here once sellers register.',
                  ),
                )
              else ...[
                FilterChipBar<String>(
                  options: filterOptions(_filters, shops, statusOf),
                  selected: _filter,
                  onSelected: (value) => setState(() {
                    _filter = value;
                    _limit = kPageSize;
                  }),
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const CardBox(
                    child: EmptyState(title: 'Nothing here', description: 'No shops match this filter.'),
                  )
                else ...[
                  CardBox(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < shown; i++) ...[
                          if (i > 0) const Divider(height: 1, color: AppColors.border),
                          _ShopAcceptanceRow(shop: visible[i], accepted: _hasAccepted(visible[i], version)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LoadMoreButton(
                    shown: shown,
                    total: visible.length,
                    onPressed: () => setState(() => _limit += kPageSize),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ShopAcceptanceRow extends StatelessWidget {
  final AdminShopRow shop;
  final bool accepted;
  const _ShopAcceptanceRow({required this.shop, required this.accepted});

  @override
  Widget build(BuildContext context) {
    final recorded = shop.contractVersion;
    final acceptedAt = shop.contractAcceptedAt;
    final detail = [
      recorded == null ? 'No version on file' : 'Version $recorded',
      if (acceptedAt != null) 'accepted ${formatOrderDate(acceptedAt)}',
    ].join(' · ');
    final name = shop.name.isEmpty ? 'Unnamed shop' : shop.name;

    return Semantics(
      container: true,
      label: '$name. $detail. ${accepted ? 'Accepted' : 'Not accepted'}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                status: accepted ? 'approved' : 'rejected',
                label: accepted ? 'Accepted' : 'Not accepted',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
