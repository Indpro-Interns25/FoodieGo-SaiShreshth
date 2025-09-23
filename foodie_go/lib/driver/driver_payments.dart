import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../customer/order_details.dart';

class DriverPayments extends StatefulWidget {
  const DriverPayments({super.key});

  @override
  State<DriverPayments> createState() => _DriverPaymentsState();
}

class _DriverPaymentsState extends State<DriverPayments> {
  final supabase = Supabase.instance.client;
  List<dynamic> payments = [];
  num totalEarnings = 0;

  @override
  void initState() {
    super.initState();
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          payments = [];
        });
        return;
      }

      // Fetch delivered orders for current driver
      final orders = await supabase
          .from('orders')
          .select('id, placed_at, status, order_items(price, quantity), user_id_res')
          .eq('user_id_dri', user.id)
          .eq('status', 'delivered')
          .order('placed_at', ascending: false);



      if (!mounted) return;

      // Calculate payments: 10% of order total for driver
      List<Map<String, dynamic>> paymentList = [];
      for (final order in (orders as List)) {
        final orderItems = order['order_items'] as List? ?? [];
        num total = 0;
        for (final item in orderItems) {
          final price = item['price'] as num? ?? 0;
          final qty = item['quantity'] as int? ?? 0;
          total += price * qty;
        }
        final driverShare = total * 0.10;
        final restaurantShare = total * 0.90;
        paymentList.add({
          'order_id': order['id'],
          'amount': driverShare,
          'restaurant_amount': restaurantShare,
          'placed_at': order['placed_at'],
          'restaurant_id': order['user_id_res'],
        });
      }

      setState(() {
        payments = paymentList;
        totalEarnings = paymentList.fold(0.0, (sum, p) => sum + (p['amount'] as num));
      });
    } catch (e) {
      print('Exception fetching payments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: fetchPayments,
        child: payments.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Center(
                      child: Text(
                        'No payments found.',
                        style: TextStyle(fontSize: 18, color: AppColors.primary),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: payments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  final orderId = payment['order_id'] as String? ?? '';
                  final amount = payment['amount'] as num? ?? 0;
                  final dateStr = payment['placed_at'] as String? ?? '';
                  String formattedDate = dateStr;
                  try {
                    final dateTime = DateTime.parse(dateStr);
                    formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
                  } catch (_) {}
                  return Card(
                    child: ListTile(
                      title: Text('Order #${orderId.substring(0, 8)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Payment: ₹${amount.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Text('Date: $formattedDate'),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsPage(orderId: orderId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.primary,
        child: Text(
          'Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
