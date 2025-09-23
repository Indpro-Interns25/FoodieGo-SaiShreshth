import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'review_page.dart';
import '../constants.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;
  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _loading = true;
  bool _confirming = false;
  bool _shownPopup = false;
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  Map<String, String> _dishNames = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final order = await supabase
          .from('orders')
          .select()
          .eq('id', widget.orderId)
          .single();
      final items = await supabase
          .from('order_items')
          .select()
          .eq('order_id', widget.orderId);
      final itemList = (items as List).cast<Map<String, dynamic>>();
      final dishIds = itemList.map((it) => it['dish_id']).whereType<String>().toSet().toList();
      Map<String, String> dishNames = {};
      if (dishIds.isNotEmpty) {
        final dishes = await supabase
            .from('dishes')
            .select('id, name')
            .filter('id', 'in', dishIds);
        dishNames = {for (var d in dishes) (d['id'].toString()): (d['name'] as String)};
      }
      if (mounted) {
        setState(() {
          _order = (order as Map<String, dynamic>);
          _items = itemList;
          _dishNames = dishNames;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch order details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load order details')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  num get _total {
    num t = 0;
    for (final v in _items) {
      final q = v['quantity'] as int? ?? 0;
      final p = v['price'];
      if (p is num) t += p * q;
    }
    return t;
  }

  Future<void> _confirmDelivery() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;

      final response = await http.post(
        Uri.parse('https://foodie-go-flask.vercel.app/confirm_delivery'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: jsonEncode({
          'order_id': widget.orderId,
        }),
      );

      if (response.statusCode == 200) {
        _fetch(); // Refresh the order details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery confirmed!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to confirm delivery')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error confirming delivery')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        centerTitle: true,
      ),
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
          ? const Center(child: Text('Order not found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text('Order #${widget.orderId.substring(0, 8)}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${_order!['status'] ?? '-'}'),
                        if (_order!['placed_at'] != null)
                          Builder(
                            builder: (context) {
                              final placedAt = _order!['placed_at'] as String?;
                              String formattedDate = '';
                              if (placedAt != null) {
                                try {
                                  DateTime dateTime = DateTime.parse(placedAt);
                                  formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
                                } catch (e) {
                                  formattedDate = placedAt;
                                }
                              }
                              return Text('Placed: $formattedDate');
                            },
                          ),
                        Text('Address: ${_order!['delivery_address'] ?? '-'}'),
                      ],
                    ),
                  ),
                ),
                if (_order!['status'] == 'waiting for confirmation')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirm Delivery'),
                              content: const Text('Are you sure you want to confirm that the delivery has been received?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _confirmDelivery();
                                  },
                                  child: Text(
                                    'Confirm',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Text(
                        'Confirm Delivery',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
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
                          'Items',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._items.map((it) {
                          final dishId = it['dish_id']?.toString() ?? '';
                          final name = _dishNames[dishId] ?? dishId;
                          final qty = (it['quantity'] ?? 1) as int;
                          final price = it['price'];
                          final line = (price is num ? price : 0) * qty;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('$name × $qty')),
                                    Text('₹ $line'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ReviewPage(orderId: widget.orderId, dishId: dishId),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.star_outline,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Review',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹ ${_total.toStringAsFixed(2)}',
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
    );
  }
}
