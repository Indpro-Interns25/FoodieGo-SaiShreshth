import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  final supabase = Supabase.instance.client;
  List<dynamic> orders = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchOrders();
    // Set up periodic refresh every 10 seconds for real-time updates
    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      fetchOrders();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchOrders() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          orders = [];
        });
        return;
      }

      final data = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id_res', user.id)
          .filter('status', 'in', '(placed,approved,"order called for delivery")');

      // Collect all dish_ids
      Set<String> dishIds = {};
      for (var order in data) {
        for (var item in order['order_items']) {
          dishIds.add(item['dish_id']);
        }
      }

      // Fetch dish details
      Map<String, dynamic> dishesMap = {};
      for (var id in dishIds) {
        try {
          final dish = await supabase
              .from('dishes')
              .select('id, name, price')
              .eq('id', id)
              .single();
          dishesMap[id] = dish;
        } catch (e) {
          // Dish not found, skip
        }
      }

      // Attach dish details to order_items
      for (var order in data) {
        for (var item in order['order_items']) {
          item['dishes'] = dishesMap[item['dish_id']] ?? {'name': 'Unknown', 'price': 0};
        }
      }

      // Sort orders by id descending to show newest first
      data.sort((a, b) => (b['id'] as String).compareTo(a['id'] as String));

      setState(() {
        orders = data as List<dynamic>;
      });
    } catch (e) {
      print('Exception fetching orders: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      fetchOrders();
    } catch (e) {
      print('Error updating order status: $e');
    }
  }



  Widget buildOrderCard(dynamic order) {
    final orderId = order['id'] as String;
    final status = order['status'] as String? ?? 'placed';
    final deliveryAddress = order['delivery_address'] as String? ?? '';
    final items = order['order_items'] as List<dynamic>? ?? [];

    String nextStatus;
    String buttonText;
    if (status == 'placed') {
      nextStatus = 'approved';
      buttonText = 'Approve Order';
    } else if (status == 'approved') {
      nextStatus = 'order called for delivery';
      buttonText = 'Call for Delivery';
    } else {
      nextStatus = status; // no change
      buttonText = '';
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: $orderId',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary)),
            SizedBox(height: 4),
            Text('Delivery Address: $deliveryAddress'),
            SizedBox(height: 8),
            Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...items.map((item) {
              final dish = item['dishes'];
              final dishName = dish != null ? dish['name'] : 'Unknown';
              final price = dish != null ? dish['price'] : 0;
              final quantity = item['quantity'] ?? 1;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('$dishName × $quantity - \$${price * quantity}'),
              );
            }).toList(),
            SizedBox(height: 8),
            if (status == 'order called for delivery')
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Order Called for Delivery',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $status',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Confirm Status Change'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Order ID: $orderId'),
                                SizedBox(height: 8),
                                Text('Delivery Address: $deliveryAddress'),
                                SizedBox(height: 8),
                                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                                ...items.map((item) {
                                  final dish = item['dishes'];
                                  final dishName = dish != null ? dish['name'] : 'Unknown';
                                  final price = dish != null ? dish['price'] : 0;
                                  final quantity = item['quantity'] ?? 1;
                                  return Text('$dishName × $quantity - \$${price * quantity}');
                                }).toList(),
                                SizedBox(height: 8),
                                Text('Change status to: $nextStatus'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  updateOrderStatus(orderId, nextStatus);
                                },
                                child: Text('Confirm'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Text(buttonText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          'No orders found.',
          style: TextStyle(fontSize: 18, color: AppColors.primary),
        ),
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return buildOrderCard(orders[index]);
      },
    );
  }
}
