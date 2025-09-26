import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
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

      // Fetch orders where restaurant is involved (either user_id_res or in restaurant_ids array)
      final data = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .or('user_id_res.eq.${user.id}')
          .filter('status', 'in', '(placed,confirmed,"order called for delivery")');

      // Also fetch multi-restaurant orders that include this restaurant
      final multiRestaurantData = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .not('restaurant_ids', 'is', null)
          .filter('status', 'in', '(placed,confirmed,"order called for delivery")');

      // Filter multi-restaurant orders to only include those where this restaurant is involved
      final filteredMultiData = multiRestaurantData.where((order) {
        final restaurantIds = order['restaurant_ids'] as List<dynamic>?;
        return restaurantIds != null && restaurantIds.any((id) => id == user.id);
      }).toList();

      // Combine the lists and remove duplicates
      final allOrders = [...data, ...filteredMultiData];
      final uniqueOrders = <dynamic>[];
      final seenIds = <String>{};
      for (var order in allOrders) {
        final orderId = order['id'] as String?;
        if (orderId != null && !seenIds.contains(orderId)) {
          seenIds.add(orderId);
          uniqueOrders.add(order);
        }
      }

      // Collect all dish_ids from order_items that belong to this restaurant
      Set<String> dishIds = {};
      for (var order in uniqueOrders) {
        final items = order['order_items'] as List<dynamic>? ?? [];
        for (var item in items) {
          // Only include items where restaurant_id matches this restaurant's user_id
          if (item['restaurant_id'] == user.id) {
            dishIds.add(item['dish_id'] as String);
          }
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

      // Attach dish details to order_items and filter to only this restaurant's items
      for (var order in uniqueOrders) {
        List<dynamic> filteredItems = [];
        final items = order['order_items'] as List<dynamic>? ?? [];
        for (var item in items) {
          if (item['restaurant_id'] == user.id) {
            item['dishes'] = dishesMap[item['dish_id']] ?? {'name': 'Unknown', 'price': 0};
            filteredItems.add(item);
          }
        }
        order['order_items'] = filteredItems;

        // Fetch approval_status for this restaurant
        try {
          final approvalResp = await supabase
              .from('order_restaurants')
              .select('approval_status')
              .eq('order_id', order['id'])
              .eq('restaurant_id', user.id)
              .single();
          order['approval_status'] = approvalResp['approval_status'] ?? 'pending';
        } catch (e) {
          order['approval_status'] = 'pending';
        }
      }

      // Sort orders by id descending to show newest first
      uniqueOrders.sort((a, b) {
        final aId = a['id'] as String? ?? '';
        final bId = b['id'] as String? ?? '';
        return bId.compareTo(aId);
      });

      setState(() {
        orders = uniqueOrders;
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

  Future<void> approveOrder(String orderId) async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$flaskApiUrl/approve_restaurant_order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_id': orderId,
        }),
      );

      if (response.statusCode == 200) {
        fetchOrders();
      } else {
        print('Error approving order: ${response.body}');
      }
    } catch (e) {
      print('Error approving order: $e');
    }
  }

  Future<void> updateItemStatus(String itemId, String newStatus) async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$flaskApiUrl/update_item_status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_item_id': itemId,
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        fetchOrders();
      } else {
        print('Error updating item status: ${response.body}');
      }
    } catch (e) {
      print('Error updating item status: $e');
    }
  }



  Widget buildOrderCard(dynamic order) {
    final orderId = order['id'] as String;
    final status = order['status'] as String? ?? 'placed';
    final deliveryAddress = order['delivery_address'] as String? ?? '';
    final items = order['order_items'] as List<dynamic>? ?? [];
    final approvalStatus = order['approval_status'] as String? ?? 'pending';

    String nextStatus;
    String buttonText;
    bool showApproveButton = false;

    // Check if all items are ready for pickup
    bool allItemsReady = items.every((item) => item['status'] == 'ready_for_pickup');

    if (status == 'placed' && approvalStatus == 'pending') {
      nextStatus = 'confirmed';
      buttonText = 'Approve Order';
      showApproveButton = true;
    } else if (status == 'confirmed' && allItemsReady) {
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
              final itemStatus = item['status'] ?? 'placed';
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('$dishName × $quantity - \$${price * quantity} (Status: $itemStatus)'),
                    ),
                    if (itemStatus == 'placed' && status == 'confirmed')
                      ElevatedButton(
                        onPressed: () => updateItemStatus(item['id'], 'ready_for_pickup'),
                        child: Text('Ready'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
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
                  if (showApproveButton)
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Confirm Approval'),
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
                                  Text('Approve this order?'),
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
                                    approveOrder(orderId);
                                  },
                                  child: Text('Approve'),
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
                    )
                  else if (buttonText.isNotEmpty)
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
