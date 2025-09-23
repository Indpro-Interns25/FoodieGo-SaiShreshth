import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // dishes state
  List<dynamic> allDishes = [];
  List<dynamic> displayedDishes = [];
  bool isLoadingDishes = false;
  // Map user_id_res -> restaurant name for quick lookup
  final Map<String, String> _restaurantNameByUserId = {};

  final Map<String, int> _dishQuantities = {}; // transient qty per dish card

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _refreshAll();
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
      displayedDishes = allDishes;
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
    // _fetchRestaurants triggers dishes fetch after restaurants are loaded
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

      if (userIds.isNotEmpty) {
        await _fetchDishesForUserIds(userIds);
      } else {
        setState(() {
          allDishes = [];
          displayedDishes = [];
        });
      }
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

  Future<void> _fetchDishesForUserIds(List<String> userIds) async {
    setState(() {
      isLoadingDishes = true;
    });
    try {
      final response = await supabase
          .from('dishes')
          .select()
          .inFilter('user_id_res', userIds)
          .eq('availability', true);
      if (!mounted) return;
      setState(() {
        allDishes = response as List<dynamic>;
        displayedDishes = allDishes;
        isLoadingDishes = false;
      });
      // Initialize default quantities for new dishes
      for (final d in allDishes) {
        final id = (d['id'] ?? '').toString();
        if (id.isNotEmpty && !_dishQuantities.containsKey(id)) {
          _dishQuantities[id] = 1;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingDishes = false;
      });
      debugPrint('Error fetching dishes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load dishes'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterAll(String query) {
    final lower = query.toLowerCase();

    // Filter restaurants
    final filteredRestaurants = allRestaurants.where((r) {
      final name = (r['restaurant_name'] ?? '') as String;
      final desc = (r['description'] ?? '') as String;
      return name.toLowerCase().contains(lower) ||
          desc.toLowerCase().contains(lower);
    }).toList();

    // Filter dishes (by dish name and restaurant name)
    final filteredDishes = allDishes.where((d) {
      final dishName = (d['name'] ?? '') as String;
      final ownerId = (d['user_id_res'] ?? '') as String;
      final restName = _restaurantNameByUserId[ownerId] ?? '';
      return dishName.toLowerCase().contains(lower) ||
          restName.toLowerCase().contains(lower);
    }).toList();

    // Also include restaurants that offer the filtered dishes
    final Set<String> ownerIds = filteredDishes
        .map((d) => (d['user_id_res'] ?? '') as String)
        .where((id) => id.isNotEmpty)
        .toSet();

    final Map<String, Map<String, dynamic>> byUserId = {
      for (final r in filteredRestaurants)
        ((r['user_id'] ?? r['id'] ?? '') as String?) ?? '':
            r as Map<String, dynamic>,
    }..removeWhere((key, value) => key.isEmpty);

    for (final r in allRestaurants) {
      final String? uid = (r['user_id'] ?? r['id'] ?? '') as String?;
      if (uid != null && ownerIds.contains(uid)) {
        byUserId.putIfAbsent(uid, () => r as Map<String, dynamic>);
      }
    }

    setState(() {
      displayedRestaurants = byUserId.values.toList();
      displayedDishes = filteredDishes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchProvider = context.watch<SearchProvider>();
    if (searchProvider.searchQuery.isNotEmpty &&
        _searchController.text != searchProvider.searchQuery) {
      _searchController.text = searchProvider.searchQuery;
      _filterAll(searchProvider.searchQuery);
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
                          onChanged: _filterAll,
                          decoration: InputDecoration(
                            hintText: 'Search dishes or restaurants',
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
                            onPressed: (isLoading || isLoadingDishes)
                                ? null
                                : _refreshAll,
                            child: Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Available Dishes Section FIRST (filtered list)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Dishes',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      if (isLoadingDishes)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (displayedDishes.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No dishes available',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: isSearching ? displayedDishes.length : (displayedDishes.length > 3 ? 3 : displayedDishes.length),
                          itemBuilder: (context, index) {
                            final d =
                                displayedDishes[index] as Map<String, dynamic>;
                            final dishId = (d['id'] ?? '').toString();
                            final dishName = (d['name'] ?? 'Dish') as String;
                            final price = d['price'];
                            final image = d['image'] as String?;
                            final ownerId = (d['user_id_res'] ?? '') as String;
                            final restName =
                                _restaurantNameByUserId[ownerId] ??
                                'Restaurant';
                            final qty = _dishQuantities[dishId] ?? 1;
                            return _buildDishCard(
                              dishId: dishId,
                              dishName: dishName,
                              restaurantName: restName,
                              price: price,
                              imageUrl: image,
                              quantity: qty,
                              ownerId: ownerId,
                            );
                          },
                        ),
                    ],
                  ),
                ),

                // Popular Restaurants Section SECOND (filtered list)
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
                            final r =
                                displayedRestaurants[index]
                                    as Map<String, dynamic>;
                            final name =
                                (r['restaurant_name'] ?? 'Restaurant')
                                    as String;
                            final desc =
                                (r['description'] ?? 'Delicious food awaits!')
                                    as String;
                            final imageUrl = r['image_url'] as String?;
                            return _buildRestaurantCard(name, desc, imageUrl);
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

  Widget _buildRestaurantCard(String name, String subtitle, String? imageUrl) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () {
          _searchController.text = name;
          _filterAll(name);
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
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
                  ],
                ),
              ),
            ],
          ),
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
