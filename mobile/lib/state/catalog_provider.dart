import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/columns.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

/// The customer-facing catalog, read from the real Supabase tables (the same
/// rows shop owners manage in their dashboard). Mirrors src/store/catalogStore.js.
///
/// Deliberately excludes pets.cost_price and shops.address / shops.phone (see
/// data/columns.dart). RLS already limits anonymous/customer reads to
/// "available" pets in approved shops.

class ShopStats {
  final double rating;
  final int reviewCount;
  const ShopStats(this.rating, this.reviewCount);
  static const none = ShopStats(0, 0);
}

class Catalog {
  final List<Pet> pets;
  final List<Shop> shops;
  final Map<String, ShopStats> stats;

  const Catalog({required this.pets, required this.shops, required this.stats});

  Pet? petById(String id) {
    for (final pet in pets) {
      if (pet.id == id) return pet;
    }
    return null;
  }

  Shop? shopById(String id) {
    for (final shop in shops) {
      if (shop.id == id) return shop;
    }
    return null;
  }

  List<Pet> petsByShop(String shopId) => pets.where((p) => p.shopId == shopId).toList();

  ShopStats statsFor(String shopId) => stats[shopId] ?? ShopStats.none;

  List<String> get speciesList => ({for (final p in pets) p.species}.toList()..sort());

  List<String> get breedList => ({for (final p in pets) p.breed}.toList()..sort());
}

/// Loads once and is shared across screens. Refresh with
/// `ref.invalidate(catalogProvider)` (e.g. after an order reserves a pet).
///
/// Riverpod 3 retries failed providers with backoff by default; for the
/// catalog that would delay the error state (and its "Try again" button) by
/// ~40s, so retries are disabled and screens expose their own retry.
final catalogProvider = FutureProvider<Catalog>(retry: (retryCount, error) => null, (ref) async {
  final client = SupabaseService.client;
  final results = await Future.wait([
    client.from('pets').select(petPublicColumns).eq('status', 'available').order('created_at', ascending: false),
    client.from('shops').select(shopPublicColumns).eq('status', 'approved').order('name', ascending: true),
    client.from('shop_reviews').select('shop_id, rating').eq('hidden', false),
  ]);

  final totals = <String, List<int>>{}; // shopId -> [sum, count]
  for (final row in (results[2] as List).cast<Map<String, dynamic>>()) {
    final entry = totals.putIfAbsent(row['shop_id'] as String, () => [0, 0]);
    entry[0] += (row['rating'] as num).toInt();
    entry[1] += 1;
  }

  final shops = (results[1] as List).map((r) => Shop.fromJson(r as Map<String, dynamic>)).toList();
  final shopIds = {for (final shop in shops) shop.id};
  final pets = (results[0] as List)
      .map((r) => Pet.fromJson(r as Map<String, dynamic>))
      .where((pet) => shopIds.contains(pet.shopId))
      .toList();

  final stats = <String, ShopStats>{
    for (final entry in totals.entries) entry.key: ShopStats(entry.value[0] / entry.value[1], entry.value[1]),
  };

  return Catalog(pets: pets, shops: shops, stats: stats);
});
