import 'package:flutter/material.dart';

import '../../core/async_utils.dart';
import '../../services/supabase_service.dart';
import '../../widgets/content_width.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';

/// Shared chrome and data helpers for the admin screens.

/// RoleShell + a refreshable, keyboard-friendly scroll view with the page
/// heading, mirroring SellerScaffold for the admin side. [child] should be
/// non-scrolling content (a Column); list screens reveal more rows with a
/// "Load more" button instead of nesting a scrollable.
class AdminScaffold extends StatelessWidget {
  /// App bar title.
  final String title;

  /// Page heading under the app bar.
  final String heading;
  final String? subtitle;
  final Widget? headerTrailing;

  /// Called by pull-to-refresh; should complete when the reload finishes.
  final Future<void> Function() onRefresh;
  final Widget child;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.heading,
    this.subtitle,
    this.headerTrailing,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: title,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: kScreenPadding,
          child: ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(title: heading, subtitle: subtitle, trailing: headerTrailing),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _timestamp(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

Map<String, dynamic>? _embedded(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty) return _embedded(raw.first);
  return null;
}

/// A shop as the admin screens see it (owner details come from the
/// `profiles(name, email)` embed, which carries no id/role, so the shared
/// Profile model can't parse it).
///
/// Street address and phone are deliberately NOT part of this row: admin
/// screens read them only through `ShopContactRepository`
/// (see `ShopContactsLoader`), so the contact columns have one owner.
class AdminShopRow {
  final String id;
  final String name;
  final String licenseNumber;
  final String status; // pending | approved | suspended
  final String? contractVersion;
  final DateTime? contractAcceptedAt;
  final DateTime createdAt;
  final String ownerName;
  final String ownerEmail;

  const AdminShopRow({
    required this.id,
    required this.name,
    required this.licenseNumber,
    required this.status,
    required this.contractVersion,
    required this.contractAcceptedAt,
    required this.createdAt,
    required this.ownerName,
    required this.ownerEmail,
  });

  factory AdminShopRow.fromJson(Map<String, dynamic> json) {
    final owner = _embedded(json['profiles']);
    final version = (json['contract_version'] as String? ?? '').trim();
    final acceptedRaw = json['contract_accepted_at'];
    return AdminShopRow(
      id: json['id'] as String,
      name: (json['name'] as String? ?? '').trim(),
      licenseNumber: (json['license_number'] as String? ?? '').trim(),
      status: json['status'] as String? ?? 'pending',
      contractVersion: version.isEmpty ? null : version,
      contractAcceptedAt: acceptedRaw is String && acceptedRaw.isNotEmpty ? _timestamp(acceptedRaw) : null,
      createdAt: _timestamp(json['created_at']),
      ownerName: ((owner?['name'] as String?) ?? '').trim(),
      ownerEmail: ((owner?['email'] as String?) ?? '').trim(),
    );
  }

  /// True once the owner has accepted a seller contract.
  bool get hasAcceptedContract => contractAcceptedAt != null;
}

/// Columns admin lists read from `shops` (no address / phone: see
/// [AdminShopRow]).
const kAdminShopColumns =
    'id, name, license_number, status, contract_version, contract_accepted_at, created_at, profiles(name, email)';

/// Every shop, newest first (pages past PostgREST's 1000-row cap).
Future<List<AdminShopRow>> fetchAdminShops() async {
  final rows = await withTimeout(
    fetchAllRows(() => SupabaseService.client.from('shops').select(kAdminShopColumns)),
    timeout: const Duration(seconds: 45),
  );
  final shops = rows.map(AdminShopRow.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return shops;
}
