import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../core/app_error.dart';
import '../core/async_utils.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';

/// Pet wishlist backed by the `wishlists` table (item_type 'pet'), replacing
/// the old local-only wishlist. Mirrors src/store/wishlistStore.js.
///
/// Signed-out users have no wishlist: [signedIn] is false and [toggle]
/// returns a message asking them to log in -- callers should send them to
/// /login instead of calling it.
///
/// The controller is rebuilt for every account change (see
/// [wishlistControllerProvider]), so signing out -- or switching accounts --
/// always starts from an empty wishlist.
class WishlistController extends ChangeNotifier {
  WishlistController(this._userId) {
    load();
  }

  final String? _userId;
  final _repo = WishlistRepository();
  bool _disposed = false;

  Set<String> petIds = {};
  bool loading = false;

  /// True when the last [load] failed (offline, timeout); the hearts then
  /// reflect only what was toggled in this session.
  bool loadFailed = false;

  bool get signedIn => _userId != null;

  bool isWishlisted(String petId) => petIds.contains(petId);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final userId = _userId;
    if (userId == null) return;
    loading = true;
    _notify();
    try {
      final rows = await withTimeout(_repo.listForCustomer(userId));
      if (_disposed) return;
      petIds = {for (final row in rows) if (row.itemType == 'pet') row.itemId};
      loadFailed = false;
    } catch (_) {
      // Keep whatever we had; the heart simply won't reflect server state.
      loadFailed = true;
    }
    if (_disposed) return;
    loading = false;
    _notify();
  }

  /// Adds/removes [petId]. Returns null on success, or a friendly error
  /// message.
  Future<String?> toggle(String petId) async {
    final userId = _userId;
    if (userId == null) return 'Log in to save pets to your wishlist.';
    final wasWishlisted = petIds.contains(petId);
    // Optimistic update, rolled back on failure.
    petIds = wasWishlisted ? ({...petIds}..remove(petId)) : {...petIds, petId};
    _notify();
    try {
      if (wasWishlisted) {
        await withTimeout(_repo.remove(customerId: userId, itemType: 'pet', itemId: petId));
      } else {
        await withTimeout(_repo.add(customerId: userId, itemType: 'pet', itemId: petId));
      }
      return null;
    } catch (error) {
      if (!wasWishlisted && _isDuplicate(error)) {
        // Already saved on the server (double tap / another device): the
        // optimistic state is right, nothing to roll back.
        return null;
      }
      petIds = wasWishlisted ? {...petIds, petId} : ({...petIds}..remove(petId));
      _notify();
      return friendlyError(error, fallback: "Couldn't update your wishlist. Please try again.");
    }
  }

  /// Postgres unique violation: the pet is already on the server wishlist.
  bool _isDuplicate(Object error) => error is PostgrestException && error.code == '23505';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The id of the signed-in customer, or null for everyone else (signed out,
/// shop owners, admins). Selecting just the id keeps the wishlist from
/// reloading on unrelated auth changes such as a profile refresh.
final _wishlistUserIdProvider = Provider<String?>((ref) {
  final userId = ref.watch(
    authControllerProvider.select(
      (auth) => auth.status == AuthStatus.signedIn && auth.profile?.role == 'customer' ? auth.profile?.id : null,
    ),
  );
  return userId;
});

final wishlistControllerProvider = ChangeNotifierProvider<WishlistController>((ref) {
  return WishlistController(ref.watch(_wishlistUserIdProvider));
});
