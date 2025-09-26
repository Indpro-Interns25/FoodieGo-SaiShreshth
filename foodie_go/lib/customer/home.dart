import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'cart_provider.dart';
import 'search_provider.dart';
import '../constants.dart';

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  final supabase = Supabase.instance.client;
  List<dynamic> allRestaurants = [];
  List<dynamic> displayedRestaurants = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool isLoading = false;

  // Map user_id_res -> restaurant name for quick lookup
  final Map<String, String> _restaurantNameByUserId = {};

  // Popular dishes state
  List<dynamic> popularDishes = [];
  bool isLoadingPopularDishes = false;

  final Map<String, int> _dishQuantities = {}; // transient qty per dish card
  bool _showSearchResults = false;

  // Ratings state
  final Map<String, Map<String, dynamic>> _dishRatings = {}; // dish_id -> {average_rating, review_count}
  final Map<String, Map<String, dynamic>> _restaurantRatings = {}; // restaurant_id -> {average_rating, review_count}

  // Search results state
  List<dynamic> searchResults = [];
  List<dynamic> searchDishes = [];
  List<dynamic> allDishes = []; // Fallback for when popular dishes are not available
  bool isLoadingAllDishes = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _refreshAll();
    _fetchPopularDishes();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void resetSearch() {
    _searchController.clear();
    _searchFocus.unfocus();
    setState(() {
      displayedRestaurants = allRestaurants;
      _showSearchResults = false;
    });
  }

  void _incrementDishQty(String dishId) {
    setState(() {
      _dishQuantities[dishId] = (_dishQuantities[dishId] ?? 1) + 1;
    });
  }

  void _decrementDishQty(String dishId) {
    setState(() {
      final current = _dishQuantities[dishId] ?? 1;
      _dishQuantities[dishId] = current > 1 ? current - 1 : 1;
    });
  }

  Future<void> _refreshAll() async {
    await _fetchRestaurants();
    await _fetchPopularDishes();
    await _fetchAllDishes(); // Fetch all dishes as fallback
  }

  Future<void> _fetchRestaurants() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await supabase.from('restaurant_profiles').select();
      debugPrint('restaurant_profiles fetched: ${response.runtimeType}');
      final list = response as List<dynamic>;
      if (list.isNotEmpty) {
        debugPrint('Count: ${list.length}');
        debugPrint('First row: ${list.first}');
      } else {
        debugPrint('No restaurants returned from Supabase');
      }
      if (!mounted) return;

      // Build name lookup and user id list
      final List<String> userIds = [];
      _restaurantNameByUserId.clear();
      for (final r in list) {
        final String? userId =
            (r['user_id'] ?? r['id'] ?? '') as String?; // prefer user_id
        final String name = (r['restaurant_name'] ?? 'Restaurant') as String;
        if (userId != null && userId.isNotEmpty) {
          userIds.add(userId);
          _restaurantNameByUserId[userId] = name;
        }
      }

      setState(() {
        allRestaurants = list;
        displayedRestaurants = allRestaurants;
        isLoading = false;
      });

      // Fetch ratings for restaurants
      await _fetchRestaurantRatings(userIds);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching restaurants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load restaurants'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  Future<void> _fetchPopularDishes() async {
    setState(() {
      isLoadingPopularDishes = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() {
          isLoadingPopularDishes = false;
        });
        return;
      }

      // Use the new optimized endpoint that includes ratings
      final response = await http.get(
        Uri.parse('$flaskApiUrl/get_top_dishes_with_ratings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dishes = data['dishes'] as List<dynamic>? ?? [];

        if (!mounted) return;
        setState(() {
          popularDishes = dishes;
          isLoadingPopularDishes = false;
        });

        // Initialize quantities for popular dishes
        for (final d in popularDishes) {
          final id = (d['id'] ?? '').toString();
          if (id.isNotEmpty && !_dishQuantities.containsKey(id)) {
            _dishQuantities[id] = 1;
          }
        }

        // Store ratings directly from the response (no need for separate API calls)
        for (final dish in dishes) {
          final dishId = dish['id'].toString();
          if (dishId.isNotEmpty) {
            setState(() {
              _dishRatings[dishId] = {
                'average_rating': dish['average_rating'] ?? 0.0,
                'review_count': dish['review_count'] ?? 0,
              };
            });
          }
        }
      } else {
        if (!mounted) return;
        setState(() {
          isLoadingPopularDishes = false;
        });
        debugPrint('Error fetching popular dishes: ${response.body}');
        // Fallback to fetch all dishes when popular dishes endpoint fails
        await _fetchAllDishes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingPopularDishes = false;
      });
      debugPrint('Error fetching popular dishes: $e');
      // Fallback to fetch all dishes when popular dishes endpoint fails
      await _fetchAllDishes();
    }
  }

  Future<void> _fetchAllDishes() async {
    setState(() {
      isLoadingAllDishes = true;
    });
    try {
      final session = supabase.auth.currentSession;
      if (session == null) {
        setState(() {
          isLoadingAllDishes = false;
        });
        return;
      }

      // Fetch all dishes from Supabase directly
      final response = await supabase
          .from('dishes')
          .select('*, restaurant_profiles(restaurant_name)')
          .limit(50); // Limit to prevent too many results

      if (!mounted) return;

      final dishes = response as List<dynamic>? ?? [];

      // Add restaurant names to dishes
      for (final dish in dishes) {
        final restaurantId = dish['user_id_res'];
        if (restaurantId != null) {
          try {
            final restaurantResponse = await supabase
                .from('restaurant_profiles')
                .select('restaurant_name')
                .eq('user_id', restaurantId)
                .single();

            dish['restaurantName'] = restaurantResponse['restaurant_name'] ?? 'Unknown Restaurant';
          } catch (e) {
            dish['restaurantName'] = 'Unknown Restaurant';
          }
        } else {
          dish['restaurantName'] = 'Unknown Restaurant';
        }
      }

      setState(() {
        allDishes = dishes;
        isLoadingAllDishes = false;
      });

      // Initialize quantities for all dishes
      for (final d in allDishes) {
        final id = (d['id'] ?? '').toString();
        if (id.isNotEmpty && !_dishQuantities.containsKey(id)) {
          _dishQuantities[id] = 1;
        }
      }

      // Fetch ratings for all dishes
      await _fetchDishRatings(dishes.map((d) => d['id'].toString()).where((id) => id.isNotEmpty).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingAllDishes = false;
      });
      debugPrint('Error fetching all dishes: $e');
    }
  }

  Future<void> _fetchDishRatings(List<String> dishIds) async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      for (final dishId in dishIds) {
        if (_dishRatings.containsKey(dishId)) continue; // Skip if already fetched

        try {
          final response = await http.get(
            Uri.parse('$flaskApiUrl/get_dish_rating?dish_id=$dishId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            setState(() {
              _dishRatings[dishId] = {
                'average_rating': data['average_rating'] ?? 0.0,
                'review_count': data['review_count'] ?? 0,
              };
            });
          }
        } catch (e) {
          debugPrint('Error fetching rating for dish $dishId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchDishRatings: $e');
    }
  }

  Future<void> _fetchRestaurantRatings(List<String> restaurantIds) async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return;

      for (final restaurantId in restaurantIds) {
        if (_restaurantRatings.containsKey(restaurantId)) continue; // Skip if already fetched

        try {
          final response = await http.get(
            Uri.parse('$flaskApiUrl/get_restaurant_rating?restaurant_id=$restaurantId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            setState(() {
              _restaurantRatings[restaurantId] = {
                'average_rating': data['average_rating'] ?? 0.0,
                'review_count': data['review_count'] ?? 0,
              };
            });
          }
        } catch (e) {
          debugPrint('Error fetching rating for restaurant $restaurantId: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchRestaurantRatings: $e');
    }
  }

  Future<void> _searchAll(String query) async {
    final lower = query.toLowerCase();

    if (query.trim().isEmpty) {
      setState(() {
        displayedRestaurants = allRestaurants;
        searchResults = [];
        searchDishes = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _showSearchResults = true;
    });

    // Filter restaurants
    final filteredRestaurants = allRestaurants.where((r) {
      final name = (r['restaurant_name'] ?? '') as String;
      final desc = (r['description'] ?? '') as String;
      return name.toLowerCase().contains(lower) ||
          desc.toLowerCase().contains(lower);
    }).toList();

    // Filter dishes from popular dishes first
    List<dynamic> filteredDishes = popularDishes.where((d) {
      final name = (d['name'] ?? '') as String;
      final restaurantName = (d['restaurantName'] ?? '') as String;
      return name.toLowerCase().contains(lower) ||
          restaurantName.toLowerCase().contains(lower);
    }).toList();

    // If no dishes found in popular dishes and we have all dishes loaded, search there too
    if (filteredDishes.isEmpty && allDishes.isNotEmpty) {
      final allDishesFiltered = allDishes.where((d) {
        final name = (d['name'] ?? '') as String;
        final restaurantName = (d['restaurantName'] ?? '') as String;
        return name.toLowerCase().contains(lower) ||
            restaurantName.toLowerCase().contains(lower);
      }).toList();

      // Combine popular dishes results with all dishes results (avoid duplicates)
      final popularDishIds = popularDishes.map((d) => d['id']).toSet();
      final uniqueAllDishes = allDishesFiltered.where((d) => !popularDishIds.contains(d['id'])).toList();

      filteredDishes = [...filteredDishes, ...uniqueAllDishes];
    }

    setState(() {
      displayedRestaurants = filteredRestaurants;
      searchResults = filteredRestaurants;
      searchDishes = filteredDishes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    if (searchProvider.searchQuery.isNotEmpty &&
        _searchController.text != searchProvider.searchQuery) {
      _searchController.text = searchProvider.searchQuery;
      _searchAll(searchProvider.searchQuery);
    }

    final bool isSearching =
        _searchFocus.hasFocus || _searchController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // App Bar Section
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to FoodieGo!',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 25,
                            ),
                          ),
                          Text(
                            'What would you like to eat?',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        child: Icon(Icons.person, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                // Search Bar + Conditional Refresh
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: _searchAll,
                          decoration: InputDecoration(
                            hintText: 'Search restaurants and dishes',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      if (isSearching) ...[
                        SizedBox(width: 10),
                        SizedBox(
                          height: 48,
                          width: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              backgroundColor: AppColors.surface,
                              side: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: isLoading ? null : _refreshAll,
                            child: Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Most Popular Dishes Section FIRST (only show when not searching)
                if (!_showSearchResults)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.green,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Top Ordered',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Based on orders',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        if (isLoadingPopularDishes || isLoadingAllDishes)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (popularDishes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No orders yet',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: popularDishes.length > 3 ? 3 : popularDishes.length,
                            itemBuilder: (context, index) {
                              final d = popularDishes[index] as Map<String, dynamic>;
                              final dishId = (d['id'] ?? '').toString();
                              final dishName = (d['name'] ?? 'Dish') as String;
                              final price = d['price'];
                              final image = d['image'] as String?;
                              final ownerId = (d['user_id_res'] ?? '') as String;
                              final restName = (d['restaurantName'] ?? 'Restaurant') as String;
                              final qty = _dishQuantities[dishId] ?? 1;
                              return _buildTopOrderedDishCard(
                                dishId: dishId,
                                dishName: dishName,
                                restaurantName: restName,
                                price: price,
                                imageUrl: image,
                                quantity: qty,
                                ownerId: ownerId,
                                orderCount: d['order_count'] ?? 0,
                              );
                            },
                          ),
                      ],
                    ),
                  ),



                // Search Results or Popular Restaurants Section
                if (_showSearchResults)
                  // Show search results
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search Results',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        // Show dishes first if any found
                        if (searchDishes.isNotEmpty) ...[
                          Text(
                            'Dishes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: searchDishes.length,
                            itemBuilder: (context, index) {
                              final d = searchDishes[index] as Map<String, dynamic>;
                              final dishId = (d['id'] ?? '').toString();
                              final dishName = (d['name'] ?? 'Dish') as String;
                              final price = d['price'];
                              final image = d['image'] as String?;
                              final ownerId = (d['user_id_res'] ?? '') as String;
                              final restName = (d['restaurantName'] ?? 'Restaurant') as String;
                              final qty = _dishQuantities[dishId] ?? 1;
                              return _buildTopOrderedDishCard(
                                dishId: dishId,
                                dishName: dishName,
                                restaurantName: restName,
                                price: price,
                                imageUrl: image,
                                quantity: qty,
                                ownerId: ownerId,
                                orderCount: d['order_count'] ?? 0,
                              );
                            },
                          ),
                          SizedBox(height: 16),
                        ],
                        // Show restaurants if any found
                        if (searchResults.isNotEmpty) ...[
                          Text(
                            'Restaurants',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final r = searchResults[index] as Map<String, dynamic>;
                              return _buildRestaurantCard(r);
                            },
                          ),
                        ],
                        // Show no results message if both are empty
                        if (searchResults.isEmpty && searchDishes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No results found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  // Show popular restaurants when not searching
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Popular Restaurants',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        if (isLoading)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (displayedRestaurants.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No restaurants found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: displayedRestaurants.length,
                            itemBuilder: (context, index) {
                              final r = displayedRestaurants[index] as Map<String, dynamic>;
                              return _buildRestaurantCard(r);
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(dynamic r) {
    final name = (r['restaurant_name'] ?? 'Restaurant') as String;
    final subtitle = (r['description'] ?? 'Delicious food awaits!') as String;
    final imageUrl = r['image_url'] as String?;
    final restaurantId = (r['user_id'] ?? '').toString();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          _searchController.text = name;
          _searchAll(name);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imageFallback(),
                            )
                          : _imageFallback(),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        // Restaurant rating display
                        if (_restaurantRatings.containsKey(restaurantId)) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                '${(_restaurantRatings[restaurantId]!['average_rating'] as double).toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber[700],
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                '(${_restaurantRatings[restaurantId]!['review_count']} reviews)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopOrderedDishCard({
    required String dishId,
    required String dishName,
    required String restaurantName,
    required dynamic price,
    required String? imageUrl,
    required int quantity,
    required String ownerId,
    required int orderCount,
  }) {
    final cartProvider = context.watch<CartProvider>();
    final bool inCart = cartProvider.cartItems.containsKey(dishId);
    final int inCartQty = inCart
        ? ((cartProvider.cartItems[dishId] as Map<String, dynamic>)['quantity'] as int? ??
              0)
        : 0;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dishName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        restaurantName,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '₹ ${price?.toString() ?? '-'}',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      // Rating display
                      if (_dishRatings.containsKey(dishId)) ...[
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${(_dishRatings[dishId]!['average_rating'] as double).toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber[700],
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '(${_dishRatings[dishId]!['review_count']} reviews)',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                      ],
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: orderCount > 0 ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: orderCount > 0 ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
                        ),
                        child: Text(
                          orderCount > 0 ? 'Ordered ${orderCount} times' : 'Featured Dish',
                          style: TextStyle(
                            fontSize: 10,
                            color: orderCount > 0 ? Colors.green : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Quantity selector (not in cart) OR compact Added tag (in cart)
                inCart
                    ? Chip(
                        label: Text(
                          inCartQty > 0 ? 'Added • $inCartQty' : 'Added',
                          style: const TextStyle(fontSize: 12),
                        ),
                        avatar: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        backgroundColor: AppColors.surface,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    : Row(
                        children: [
                          IconButton(
                            onPressed: () => _decrementDishQty(dishId),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          Text('${_dishQuantities[dishId] ?? quantity}'),
                          IconButton(
                            onPressed: () => _incrementDishQty(dishId),
                            icon: Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                // Add/Added + Remove controls
                inCart
                    ? Row(
                        children: [
                          // Right side shows only Remove when already in cart
                          TextButton.icon(
                            onPressed: () => cartProvider.removeFromCart(dishId),
                            icon: const Icon(Icons.remove_shopping_cart),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final dish = {
                            'id': dishId,
                            'name': dishName,
                            'price': price,
                            'image': imageUrl,
                            'user_id_res': ownerId,
                            'restaurantName': restaurantName,
                          };
                          cartProvider.addToCart(dish, _dishQuantities[dishId] ?? 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added to cart')),
                          );
                        },
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Add to cart'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishCard({
    required String dishId,
    required String dishName,
    required String restaurantName,
    required dynamic price,
    required String? imageUrl,
    required int quantity,
    required String ownerId,
  }) {
    final cartProvider = context.watch<CartProvider>();
    final bool inCart = cartProvider.cartItems.containsKey(dishId);
    final int inCartQty = inCart
        ? ((cartProvider.cartItems[dishId] as Map<String, dynamic>)['quantity'] as int? ??
              0)
        : 0;
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(),
                          )
                        : _imageFallback(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dishName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        restaurantName,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '₹ ${price?.toString() ?? '-'}',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 4),
                      // Rating display
                      if (_dishRatings.containsKey(dishId)) ...[
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${(_dishRatings[dishId]!['average_rating'] as double).toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber[700],
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(
                              '(${_dishRatings[dishId]!['review_count']} reviews)',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Quantity selector (not in cart) OR compact Added tag (in cart)
                inCart
                    ? Chip(
                        label: Text(
                          inCartQty > 0 ? 'Added • $inCartQty' : 'Added',
                          style: const TextStyle(fontSize: 12),
                        ),
                        avatar: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        backgroundColor: AppColors.surface,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: AppColors.primary,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    : Row(
                        children: [
                          IconButton(
                            onPressed: () => _decrementDishQty(dishId),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          Text('${_dishQuantities[dishId] ?? quantity}'),
                          IconButton(
                            onPressed: () => _incrementDishQty(dishId),
                            icon: Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                // Add/Added + Remove controls
                inCart
                    ? Row(
                        children: [
                          // Right side shows only Remove when already in cart
                          TextButton.icon(
                            onPressed: () => cartProvider.removeFromCart(dishId),
                            icon: const Icon(Icons.remove_shopping_cart),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final dish = {
                            'id': dishId,
                            'name': dishName,
                            'price': price,
                            'image': imageUrl,
                            'user_id_res': ownerId,
                            'restaurantName': restaurantName,
                          };
                          cartProvider.addToCart(dish, _dishQuantities[dishId] ?? 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Added to cart')),
                          );
                        },
                        icon: Icon(Icons.add_shopping_cart),
                        label: Text('Add to cart'),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.surface,
      child: Icon(Icons.storefront, color: AppColors.textSecondary),
    );
  }
}
