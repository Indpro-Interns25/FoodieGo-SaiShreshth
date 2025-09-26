import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'cart_provider.dart';
import '../constants.dart';

enum AddressType { profile, other }

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Map<String, dynamic> _cartItems =
      {}; // dishId -> {name, price, quantity, ...}
  bool _loading = true;
  bool _submitting = false;
  String? _profileAddress;
  AddressType _addressType = AddressType.profile;
  final TextEditingController _otherAddressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadAddress();
  }

  @override
  void dispose() {
    _otherAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() {
      _loading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('cart_items');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _cartItems = decoded;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load cart for checkout: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadAddress() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final res = await supabase
          .from('customer_profiles')
          .select('address')
          .eq('user_id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _profileAddress = (res['address'] as String?)?.trim();
        });
      }
    } catch (e) {
      debugPrint('Failed to load address: $e');
    }
  }

  num get _subtotal {
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

  num get _restaurantShare => _subtotal * 0.90;
  num get _driverShare => _subtotal * 0.10;

  Future<String?> _getFreshAccessToken() async {
    try {
      final current = Supabase.instance.client.auth.currentSession;
      if (current != null) {
        try {
          final refreshed =
              await Supabase.instance.client.auth.refreshSession();
          final fresh = refreshed.session?.accessToken;
          if (fresh != null && fresh.isNotEmpty) return fresh;
        } catch (_) {
          // ignore and fall back
        }
        return current.accessToken;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session token: $e');
      return Supabase.instance.client.auth.currentSession?.accessToken;
    }
  }

  Future<void> _placeOrder() async {
    final token = await _getFreshAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing or invalid token. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('Cart is empty'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    String? deliveryAddress;
    if (_addressType == AddressType.profile) {
      deliveryAddress = _profileAddress;
    } else {
      deliveryAddress = _otherAddressController.text.trim();
    }

    if (deliveryAddress == null || deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(
        content: Text('Please select or enter a delivery address'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      // Get unique restaurants from cart
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final uniqueRestaurants = cartProvider.getUniqueRestaurants();
      final itemsByRestaurant = cartProvider.getItemsByRestaurant();

      if (uniqueRestaurants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No restaurants found in cart'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Prepare order items with restaurant_id
      final orderItems = <Map<String, dynamic>>[];
      for (final restaurant in uniqueRestaurants) {
        final restaurantId = restaurant['restaurant_id'] as String;
        final restaurantItems = itemsByRestaurant[restaurantId] ?? [];

        for (final item in restaurantItems) {
          orderItems.add({
            'dish_id': item['id'],
            'quantity': item['quantity'] ?? 1,
            'price': item['price'],
            'restaurant_id': restaurantId,
          });
        }
      }

      final orderData = {
        'delivery_address': deliveryAddress,
        'status': 'placed',
        'restaurant_ids': uniqueRestaurants.map((r) => r['restaurant_id']).toList(),
      };

      final body = jsonEncode({
        'order': orderData,
        'order_items': orderItems,
      });

      final response = await http
          .post(
            Uri.parse('$flaskApiUrl/create_order'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));
      print(response.body);

      if (response.statusCode == 200) {
        Provider.of<CartProvider>(context, listen: false).clearCart();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else if (response.statusCode == 401) {
        debugPrint('Unauthorized: ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        debugPrint('Order failed: ${response.statusCode} ${response.body}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Order error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text('Order error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: AppColors.surface,
        iconTheme: IconThemeData(color: AppColors.primary),
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cart Items',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._cartItems.entries.map((e) {
                                final item = e.value as Map<String, dynamic>;
                                final name = (item['name'] ?? 'Dish') as String;
                                final qty = (item['quantity'] ?? 1) as int;
                                final price = item['price'];
                                final lineTotal =
                                    (price is num ? price : 0) * qty;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '$name × $qty',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text('₹ ${lineTotal.toString()}'),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Delivery Address',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              RadioListTile<AddressType>(
                                title: Text(_profileAddress ?? 'No profile address'),
                                value: AddressType.profile,
                                groupValue: _addressType,
                                onChanged: (AddressType? value) {
                                  if (value != null) {
                                    setState(() {
                                      _addressType = value;
                                    });
                                  }
                                },
                              ),
                              RadioListTile<AddressType>(
                                title: const Text('Use a different address'),
                                value: AddressType.other,
                                groupValue: _addressType,
                                onChanged: (AddressType? value) {
                                  if (value != null) {
                                    setState(() {
                                      _addressType = value;
                                    });
                                  }
                                },
                              ),
                              if (_addressType == AddressType.other)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: TextField(
                                    controller: _otherAddressController,
                                    decoration: const InputDecoration(
                                      labelText: 'Enter new address',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              _row('Subtotal', _subtotal),
                              const Divider(),
                              _row('Restaurant share (90%)', _restaurantShare),
                              _row('Driver share (10%)', _driverShare),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '₹ ${_subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _submitting ? null : _placeOrder,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Place Order'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, num amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text('₹ ${amount.toStringAsFixed(2)}')],
      ),
    );
  }
}
