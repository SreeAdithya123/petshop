import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/async_utils.dart';
import '../core/crash_reporter.dart';
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

/// Parses every row, skipping (and reporting) the ones that don't fit the
/// model instead of letting one bad row take the whole catalog down.
List<T> _parseRows<T>(Object? rows, T Function(Map<String, dynamic> json) parse, String what) {
  if (rows is! List) return <T>[];
  final parsed = <T>[];
  for (final row in rows) {
    if (row is! Map<String, dynamic>) continue;
    try {
      parsed.add(parse(row));
    } catch (error, stack) {
      CrashReporting.report(error, stack, reason: 'catalog: skipped malformed $what row');
    }
  }
  return parsed;
}

/// Review stats are a nicety: if they can't be read (RLS change, slow
/// network) the catalog still loads, just without star ratings.
Future<List<dynamic>> _loadReviews() async {
  try {
    final rows = await SupabaseService.client.from('shop_reviews').select('shop_id, rating').eq('hidden', false);
    return rows;
  } catch (_) {
    return const <dynamic>[];
  }
}

/// Loads once and is shared across screens. Refresh with
/// `ref.invalidate(catalogProvider)` (e.g. after an order reserves a pet).
///
/// Riverpod 3 retries failed providers with backoff by default; for the
/// catalog that would delay the error state (and its "Retry" button) by ~40s
/// and create a retry storm on a bad connection, so retries are disabled and
/// screens expose their own retry. A request that hangs fails with a
/// `TimeoutException` after [AppEnv.requestTimeout]; screens turn any error
/// into friendly text with `errorText(error)`.
final catalogProvider = FutureProvider<Catalog>(retry: (retryCount, error) => null, (ref) async {
  final client = SupabaseService.client;
  final results = await withTimeout(
    Future.wait<Object?>([
      client.from('pets').select(petPublicColumns).eq('status', 'available').order('created_at', ascending: false),
      client.from('shops').select(shopPublicColumns).eq('status', 'approved').order('name', ascending: true),
      _loadReviews(),
    ]),
    message: 'Loading the catalog timed out.',
  );

  final totals = <String, List<int>>{}; // shopId -> [sum, count]
  for (final row in results[2] as List<dynamic>) {
    if (row is! Map<String, dynamic>) continue;
    final shopId = row['shop_id'];
    final rating = row['rating'];
    if (shopId is! String || rating is! num) continue;
    final entry = totals.putIfAbsent(shopId, () => [0, 0]);
    entry[0] += rating.toInt();
    entry[1] += 1;
  }

  final shops = _parseRows<Shop>(results[1], Shop.fromJson, 'shop');
  final shopIds = {for (final shop in shops) shop.id};
  final pets = _parseRows<Pet>(results[0], Pet.fromJson, 'pet').where((pet) => shopIds.contains(pet.shopId)).toList();

  final stats = <String, ShopStats>{
    for (final entry in totals.entries) entry.key: ShopStats(entry.value[0] / entry.value[1], entry.value[1]),
  };

  return Catalog(pets: pets, shops: shops, stats: stats);
});
