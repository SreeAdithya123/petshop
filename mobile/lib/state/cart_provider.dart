import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors src/store/cartStore.js (the wishlist now lives in
/// wishlist_provider.dart, backed by the database): a cart line item is just an
/// {itemType, itemId} pair (no quantity -- a pet is a unique animal, and
/// this mobile build treats store products the same way for simplicity).
/// Names, prices and shops are resolved from the live catalog at render time
/// and never stored, so a sold or repriced pet can't leave a stale cart line;
/// [CartController.prunePets] drops pets the catalog no longer lists.
/// Persisted locally via SharedPreferences (the web app's equivalent used
/// localStorage), same "no network calls here, UI-only state" boundary.
class CartLine {
  final String itemType; // pet | product
  final String itemId;
  const CartLine(this.itemType, this.itemId);

  Map<String, String> toJson() => {'itemType': itemType, 'itemId': itemId};
  factory CartLine.fromJson(Map<String, dynamic> json) =>
      CartLine(json['itemType'] as String, json['itemId'] as String);

  @override
  bool operator ==(Object other) =>
      other is CartLine && other.itemType == itemType && other.itemId == itemId;
  @override
  int get hashCode => Object.hash(itemType, itemId);
}

class CartController extends ChangeNotifier {
  static const _cartKey = 'petstore.cart.v1';

  List<CartLine> items = [];

  CartController() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = _decode(prefs.getString(_cartKey));
      // Keep anything added while the stored cart was still being read.
      items = [...stored, ...items.where((line) => !stored.contains(line))];
    } catch (_) {
      // Unreadable storage: carry on with the in-memory cart.
    }
    notifyListeners();
  }

  /// Malformed or old-shaped storage must never break startup.
  List<CartLine> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final lines = <CartLine>[];
      for (final entry in list) {
        if (entry is! Map<String, dynamic>) continue;
        final type = entry['itemType'];
        final id = entry['itemId'];
        if (type is String && id is String && id.isNotEmpty) {
          final line = CartLine(type, id);
          if (!lines.contains(line)) lines.add(line);
        }
      }
      return lines;
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cartKey, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {
      // The in-memory cart still works if the write fails.
    }
  }

  bool isInCart(String itemType, String itemId) => items.contains(CartLine(itemType, itemId));

  Future<void> addToCart(String itemType, String itemId) async {
    final line = CartLine(itemType, itemId);
    if (items.contains(line)) return;
    items = [...items, line];
    notifyListeners();
    await _persist();
  }

  Future<void> removeFromCart(String itemType, String itemId) async {
    items = items.where((e) => e != CartLine(itemType, itemId)).toList();
    notifyListeners();
    await _persist();
  }

  /// Drops cart pets that are no longer in [validPetIds] (sold, reserved or
  /// deleted since they were added). Returns how many lines were removed.
  Future<int> prunePets(Set<String> validPetIds) async {
    final kept = items.where((e) => e.itemType != 'pet' || validPetIds.contains(e.itemId)).toList();
    final removed = items.length - kept.length;
    if (removed == 0) return 0;
    items = kept;
    notifyListeners();
    await _persist();
    return removed;
  }

  Future<void> clearCart() async {
    items = [];
    notifyListeners();
    await _persist();
  }
}

final cartControllerProvider = ChangeNotifierProvider<CartController>((ref) {
  return CartController();
});
