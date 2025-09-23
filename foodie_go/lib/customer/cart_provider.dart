
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartProvider with ChangeNotifier {
  Map<String, dynamic> _cartItems = {};

  Map<String, dynamic> get cartItems => _cartItems;

  num get subtotal {
    num total = 0;
    for (final value in _cartItems.values) {
      if (value is Map<String, dynamic>) {
        final q = value['quantity'] as int? ?? 0;
        final p = value['price'];
        if (p is num) total += p * q;
      }
    }
    return total;
  }

  int get cartCount {
    int total = 0;
    for (final entry in _cartItems.values) {
      final qty = (entry['quantity'] ?? 0) as int;
      total += qty;
    }
    return total;
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cart_items');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _cartItems = decoded;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to load cart: $e');
    }
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cart_items', jsonEncode(_cartItems));
    } catch (e) {
      debugPrint('Failed to save cart: $e');
    }
  }

  void addToCart(Map<String, dynamic> dish, int qty) {
    final String dishId = (dish['id'] ?? '').toString();
    if (dishId.isEmpty) {
      return;
    }
    final String name = (dish['name'] ?? 'Dish') as String;
    final dynamic price = dish['price'];
    final String? imageUrl = dish['image'] as String?;
    final String ownerId = (dish['user_id_res'] ?? '') as String;
    final String restaurantName = dish['restaurantName'] ?? 'Restaurant';

    if (_cartItems.containsKey(dishId)) {
      final existing = _cartItems[dishId] as Map<String, dynamic>;
      final int oldQty = (existing['quantity'] ?? 0) as int;
      existing['quantity'] = oldQty + qty;
      existing['price'] = price; // keep latest price
      existing['name'] = name;
      existing['imageUrl'] = imageUrl;
      existing['restaurantName'] = restaurantName;
      existing['restaurant_id'] = ownerId;
      _cartItems[dishId] = existing;
    } else {
      _cartItems[dishId] = {
        'id': dishId,
        'name': name,
        'price': price,
        'quantity': qty,
        'imageUrl': imageUrl,
        'restaurantName': restaurantName,
        'restaurant_id': ownerId,
      };
    }
    _saveCart();
    notifyListeners();
  }

  void removeFromCart(String dishId) {
    if (!_cartItems.containsKey(dishId)) return;
    _cartItems.remove(dishId);
    _saveCart();
    notifyListeners();
  }

  void incrementQuantity(String dishId) {
    if (!_cartItems.containsKey(dishId)) return;
    final item = _cartItems[dishId] as Map<String, dynamic>;
    final current = (item['quantity'] ?? 1) as int;
    item['quantity'] = current + 1;
    _cartItems[dishId] = item;
    _saveCart();
    notifyListeners();
  }

  void decrementQuantity(String dishId) {
    if (!_cartItems.containsKey(dishId)) return;
    final item = _cartItems[dishId] as Map<String, dynamic>;
    final current = (item['quantity'] ?? 1) as int;
    if (current > 1) {
      item['quantity'] = current - 1;
      _cartItems[dishId] = item;
      _saveCart();
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    _cartItems.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_items');
    notifyListeners();
  }
}
