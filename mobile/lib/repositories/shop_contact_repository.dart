import '../services/supabase_service.dart';

/// A shop's private contact details (street address + phone).
///
/// These live in `public.shop_private`, a table that row-level security makes
/// readable ONLY by the owning shop and admins. Customer-facing screens must
/// never call this class. All reads/writes of shop contact details go through
/// here so the storage can change without touching any screen.
class ShopContact {
  final String shopId;
  final String address;
  final String phone;
  const ShopContact({required this.shopId, required this.address, required this.phone});
}

class ShopContactRepository {
  final _client = SupabaseService.client;

  Future<ShopContact?> fetch(String shopId) async {
    final row = await _client.from('shop_private').select('shop_id, address, phone').eq('shop_id', shopId).maybeSingle();
    return row == null ? null : _parse(row);
  }

  /// Contact details for several shops at once, keyed by shop id (admin lists).
  Future<Map<String, ShopContact>> fetchMany(List<String> shopIds) async {
    if (shopIds.isEmpty) return const {};
    final rows = await _client.from('shop_private').select('shop_id, address, phone').inFilter('shop_id', shopIds);
    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>()) row['shop_id'] as String: _parse(row),
    };
  }

  /// Saves (creates or replaces) the contact details of an existing shop.
  /// Returns false when nothing changed (blocked by row-level security).
  Future<bool> save(String shopId, {required String address, required String phone}) async {
    final rows = await _client
        .from('shop_private')
        .upsert({'shop_id': shopId, 'address': address, 'phone': phone}, onConflict: 'shop_id')
        .select('shop_id');
    return (rows as List).isNotEmpty;
  }

  /// Creates a shop (status is forced to 'pending' server-side) and then its
  /// contact details, and returns the new shop id. [fields] holds the public
  /// shop columns (name, license_number, description, owner_id, ...).
  ///
  /// If the contact step fails the shop already exists without contact
  /// details: the error is rethrown and the owner can simply save again from
  /// the store profile screen.
  Future<String> createShop(Map<String, dynamic> fields, {required String address, required String phone}) async {
    final row = await _client.from('shops').insert(fields).select('id').single();
    final shopId = row['id'] as String;
    final saved = await save(shopId, address: address, phone: phone);
    if (!saved) {
      throw StateError('Your shop was created, but its address and phone could not be saved. Please save them again.');
    }
    return shopId;
  }

  ShopContact _parse(Map<String, dynamic> row) => ShopContact(
        shopId: row['shop_id'] as String,
        address: row['address'] as String? ?? '',
        phone: row['phone'] as String? ?? '',
      );
}
