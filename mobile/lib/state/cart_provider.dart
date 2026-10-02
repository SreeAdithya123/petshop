import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors src/store/cartStore.js: a cart line item is just an
/// {itemType, itemId} pair (no quantity -- a pet is a unique animal, and
/// this mobile build treats store products the same way for simplicity).
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
  static const _wishlistKey = 'petstore.wishlist.v1';

  List<CartLine> items = [];
  List<CartLine> wishlist = [];

  CartController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    items = _decode(prefs.getString(_cartKey));
    wishlist = _decode(prefs.getString(_wishlistKey));
    notifyListeners();
  }

  List<CartLine> _decode(String? raw) {
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => CartLine.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _persist(String key, List<CartLine> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value.map((e) => e.toJson()).toList()));
  }

  bool isInCart(String itemType, String itemId) => items.contains(CartLine(itemType, itemId));

  Future<void> addToCart(String itemType, String itemId) async {
    final line = CartLine(itemType, itemId);
    if (items.contains(line)) return;
    items = [...items, line];
    notifyListeners();
    await _persist(_cartKey, items);
  }

  Future<void> removeFromCart(String itemType, String itemId) async {
    items = items.where((e) => e != CartLine(itemType, itemId)).toList();
    notifyListeners();
    await _persist(_cartKey, items);
  }

  Future<void> clearCart() async {
    items = [];
    notifyListeners();
    await _persist(_cartKey, items);
  }

  bool isInWishlist(String itemType, String itemId) => wishlist.contains(CartLine(itemType, itemId));

  Future<void> toggleWishlist(String itemType, String itemId) async {
    final line = CartLine(itemType, itemId);
    wishlist = wishlist.contains(line)
        ? wishlist.where((e) => e != line).toList()
        : [...wishlist, line];
    notifyListeners();
    await _persist(_wishlistKey, wishlist);
  }
}

final cartControllerProvider = ChangeNotifierProvider<CartController>((ref) {
  return CartController();
});
