import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_provider.dart';
import 'checkout.dart';
import '../constants.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: cartProvider.cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 60,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildRestaurantGroups(context, cartProvider),
                  ),
                ),
                _CartSummary(
                  subtotal: cartProvider.subtotal,
                  onCheckout: () async {
                    final placed = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CheckoutPage(),
                      ),
                    );
                    if (placed == true && context.mounted) {
                      cartProvider.loadCart();
                    }
                  },
                ),
              ],
            ),
    );
  }

  List<Widget> _buildRestaurantGroups(BuildContext context, CartProvider cartProvider) {
    final itemsByRestaurant = cartProvider.getItemsByRestaurant();
    final uniqueRestaurants = cartProvider.getUniqueRestaurants();
    final widgets = <Widget>[];

    for (final restaurant in uniqueRestaurants) {
      final restaurantId = restaurant['restaurant_id'] as String;
      final restaurantName = restaurant['restaurantName'] as String;
      final restaurantAddress = restaurant['restaurantAddress'] as String;
      final restaurantItems = itemsByRestaurant[restaurantId] ?? [];

      // Add restaurant header
      widgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurantName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                restaurantAddress,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );

      // Add items for this restaurant
      for (final item in restaurantItems) {
        final dishId = item['id'] as String;
        final name = (item['name'] ?? 'Dish') as String;
        final price = item['price'];
        final qty = (item['quantity'] ?? 1) as int;
        final imageUrl = item['imageUrl'] as String?;

        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CartItemTile(
              dishId: dishId,
              name: name,
              restaurant: restaurantName,
              price: price,
              quantity: qty,
              imageUrl: imageUrl,
              onInc: () => cartProvider.incrementQuantity(dishId),
              onDec: () => cartProvider.decrementQuantity(dishId),
              onRemove: () {
                cartProvider.removeFromCart(dishId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item removed from cart')),
                );
              },
            ),
          ),
        );
      }

      // Add spacing between restaurants
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }
}

class _CartItemTile extends StatelessWidget {
  final String dishId;
  final String name;
  final String restaurant;
  final dynamic price;
  final int quantity;
  final String? imageUrl;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.dishId,
    required this.name,
    required this.restaurant,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 70,
                height: 70,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    : _imageFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹ ${price?.toString() ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: onDec,
                          ),
                          Text('$quantity'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: onInc,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.surface,
      child: Icon(Icons.image_not_supported, color: AppColors.textLight),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final num subtotal;
  final VoidCallback onCheckout;

  const _CartSummary({required this.subtotal, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 6,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Subtotal', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onCheckout,
              child: const Text('Checkout'),
            ),
          ],
        ),
      ),
    );
  }
}
