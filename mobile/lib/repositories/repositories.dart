import '../models/models.dart';
import '../services/supabase_service.dart';

/// Thin query wrappers over Supabase tables, grouped by table. These are
/// intentionally generic (not one bespoke method per screen) so screen
/// widgets compose `.select()`/`.eq()`/`.order()` filters as needed on top,
/// the same way the web app's pages call `supabase.from(...)` directly.
/// Screens should prefer these helpers for common cases but may reach
/// `SupabaseService.client.from(...)` directly for one-off queries.
class ShopsRepository {
  final _table = SupabaseService.client.from('shops');

  Future<Shop?> getByOwnerId(String ownerId) async {
    final row = await _table.select().eq('owner_id', ownerId).maybeSingle();
    return row != null ? Shop.fromJson(row) : null;
  }

  Future<Shop?> getById(String id) async {
    final row = await _table.select().eq('id', id).maybeSingle();
    return row != null ? Shop.fromJson(row) : null;
  }

  Future<List<Shop>> listApproved() async {
    final rows = await _table.select().eq('status', 'approved').order('created_at', ascending: false);
    return (rows as List).map((r) => Shop.fromJson(r)).toList();
  }

  Future<List<Shop>> listAllWithOwner() async {
    final rows = await _table.select('*, profiles(name,email)').order('created_at', ascending: false);
    return (rows as List).map((r) => Shop.fromJson(r)).toList();
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);

  Future<void> updateStatus(String id, String status) => _table.update({'status': status}).eq('id', id);

  Future<void> update(String id, Map<String, dynamic> data) => _table.update(data).eq('id', id);
}

class PetsRepository {
  final _table = SupabaseService.client.from('pets');

  Future<List<Pet>> listByShop(String shopId) async {
    final rows = await _table.select().eq('shop_id', shopId).order('created_at', ascending: false);
    return (rows as List).map((r) => Pet.fromJson(r)).toList();
  }

  Future<List<Pet>> listAvailable({String? species}) async {
    var query = _table.select('*, shops(name)').eq('status', 'available');
    if (species != null) query = query.eq('species', species);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => Pet.fromJson(r)).toList();
  }

  Future<Pet?> getById(String id) async {
    final row = await _table.select('*, shops(*)').eq('id', id).maybeSingle();
    return row != null ? Pet.fromJson(row) : null;
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);

  Future<void> update(String id, Map<String, dynamic> data) => _table.update(data).eq('id', id);

  Future<void> delete(String id) => _table.delete().eq('id', id);
}

class ProductsRepository {
  final _table = SupabaseService.client.from('products');

  Future<List<Product>> listByShop(String shopId) async {
    final rows = await _table.select().eq('shop_id', shopId).order('created_at', ascending: false);
    return (rows as List).map((r) => Product.fromJson(r)).toList();
  }

  Future<List<Product>> listAvailable({String? category}) async {
    var query = _table.select('*, shops(name)').eq('status', 'available');
    if (category != null) query = query.eq('category', category);
    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => Product.fromJson(r)).toList();
  }

  Future<Product?> getById(String id) async {
    final row = await _table.select('*, shops(*)').eq('id', id).maybeSingle();
    return row != null ? Product.fromJson(row) : null;
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);

  Future<void> update(String id, Map<String, dynamic> data) => _table.update(data).eq('id', id);

  Future<void> delete(String id) => _table.delete().eq('id', id);
}

class OrdersRepository {
  final _table = SupabaseService.client.from('orders');

  Future<List<OrderRow>> listForCustomer(String customerId) async {
    final rows = await _table.select().eq('customer_id', customerId).order('created_at', ascending: false);
    return (rows as List).map((r) => OrderRow.fromJson(r)).toList();
  }

  Future<List<OrderRow>> listAllWithCustomer() async {
    final rows = await _table.select('*, profiles(name,email)').order('created_at', ascending: false);
    return (rows as List).map((r) => OrderRow.fromJson(r)).toList();
  }

