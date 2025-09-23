import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../constants.dart';

class Reviews extends StatefulWidget {
  const Reviews({super.key});

  @override
  State<Reviews> createState() => _ReviewsState();
}

class _ReviewsState extends State<Reviews> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> reviews = [];
  bool isLoading = true;
  double averageRating = 0.0;
  Map<int, int> ratingDistribution = {};

  Timer? _refreshTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchReviews();
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
      fetchReviews();
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _stopAutoRefresh(); // Ensure no duplicate timers
    _refreshTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      if (_isVisible && mounted) {
        print('Auto-refreshing reviews...');
        fetchReviews();
      }
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> fetchReviews() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Test Supabase connection first
      try {
        await supabase.from('reviews').select('id').limit(1);
      } catch (connectionError) {
        print('Supabase connection error: $connectionError');
        if (!mounted) return;
        setState(() {
          reviews = [];
          isLoading = false;
        });
        return;
      }

      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found');
        setState(() {
          reviews = [];
          isLoading = false;
        });
        return;
      }

      print('Fetching reviews for restaurant: ${user.id}');

      // Try to fetch reviews with timeout
      try {
        final reviewsData = await supabase
            .from('reviews')
            .select('*')
            .eq('restaurant_id', user.id)
            .order('created_at', ascending: false);

        print('Reviews data fetched: ${reviewsData.length} reviews');

        if (!mounted) return;

        // Calculate statistics
        if (reviewsData.isNotEmpty) {
          double totalRating = 0;
          Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

          for (var review in reviewsData) {
            int rating = review['rating'] ?? 0;
            totalRating += rating;
            if (rating >= 1 && rating <= 5) {
              distribution[rating] = (distribution[rating] ?? 0) + 1;
            }
          }

          setState(() {
            averageRating = totalRating / reviewsData.length;
            ratingDistribution = distribution;
          });
        }

        setState(() {
          reviews = List<Map<String, dynamic>>.from(reviewsData);
          isLoading = false;
        });
      } catch (dbError) {
        print('Database error fetching reviews: $dbError');
        // If reviews table doesn't exist or other database issues, show empty state
        setState(() {
          reviews = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Exception fetching reviews: $e');
      setState(() {
        reviews = [];
        isLoading = false;
      });
    }
  }

  Widget buildReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? 'No comment provided';
    final createdAt = review['created_at'] ?? '';
    final customerName = 'Anonymous Customer'; // No longer joining with customer_profiles
    final deliveryAddress = ''; // No longer joining with orders

    String formattedDate = createdAt;
    try {
      final dateTime = DateTime.parse(createdAt);
      formattedDate = DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (_) {}

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      child: InkWell(
        onTap: () {
          _showReviewDetails(review);
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating and customer info row
              Row(
                children: [
                  // Star rating
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  SizedBox(width: 8),
                  Text(
                    rating.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  Spacer(),
                  Text(
                    customerName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Comment preview (truncated)
              Text(
                comment.length > 100 ? '${comment.substring(0, 100)}...' : comment,
                style: TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),

              // Date and delivery address
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (deliveryAddress.isNotEmpty) ...[
                    SizedBox(width: 16),
                    Icon(Icons.location_on, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deliveryAddress,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReviewDetails(Map<String, dynamic> review) {
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? 'No comment provided';
    final createdAt = review['created_at'] ?? '';
    final customerName = 'Anonymous Customer'; // No longer joining with customer_profiles
    final deliveryAddress = ''; // No longer joining with orders

    String formattedDate = createdAt;
    try {
      final dateTime = DateTime.parse(createdAt);
      formattedDate = DateFormat('MMMM dd, yyyy \'at\' hh:mm a').format(dateTime);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 24,
                  );
                }),
              ),
              SizedBox(width: 8),
              Text(
                '$rating.0',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: $customerName',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Date: $formattedDate',
                  style: TextStyle(color: Colors.grey),
                ),
                if (deliveryAddress.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    'Delivery Address: $deliveryAddress',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
                SizedBox(height: 16),
                Text(
                  'Review:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  comment,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: fetchReviews,
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading reviews...',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              )
            : reviews.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.8,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.reviews_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No reviews yet.',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              Text(
                                'Reviews will appear here once customers rate their orders.',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Statistics Header
                      Container(
                        padding: EdgeInsets.all(16),
                        color: AppColors.background,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    averageRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (index) {
                                      return Icon(
                                        index < averageRating.round() ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 20,
                                      );
                                    }),
                                  ),
                                  Text(
                                    'Average Rating',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 50,
                              color: Colors.grey,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    reviews.length.toString(),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Total Reviews',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Reviews List
                      Expanded(
                        child: ListView.builder(
                          itemCount: reviews.length,
                          itemBuilder: (context, index) {
                            return buildReviewCard(reviews[index]);
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
