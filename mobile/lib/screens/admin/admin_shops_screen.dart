import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../theme/app_theme.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Matches src/pages/admin/Shops.jsx: list every shop with owner details and
/// approve / suspend / reactivate actions.
class AdminShopsScreen extends ConsumerStatefulWidget {
  const AdminShopsScreen({super.key});

  @override
  ConsumerState<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

Color _statusColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.trust;
    case 'suspended':
      return AppColors.error;
    default:
      return AppColors.inkSoft;
  }
}

class _AdminShopsScreenState extends ConsumerState<AdminShopsScreen> {
  final _repo = ShopsRepository();
  bool _loading = true;
  List<Shop> _shops = [];
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final shops = await _repo.listAllWithOwner();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Shop shop, String nextStatus, {String? confirmMessage}) async {
    if (confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busyId = shop.id);
    try {
      await _repo.updateStatus(shop.id, nextStatus);
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _actionsFor(Shop shop) {
    final disabled = _busyId == shop.id;
    if (shop.status == 'pending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: disabled ? null : () => _updateStatus(shop, 'approved'),
              child: const Text('Approve'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: disabled
                  ? null
                  : () => _updateStatus(
                        shop,
                        'suspended',
                        confirmMessage: 'Suspend ${shop.name}? This shop will not be approved.',
                      ),
              child: const Text('Suspend'),
            ),
          ),
        ],
      );
    }
    if (shop.status == 'approved') {
      return SizedBox(
        height: 36,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          onPressed: disabled
              ? null
              : () => _updateStatus(
                    shop,
                    'suspended',
                    confirmMessage: 'Suspend ${shop.name}? It will no longer be visible to customers.',
                  ),
          child: const Text('Suspend'),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: disabled ? null : () => _updateStatus(shop, 'approved'),
        child: const Text('Reactivate'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Shops',
      child: _loading
          ? const LoadingView()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: kScreenPadding,
                children: [
                  Text('Manage shops', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Approve, suspend, or reactivate shops on the platform.',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  if (_shops.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyState(
                        title: 'No shops yet',
                        description: 'Shops will appear here once sellers register.',
                      ),
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
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _shops[i].name,
                                    style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_shops[i].owner?.name ?? 'Unknown owner'}'
                                    '${_shops[i].owner?.email != null && _shops[i].owner!.email!.isNotEmpty ? ' · ${_shops[i].owner!.email}' : ''}',
                                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'License ${_shops[i].licenseNumber.isNotEmpty ? _shops[i].licenseNumber : '—'} · '
                                    '${_shops[i].address.isNotEmpty ? _shops[i].address : 'No address on file'}',
                                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _shops[i].status,
                                    style: AppTheme.body(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(_shops[i].status),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _actionsFor(_shops[i]),
                                ],
                              ),
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
