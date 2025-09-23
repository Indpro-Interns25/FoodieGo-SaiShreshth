import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class DriverOrders extends StatefulWidget {
  const DriverOrders({super.key});

  @override
  State<DriverOrders> createState() => _DriverOrdersState();
}

class _DriverOrdersState extends State<DriverOrders> {
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

      // Fetch assigned orders
      final assignedData = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id_dri', user.id)
          .filter('status', 'in', '(order called for delivery,waiting for delivery,waiting for confirmation)');

      // Fetch unassigned orders available for acceptance
      final unassignedData = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .filter('user_id_dri', 'is', null)
          .eq('status', 'order called for delivery');

      // Combine the lists
      final data = [...assignedData, ...unassignedData];

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

      // Sort orders: assigned orders first (descending by id), then unassigned orders (descending by id)
      data.sort((a, b) {
        final aAssigned = a['user_id_dri'] == supabase.auth.currentUser?.id;
        final bAssigned = b['user_id_dri'] == supabase.auth.currentUser?.id;
        if (aAssigned && !bAssigned) return -1;
        if (!aAssigned && bAssigned) return 1;
        return (b['id'] as String).compareTo(a['id'] as String);
      });

      if (!mounted) return;
      setState(() {
        orders = data as List<dynamic>;
      });
    } catch (e) {
      print('Exception fetching orders: $e');
    }
  }

  bool _updatingStatus = false;

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    setState(() {
      _updatingStatus = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('https://foodie-go-flask.vercel.app/update_order_status_driver'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_id': orderId,
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        await fetchOrders();
      } else {
        print('Error updating order status: ${response.body}');
      }
    } catch (e) {
      print('Error updating order status: $e');
    } finally {
      setState(() {
        _updatingStatus = false;
      });
    }
  }

  Future<void> acceptOrder(String orderId) async {
    setState(() {
      _updatingStatus = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('https://foodie-go-flask.vercel.app/accept_order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_id': orderId,
        }),
      );

      if (response.statusCode == 200) {
        await fetchOrders();
      } else {
        print('Error accepting order: ${response.body}');
      }
    } catch (e) {
      print('Error accepting order: $e');
    } finally {
      setState(() {
        _updatingStatus = false;
      });
    }
  }

  Widget buildOrderCard(dynamic order) {
    final orderId = order['id'] as String;
    final status = order['status'] as String? ?? 'order called for delivery';
    final deliveryAddress = order['delivery_address'] as String? ?? '';
    final pickupAddress = 'Restaurant address not available';
    final items = order['order_items'] as List<dynamic>? ?? [];
    final isAssigned = order['user_id_dri'] != null;
    final isAssignedToCurrent = order['user_id_dri'] == supabase.auth.currentUser?.id;

    String nextStatus;
    String buttonText;
    VoidCallback? onPressed;
    if (!isAssigned && status == 'order called for delivery') {
      nextStatus = 'waiting for delivery';
      buttonText = 'Accept';
      onPressed = () => acceptOrder(orderId);
    } else if (status == 'order called for delivery') {
      nextStatus = 'waiting for delivery';
      buttonText = 'Picked Up';
      onPressed = () => updateOrderStatus(orderId, nextStatus);
    } else if (status == 'waiting for delivery') {
      nextStatus = 'waiting for confirmation';
      buttonText = 'Delivered';
      onPressed = () => updateOrderStatus(orderId, nextStatus);
    } else {
      nextStatus = status; // no change
      buttonText = '';
      onPressed = null;
    }

    Color? cardColor;
    if (isAssignedToCurrent) {
      cardColor = Colors.green[100];
    } else if (status == 'waiting for confirmation') {
      cardColor = Colors.yellow[100];
    } else {
      cardColor = null;
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      color: cardColor,
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
            SizedBox(height: 4),
            Text('Pickup Address: $pickupAddress'),
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
            if (status == 'delivered')
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Delivered',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              )
            else if (status == 'waiting for confirmation')
              Row(
                children: [
                  Icon(Icons.access_time, color: Colors.yellow),
                  SizedBox(width: 8),
                  Text('Waiting for Confirmation',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.yellow[700])),
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
                    onPressed: buttonText == 'Accept' ? onPressed : () {
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
                                SizedBox(height: 4),
                                Text('Pickup Address: $pickupAddress'),
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
                                  if (onPressed != null) onPressed();
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
    return RefreshIndicator(
      onRefresh: fetchOrders,
      child: orders.isEmpty
          ? SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height,
                child: Center(
                  child: Text(
                    'No orders available.',
                    style: TextStyle(fontSize: 18, color: AppColors.primary),
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return buildOrderCard(orders[index]);
              },
            ),
    );
  }
}

