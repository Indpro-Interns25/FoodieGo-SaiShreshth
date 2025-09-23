import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../customer/order_details.dart';

class Payments extends StatefulWidget {
  const Payments({super.key});
  @override
  State<Payments> createState() => _PaymentsState();
}

class _PaymentsState extends State<Payments> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> payments = [];
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

      // Fetch delivered orders for current restaurant user
      final orders = await supabase
          .from('orders')
          .select('id, placed_at, status, order_items(price, quantity)')
          .eq('user_id_res', user.id)
          .eq('status', 'delivered')
          .order('placed_at', ascending: false);

      if (!mounted) return;

      // Calculate payments: 90% of order total for restaurant
      List<Map<String, dynamic>> paymentList = [];
      for (final order in (orders as List)) {
        final orderItems = order['order_items'] as List? ?? [];
        num total = 0;
        for (final item in orderItems) {
          final price = item['price'] as num? ?? 0;
          final qty = item['quantity'] as int? ?? 0;
          total += price * qty;
        }
        final restaurantShare = total * 0.90;
        paymentList.add({
          'order_id': order['id'],
          'amount': restaurantShare,
          'placed_at': order['placed_at'],
        });
      }

      setState(() {
        payments = paymentList;
        totalEarnings = paymentList.fold(0.0, (sum, p) => sum + (p['amount'] as num));
      });
    } catch (e) {
      print('Exception fetching restaurant payments: $e');
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
                        style: TextStyle(fontSize: 18, color: Colors.black54),
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
        color: Colors.orange,
        child: Text(
          'Total Earnings: ₹${totalEarnings.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
