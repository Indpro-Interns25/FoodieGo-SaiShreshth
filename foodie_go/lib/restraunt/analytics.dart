import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';

class Analytics extends StatefulWidget {
  const Analytics({super.key});

  @override
  State<Analytics> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<Analytics> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  bool isLoading = true;

  // Order Analytics
  int totalOrders = 0;
  double totalRevenue = 0;
  double averageOrderValue = 0;
  Map<String, int> orderStatusDistribution = {};

  // Review Analytics
  double averageRating = 0.0;
  int totalReviews = 0;
  Map<int, int> ratingDistribution = {};

  // Customer Analytics
  int uniqueCustomers = 0;
  double repeatCustomerRate = 0.0;

  // Driver Analytics
  Map<String, int> driverPerformance = {};

  // Time-based Analytics
  Map<String, double> weeklyRevenue = {};
  Map<String, int> dailyOrders = {};

  Timer? _refreshTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchAnalyticsData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAutoRefresh();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isVisible = state == AppLifecycleState.resumed;
    if (_isVisible) {
      // Refresh data when app becomes visible
      fetchAnalyticsData();
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh(); // Ensure no duplicate timers
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (_isVisible && mounted) {
        print('Auto-refreshing analytics...');
        fetchAnalyticsData();
      }
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> fetchAnalyticsData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Test Supabase connection first
      try {
        await supabase.from('orders').select('id').limit(1);
      } catch (connectionError) {
        print('Supabase connection error: $connectionError');
        if (!mounted) return;
        setState(() {
          isLoading = false;
        });
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found for analytics');
        setState(() {
          isLoading = false;
        });
        return;
      }

      print('Fetching analytics data for restaurant: ${user.id}');

      // Fetch data sequentially to avoid overwhelming the database
      await fetchOrderAnalytics(user.id);
      await fetchReviewAnalytics(user.id);
      await fetchCustomerAnalytics(user.id);
      await fetchDriverAnalytics(user.id);
      await fetchTimeBasedAnalytics(user.id);

      print('Analytics data fetched successfully');
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Exception fetching analytics: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchOrderAnalytics(String restaurantId) async {
    try {
      // Fetch all orders for this restaurant
      final ordersData = await supabase
          .from('orders')
          .select('*, order_items(*)')
          .eq('user_id_res', restaurantId);

      if (ordersData.isNotEmpty) {
        int orderCount = ordersData.length;
        double revenue = 0;
        Map<String, int> statusDist = {'placed': 0, 'approved': 0, 'delivered': 0, 'cancelled': 0};

        for (var order in ordersData) {
          // Calculate revenue (90% of order total for restaurant)
          final items = order['order_items'] as List? ?? [];
          double orderTotal = 0;
          for (var item in items) {
            orderTotal += (item['price'] ?? 0) * (item['quantity'] ?? 1);
          }
          revenue += orderTotal * 0.9;

          // Count status
          String status = order['status'] ?? 'placed';
          statusDist[status] = (statusDist[status] ?? 0) + 1;
        }

        setState(() {
          totalOrders = orderCount;
          totalRevenue = revenue;
          averageOrderValue = orderCount > 0 ? revenue / orderCount : 0;
          orderStatusDistribution = statusDist;
        });
      }
    } catch (e) {
      print('Error fetching order analytics: $e');
      // Set default values when data fetch fails
      setState(() {
        totalOrders = 0;
        totalRevenue = 0;
        averageOrderValue = 0;
        orderStatusDistribution = {};
      });
    }
  }

  Future<void> fetchReviewAnalytics(String restaurantId) async {
    try {
      final reviewsData = await supabase
          .from('reviews')
          .select('*')
          .eq('restaurant_id', restaurantId);

      if (reviewsData.isNotEmpty) {
        double totalRating = 0;
        Map<int, int> ratingDist = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

        for (var review in reviewsData) {
          int rating = review['rating'] ?? 0;
          totalRating += rating;
          if (rating >= 1 && rating <= 5) {
            ratingDist[rating] = (ratingDist[rating] ?? 0) + 1;
          }
        }

        setState(() {
          totalReviews = reviewsData.length;
          averageRating = totalRating / reviewsData.length;
          ratingDistribution = ratingDist;
        });
      }
    } catch (e) {
      print('Error fetching review analytics: $e');
    }
  }

  Future<void> fetchCustomerAnalytics(String restaurantId) async {
    try {
      final ordersData = await supabase
          .from('orders')
          .select('user_id')
          .eq('user_id_res', restaurantId)
          .eq('status', 'delivered');

      if (ordersData.isNotEmpty) {
        Set<String> uniqueCustomersSet = {};
        Map<String, int> customerOrderCount = {};

        for (var order in ordersData) {
          String customerId = order['user_id'] ?? '';
          uniqueCustomersSet.add(customerId);
          customerOrderCount[customerId] = (customerOrderCount[customerId] ?? 0) + 1;
        }

        int repeatCustomers = customerOrderCount.values.where((count) => count > 1).length;
        double repeatRate = uniqueCustomersSet.length > 0
            ? (repeatCustomers / uniqueCustomersSet.length) * 100
            : 0;

        setState(() {
          uniqueCustomers = uniqueCustomersSet.length;
          repeatCustomerRate = repeatRate;
        });
      }
    } catch (e) {
      print('Error fetching customer analytics: $e');
    }
  }

  Future<void> fetchDriverAnalytics(String restaurantId) async {
    try {
      final ordersData = await supabase
          .from('orders')
          .select('user_id_dri, status')
          .eq('user_id_res', restaurantId)
          .not('user_id_dri', 'is', null);

      if (ordersData.isNotEmpty) {
        Map<String, int> driverStats = {};

        for (var order in ordersData) {
          String driverId = order['user_id_dri'] ?? '';
          String status = order['status'] ?? '';

          if (driverId.isNotEmpty) {
            if (!driverStats.containsKey(driverId)) {
              driverStats[driverId] = 0;
            }
            if (status == 'delivered') {
              driverStats[driverId] = (driverStats[driverId] ?? 0) + 1;
            }
          }
        }

        setState(() {
          driverPerformance = driverStats;
        });
      }
    } catch (e) {
      print('Error fetching driver analytics: $e');
    }
  }

  Future<void> fetchTimeBasedAnalytics(String restaurantId) async {
    try {
      final ordersData = await supabase
          .from('orders')
          .select('placed_at, order_items(*)')
          .eq('user_id_res', restaurantId)
          .eq('status', 'delivered')
          .order('placed_at', ascending: false)
          .limit(30); // Last 30 orders

      if (ordersData.isNotEmpty) {
        Map<String, double> weeklyRev = {};
        Map<String, int> dailyOrd = {};

        for (var order in ordersData) {
          String dateStr = order['placed_at'] ?? '';
          if (dateStr.isEmpty) continue;

          try {
            DateTime orderDate = DateTime.parse(dateStr);
            String weekKey = '${orderDate.year}-W${((orderDate.day - orderDate.weekday + 10) / 7).floor()}';
            String dayKey = DateFormat('yyyy-MM-dd').format(orderDate);

            // Calculate order value
            double orderValue = 0;
            final items = order['order_items'] as List? ?? [];
            for (var item in items) {
              orderValue += (item['price'] ?? 0) * (item['quantity'] ?? 1);
            }

            weeklyRev[weekKey] = (weeklyRev[weekKey] ?? 0) + (orderValue * 0.9);
            dailyOrd[dayKey] = (dailyOrd[dayKey] ?? 0) + 1;
          } catch (e) {
            print('Error parsing date: $e');
          }
        }

        setState(() {
          weeklyRevenue = weeklyRev;
          dailyOrders = dailyOrd;
        });
      }
    } catch (e) {
      print('Error fetching time-based analytics: $e');
    }
  }

  Widget buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
              ),
              SizedBox(height: 16),
              Text(
                'Loading analytics...',
                style: TextStyle(color: AppColors.primary),
              ),

            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: fetchAnalyticsData,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                color: AppColors.background,
                child: Row(
                  children: [
                    Text(
                      'Analytics Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.primary),
                      onPressed: fetchAnalyticsData,
                    ),
                  ],
                ),
              ),

              // Key Metrics
              buildSectionTitle('Key Performance Metrics'),
              Padding(
                padding: EdgeInsets.all(16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    buildMetricCard(
                      'Total Orders',
                      totalOrders.toString(),
                      Icons.receipt_long,
                      AppColors.primary,
                    ),
                    buildMetricCard(
                      'Total Revenue',
                      '₹${totalRevenue.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      Colors.green,
                    ),
                    buildMetricCard(
                      'Avg Order Value',
                      '₹${averageOrderValue.toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.blue,
                    ),
                    buildMetricCard(
                      'Total Reviews',
                      totalReviews.toString(),
                      Icons.star,
                      Colors.amber,
                    ),
                  ],
                ),
              ),

              // Order Status Distribution
              if (orderStatusDistribution.isNotEmpty) ...[
                buildSectionTitle('Order Status Distribution'),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: orderStatusDistribution.entries.map((entry) {
                      int count = entry.value;
                      double percentage = totalOrders > 0 ? (count / totalOrders) * 100 : 0;
                      return Card(
                        child: ListTile(
                          title: Text(entry.key.toUpperCase()),
                          subtitle: Text('$count orders (${percentage.toStringAsFixed(1)}%)'),
                          trailing: Text(count.toString()),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Review Analytics
              if (totalReviews > 0) ...[
                buildSectionTitle('Review Analytics'),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Average Rating',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  Text(
                                    averageRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Row(
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < averageRating.round() ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 20,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text('Rating Distribution:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          ...ratingDistribution.entries.map((entry) {
                            int count = entry.value;
                            double percentage = totalReviews > 0 ? (count / totalReviews) * 100 : 0;
                            return Row(
                              children: [
                                Text('${entry.key}★'),
                                SizedBox(width: 8),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('${percentage.toStringAsFixed(1)}%'),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Customer Analytics
              buildSectionTitle('Customer Analytics'),
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                uniqueCustomers.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text('Unique Customers'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                '${repeatCustomerRate.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text('Repeat Customer Rate'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Driver Performance
              if (driverPerformance.isNotEmpty) ...[
                buildSectionTitle('Driver Performance'),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: driverPerformance.entries.map((entry) {
                      return Card(
                        child: ListTile(
                          title: Text('Driver ${entry.key.substring(0, 8)}'),
                          subtitle: Text('Successful Deliveries'),
                          trailing: Text('${entry.value} orders'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],

              // Recent Activity
              buildSectionTitle('Recent Activity'),
              Padding(
                padding: EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last 7 Days Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Orders: ${dailyOrders.length}'),
                        Text('Revenue: ₹${weeklyRevenue.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)}'),
                        if (dailyOrders.isEmpty && weeklyRevenue.isEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            'No recent activity data available.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // No Data Message
              if (totalOrders == 0 && totalReviews == 0 && uniqueCustomers == 0) ...[
                SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No Analytics Data Available',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Analytics will appear here once you start receiving orders and reviews.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
