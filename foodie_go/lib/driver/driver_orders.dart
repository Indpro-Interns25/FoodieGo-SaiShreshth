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
  List<Map<String, dynamic>> orders = [];
  Timer? _timer;
  // Track acquired restaurants per order: Map<orderId, Set<restaurantId>>
  Map<String, Set<String>> acquiredRestaurants = {};

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
          .filter('status', 'in', '(confirmed,"order called for delivery")');

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

      // Fetch restaurant addresses for all orders (multi and single restaurant)
      for (var order in data) {
        final restaurantIds = order['restaurant_ids'];
        final userIdRes = order['user_id_res'];
        List<String> idsToFetch = [];

        if (restaurantIds != null && restaurantIds is List && restaurantIds.isNotEmpty) {
          idsToFetch = List<String>.from(restaurantIds);
        } else if (userIdRes != null) {
          // Backward compatibility for single restaurant orders without restaurant_ids
          idsToFetch = [userIdRes];
        }

        if (idsToFetch.isNotEmpty) {
          try {
            final response = await http.post(
              Uri.parse('$flaskApiUrl/get_restaurant_addresses'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
              },
              body: jsonEncode({
                'restaurant_ids': idsToFetch,
              }),
            );

            if (response.statusCode == 200) {
              final addressData = jsonDecode(response.body);
              order['restaurant_addresses'] = addressData['addresses'];
            }
          } catch (e) {
            print('Error fetching restaurant addresses: $e');
          }
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
        orders = data;
      });

      // Sync acquired restaurants from database
      for (var order in orders) {
        final orderId = order['id'] as String;
        final acquired = order['acquired_restaurants'] as List<dynamic>? ?? [];
        acquiredRestaurants[orderId] = Set<String>.from(acquired.map((e) => e.toString()));
      }
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
        Uri.parse('$flaskApiUrl/update_order_status_driver'),
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

  Future<void> acquireRestaurant(String orderId, String restaurantId) async {
    setState(() {
      _updatingStatus = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$flaskApiUrl/acquire_restaurant_for_order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_id': orderId,
          'restaurant_id': restaurantId,
        }),
      );

      if (response.statusCode == 200) {
        // Update local tracking
        setState(() {
          acquiredRestaurants.putIfAbsent(orderId, () => {}).add(restaurantId);
        });

        // Check if all restaurants are acquired for this order
        final matchingOrders = orders.where((o) => o['id'] == orderId).toList();
        if (matchingOrders.isNotEmpty) {
          final order = matchingOrders.first;
          final restaurantIds = order['restaurant_ids'] as List<dynamic>? ?? [];
          final acquired = acquiredRestaurants[orderId] ?? {};
          if (restaurantIds.every((rid) => acquired.contains(rid))) {
            // All restaurants acquired, auto-progress to 'waiting for delivery'
            await updateOrderStatus(orderId, 'waiting for delivery');
          }
        }
      } else {
        print('Error acquiring restaurant: ${response.body}');
      }
    } catch (e) {
      print('Error acquiring restaurant: $e');
    } finally {
      setState(() {
        _updatingStatus = false;
      });
    }
  }

  Future<void> pickupItems(String orderId, String restaurantId) async {
    setState(() {
      _updatingStatus = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$flaskApiUrl/pickup_items'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_id': orderId,
          'restaurant_id': restaurantId,
        }),
      );

      if (response.statusCode == 200) {
        await fetchOrders();
      } else {
        print('Error picking up items: ${response.body}');
      }
    } catch (e) {
      print('Error picking up items: $e');
    } finally {
      setState(() {
        _updatingStatus = false;
      });
    }
  }

  Future<void> acceptOrder(String orderId) async {
    // Find the order to get addresses
    final matchingOrders = orders.where((o) => o['id'] == orderId).toList();
    if (matchingOrders.isEmpty) return;
    final order = matchingOrders.first;

    final restaurantAddresses = order['restaurant_addresses'] as List<dynamic>? ?? [];

    // Show confirmation dialog with pickup addresses
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Accept Order'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pickup Locations:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                if (restaurantAddresses.isEmpty)
                  Text('No pickup addresses available')
                else
                  ...restaurantAddresses.map((restaurant) {
                    final restaurantName = restaurant['restaurant_name'] ?? 'Unknown Restaurant';
                    final address = restaurant['address'] ?? 'Address not provided';
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.store, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$restaurantName: $address',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                SizedBox(height: 16),
                Text('Do you want to accept this order?', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Accept'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      _updatingStatus = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('$flaskApiUrl/accept_order'),
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
    final items = order['order_items'] as List<dynamic>? ?? [];
    final isAssigned = order['user_id_dri'] != null;
    final isAssignedToCurrent = order['user_id_dri'] == supabase.auth.currentUser?.id;
    final restaurantAddresses = order['restaurant_addresses'] as List<dynamic>? ?? [];
    final restaurantIds = order['restaurant_ids'] as List<dynamic>? ?? [];
    final isSingleRestaurant = restaurantIds.length == 1;

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
            SizedBox(height: 8),

            // Restaurant pickup addresses
            if (restaurantAddresses.isNotEmpty) ...[
              Text('Pickup Locations:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              ...restaurantAddresses.map((restaurant) {
                final restaurantName = restaurant['restaurant_name'] ?? 'Unknown Restaurant';
                final address = restaurant['address'] ?? 'Address not provided';
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.store, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$restaurantName: $address',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              SizedBox(height: 8),
            ],

            Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            // Group items by restaurant
            ...(() {
              Map<String, List<dynamic>> itemsByRestaurant = {};
              for (var item in items) {
                final restaurantId = item['restaurant_id'] as String? ?? 'unknown';
                itemsByRestaurant.putIfAbsent(restaurantId, () => []).add(item);
              }

              List<Widget> restaurantWidgets = [];
              itemsByRestaurant.forEach((restaurantId, restItems) {
                final restaurantName = restaurantAddresses.firstWhere(
                  (r) => r['restaurant_id'] == restaurantId,
                  orElse: () => {'restaurant_name': 'Unknown Restaurant'},
                )['restaurant_name'] ?? 'Unknown Restaurant';

                restaurantWidgets.add(
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$restaurantName:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ...restItems.map((item) {
                          final dish = item['dishes'];
                          final dishName = dish != null ? dish['name'] : 'Unknown';
                          final price = dish != null ? dish['price'] : 0;
                          final quantity = item['quantity'] ?? 1;
                          final itemStatus = item['status'] ?? 'placed';

                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                            child: Text('$dishName × $quantity - \$${price * quantity} (Status: $itemStatus)'),
                          );
                        }).toList(),
                        // Pickup button for each restaurant when driver accepts order
                        if (isAssignedToCurrent) ...[
                          SizedBox(height: 4),
                          ElevatedButton(
                            onPressed: restItems.every((item) => item['status'] == 'ready_for_pickup')
                                ? () => pickupItems(orderId, restaurantId)
                                : null,
                            child: Text('Picked Up'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: restItems.every((item) => item['status'] == 'ready_for_pickup')
                                  ? AppColors.primary
                                  : Colors.grey,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              });
              return restaurantWidgets;
            })(),
            SizedBox(height: 8),

            // Status and action buttons
            () {
              if (status == 'delivered')
                return Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Delivered',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                );
              else if (status == 'waiting for confirmation')
                return Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.yellow),
                    SizedBox(width: 8),
                    Text('Waiting for Confirmation',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.yellow[700])),
                  ],
                );
              else
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $status',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    SizedBox(height: 8),

                    // Action buttons based on status
                    if (!isAssigned && (status == 'confirmed' || status == 'order called for delivery'))
                      ElevatedButton(
                        onPressed: () => acceptOrder(orderId),
                        child: Text('Accept Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      )
                    else if (isAssigned && status == 'order called for delivery')
                      () {
                        final restaurantIds = order['restaurant_ids'] as List<dynamic>?;
                        final isMulti = (restaurantIds?.length ?? 0) > 1;
                        if (isMulti)
                          // Multi-restaurant order: show acquire buttons for each restaurant
                          return Column(
                            children: [
                              Text('Acquire from each restaurant:', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              ...restaurantAddresses.map((restaurant) {
                                final restaurantId = restaurant['restaurant_id'] as String?;
                                if (restaurantId == null) return SizedBox.shrink();
                                final isAcquired = acquiredRestaurants[orderId]?.contains(restaurantId) ?? false;
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          restaurant['restaurant_name'] ?? 'Unknown Restaurant',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      if (isAcquired)
                                        Icon(Icons.check_circle, color: Colors.green, size: 20)
                                      else
                                        ElevatedButton(
                                          onPressed: () => acquireRestaurant(orderId, restaurantId),
                                          child: Text('Acquire'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          );
                        else
                          // Single restaurant: no button here, pickup per restaurant
                          return SizedBox.shrink();
                      }()
                    else if (status == 'waiting for delivery')
                      () {
                        // Check if all restaurants have been picked up
                        final restaurantStatuses = order['restaurant_statuses'] as List<dynamic>? ?? [];
                        final allPickedUp = restaurantStatuses.every((status) => status['picked_up'] == true);

                        return ElevatedButton(
                          onPressed: allPickedUp ? () => updateOrderStatus(orderId, 'waiting for confirmation') : null,
                          child: Text('Delivered to Customer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allPickedUp ? AppColors.primary : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        );
                      }(),
                  ],
                );
            }(),
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

