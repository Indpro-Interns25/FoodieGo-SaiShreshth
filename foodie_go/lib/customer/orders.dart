import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'order_details.dart';
import 'review_page.dart';
import '../constants.dart';

class OrdersPage extends StatefulWidget {
  final VoidCallback? onPageInit;
  final bool showAppBar;

  const OrdersPage({super.key, this.onPageInit, this.showAppBar = true});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
    _startRefreshTimer();

    // Reset navigation to home tab when OrdersPage is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPageInit?.call();
    });
  }

  @override
  void dispose() {
    try {
      _tabController.dispose();
    } catch (e) {
      // Ignore dispose errors
    }
    super.dispose();
    // setState(() {
    //   _selectedIndex = 0;
    // });
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final res = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id', user.id)
          .order('placed_at', ascending: false);
      final list = (res as List).cast<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _orders = list;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch orders: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load orders')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchOrders();
      }
    });
  }

  List<Map<String, dynamic>> get _ongoing => _orders.where((o) {
    final status = (o['status'] ?? '').toString().toLowerCase();
    return status != 'delivered' && status.isNotEmpty;
  }).toList();

  List<Map<String, dynamic>> get _delivered => _orders.where((o) {
    final status = (o['status'] ?? '').toString().toLowerCase();
    return status == 'delivered';
  }).toList();

  num get totalSpent {
    num total = 0;
    for (final order in _orders) {
      final orderItems = order['order_items'] as List? ?? [];
      for (final item in orderItems) {
        final price = item['price'] as num? ?? 0;
        final qty = item['quantity'] as int? ?? 0;
        total += price * qty;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: Text(
          'My Orders',
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
      ) : null,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Always show TabBar, either as part of AppBar or as separate widget
          if (!widget.showAppBar) Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Ongoing'),
                Tab(text: 'Delivered'),
              ],
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorWeight: 3,
              labelStyle: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _OrdersList(orders: _ongoing, onRefresh: _fetchOrders),
                      _OrdersList(orders: _delivered, onRefresh: _fetchOrders),
                    ],
                  ),
          ),
        ],
      ),

    );
  }
}

class _OrdersList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Future<void> Function() onRefresh;

  const _OrdersList({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('No orders to show')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final o = orders[index];
          final id = o['id'] as String? ?? '';
          final status = (o['status'] ?? '').toString();
          final placedAt = o['placed_at'] as String?;
          final addr = (o['delivery_address'] ?? '-') as String;
          final orderItems = o['order_items'] as List? ?? [];
          num total = 0;
          for (final item in orderItems) {
            final price = item['price'] as num? ?? 0;
            final qty = item['quantity'] as int? ?? 0;
            total += price * qty;
          }
          String formattedDate = '';
          if (placedAt != null) {
            try {
              DateTime dateTime = DateTime.parse(placedAt);
              formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
            } catch (e) {
              formattedDate = placedAt;
            }
          }
          Color? statusColor;
          final statusLower = status.toLowerCase();
          if (statusLower == 'waiting for confirmation') {
            statusColor = AppColors.warning;
          } else if (statusLower == 'confirmed') {
            statusColor = AppColors.info;
          } else if (statusLower == 'preparing') {
            statusColor = AppColors.primaryLight;
          } else if (statusLower == 'out for delivery') {
            statusColor = AppColors.secondary;
          } else if (statusLower == 'delivered') {
            statusColor = AppColors.success;
          } else if (statusLower == 'cancelled') {
            statusColor = AppColors.error;
          }
          return Card(
            child: ListTile(
              title: Text('Order #${id.substring(0, 8)}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor ?? Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Status: $status',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Text('Total: ₹${total.toStringAsFixed(2)}'),
                  if (formattedDate.isNotEmpty) Text('Placed: $formattedDate'),
                  Text('Address: $addr'),
                ],
              ),
              trailing: statusLower == 'delivered'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                    builder: (_) => ReviewPage(orderId: id),
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
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsPage(orderId: id),
                  ),
                );
              },
            ),
          );
        },
    ),
    );
  }
}
