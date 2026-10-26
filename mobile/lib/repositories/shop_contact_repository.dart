import '../services/supabase_service.dart';

/// A shop's private contact details (street address + phone).
///
/// ONLY shop owners (their own shop) and admins may use this: customer-facing
/// screens must never call it. All reads/writes of shop contact details go
/// through this class so that moving them out of the public `shops` table
/// into a private, owner/admin-only table later only changes this one file.
class ShopContact {
  final String shopId;
  final String address;
  final String phone;
  const ShopContact({required this.shopId, required this.address, required this.phone});
}

class ShopContactRepository {
  final _client = SupabaseService.client;

  Future<ShopContact?> fetch(String shopId) async {
    final row = await _client.from('shops').select('id, address, phone').eq('id', shopId).maybeSingle();
    return row == null ? null : _parse(row);
  }

  /// Contact details for several shops at once, keyed by shop id (admin lists).
  Future<Map<String, ShopContact>> fetchMany(List<String> shopIds) async {
    if (shopIds.isEmpty) return const {};
    final rows = await _client.from('shops').select('id, address, phone').inFilter('id', shopIds);
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>()) row['id'] as String: _parse(row),
    };
  }

  /// Saves the contact details of an existing shop. Returns false when nothing
  /// changed (blocked by RLS).
  Future<bool> save(String shopId, {required String address, required String phone}) async {
    final rows = await _client
        .from('shops')
        .update({'address': address, 'phone': phone})
        .eq('id', shopId)
        .select('id');
    return (rows as List).isNotEmpty;
  }

  /// Creates a shop (status is forced to 'pending' server-side) together with
  /// its contact details and returns the new shop id. [fields] holds the
  /// public shop columns (name, license_number, description, owner_id, ...).
  Future<String> createShop(Map<String, dynamic> fields, {required String address, required String phone}) async {
    final row = await _client
        .from('shops')
        .insert({...fields, 'address': address, 'phone': phone})
        .select('id')
        .single();
    return row['id'] as String;
  }

  ShopContact _parse(Map<String, dynamic> row) => ShopContact(
        shopId: row['id'] as String,
        address: row['address'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
      );
}