  Future<List<Map<String, dynamic>>> listByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _table.select().inFilter('id', ids).order('created_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String> insert(Map<String, dynamic> data) async {
    final row = await _table.insert(data).select().single();
    return row['id'] as String;
  }

  Future<void> updateStatus(String id, String status) => _table.update({'status': status}).eq('id', id);
}

class OrderItemsRepository {
  final _table = SupabaseService.client.from('order_items');

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);

  Future<void> insertMany(List<Map<String, dynamic>> rows) => _table.insert(rows);

  Future<List<String>> orderIdsForItems({required String itemType, required List<String> itemIds}) async {
    if (itemIds.isEmpty) return [];
    final rows = await _table.select('order_id').eq('item_type', itemType).inFilter('item_id', itemIds);
    return (rows as List).map((r) => r['order_id'] as String).toSet().toList();
  }
}

class ReservationsRepository {
  final _table = SupabaseService.client.from('reservations');

  Future<List<Reservation>> listForCustomer(String customerId) async {
    final rows = await _table
        .select('*, pets(species, breed)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Reservation.fromJson(r)).toList();
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);
}

class GiftsRepository {
  final _table = SupabaseService.client.from('gifts');

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);
}

class ReferenceVideosRepository {
  final _table = SupabaseService.client.from('reference_videos');

  Future<List<ReferenceVideo>> listAll() async {
    final rows = await _table.select().order('created_at', ascending: false);
    return (rows as List).map((r) => ReferenceVideo.fromJson(r)).toList();
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);

  Future<void> delete(String id) => _table.delete().eq('id', id);
}

class SupportTicketsRepository {
  final _table = SupabaseService.client.from('support_tickets');

  Future<List<SupportTicket>> listForCustomer(String customerId) async {
    final rows = await _table
        .select('*, shops(name)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => SupportTicket.fromJson(r)).toList();
  }

  Future<List<SupportTicket>> listForShop(String shopId) async {
    final rows = await _table
        .select('*, profiles(name,email)')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => SupportTicket.fromJson(r)).toList();
  }

  Future<List<SupportTicket>> listAll() async {
    final rows = await _table
        .select('*, profiles(name,email), shops(name)')
        .order('created_at', ascending: false);
    return (rows as List).map((r) => SupportTicket.fromJson(r)).toList();
  }

  Future<String> insert(Map<String, dynamic> data) async {
    final row = await _table.insert(data).select().single();
    return row['id'] as String;
  }

  Future<void> updateStatus(String id, String status) => _table.update({'status': status}).eq('id', id);
}

class SupportMessagesRepository {
  final _table = SupabaseService.client.from('support_messages');

  Future<List<SupportMessage>> listForTicket(String ticketId) async {
    final rows = await _table
        .select('*, profiles(name)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return (rows as List).map((r) => SupportMessage.fromJson(r)).toList();
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);
}

class ShopReviewsRepository {
  final _table = SupabaseService.client.from('shop_reviews');

  Future<List<ShopReview>> listForShop(String shopId) async {
    final rows = await _table.select().eq('shop_id', shopId).order('created_at', ascending: false);
    return (rows as List).map((r) => ShopReview.fromJson(r)).toList();
  }

  Future<void> insert(Map<String, dynamic> data) => _table.insert(data);
}

class WishlistRepository {
  final _table = SupabaseService.client.from('wishlists');

  Future<List<WishlistItem>> listForCustomer(String customerId) async {
    final rows = await _table.select().eq('customer_id', customerId);
    return (rows as List).map((r) => WishlistItem.fromJson(r)).toList();
  }

  Future<void> add({required String customerId, required String itemType, required String itemId}) =>
      _table.insert({'customer_id': customerId, 'item_type': itemType, 'item_id': itemId});

  Future<void> remove({required String customerId, required String itemType, required String itemId}) => _table
      .delete()
      .eq('customer_id', customerId)
      .eq('item_type', itemType)
      .eq('item_id', itemId);
}
