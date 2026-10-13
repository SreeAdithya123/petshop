import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/repositories.dart';
import 'auth_provider.dart';

/// Pet wishlist backed by the `wishlists` table (item_type 'pet'), replacing
/// the old local-only wishlist. Mirrors src/store/wishlistStore.js.
///
/// Signed-out users have no wishlist: [signedIn] is false and [toggle]
/// returns a message asking them to log in -- callers should send them to
/// /login instead of calling it.
class WishlistController extends ChangeNotifier {
  WishlistController(this._userId) {
    load();
  }

  final String? _userId;
  final _repo = WishlistRepository();

  Set<String> petIds = {};
  bool loading = false;

  bool get signedIn => _userId != null;

  bool isWishlisted(String petId) => petIds.contains(petId);

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    loading = true;
    notifyListeners();
    try {
      final rows = await _repo.listForCustomer(userId);
      petIds = {for (final row in rows) if (row.itemType == 'pet') row.itemId};
    } catch (_) {
      // Keep whatever we had; the heart simply won't reflect server state.
    }
    loading = false;
    notifyListeners();
  }

  /// Adds/removes [petId]. Returns null on success, or an error message.
  Future<String?> toggle(String petId) async {
    final userId = _userId;
    if (userId == null) return 'Log in to save pets to your wishlist.';
    final wasWishlisted = petIds.contains(petId);
    // Optimistic update, rolled back on failure.
    petIds = wasWishlisted ? ({...petIds}..remove(petId)) : {...petIds, petId};
    notifyListeners();
    try {
      if (wasWishlisted) {
        await _repo.remove(customerId: userId, itemType: 'pet', itemId: petId);
      } else {
        await _repo.add(customerId: userId, itemType: 'pet', itemId: petId);
      }
      return null;
    } catch (error) {
      petIds = wasWishlisted ? {...petIds, petId} : ({...petIds}..remove(petId));
      notifyListeners();
      return error is PostgrestException ? error.message : error.toString();
    }
  }
}

final wishlistControllerProvider = ChangeNotifierProvider<WishlistController>((ref) {
  final auth = ref.watch(authControllerProvider);
  final isCustomer = auth.status == AuthStatus.signedIn && auth.profile?.role == 'customer';
  return WishlistController(isCustomer ? auth.profile!.id : null);
});
