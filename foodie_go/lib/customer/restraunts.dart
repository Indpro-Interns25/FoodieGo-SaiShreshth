import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'search_provider.dart';
import '../constants.dart';

class RestaurantsPage extends StatefulWidget {
  final Function(int) onTabTapped;
  const RestaurantsPage({super.key, required this.onTabTapped});
  @override
  State<RestaurantsPage> createState() => _RestaurantsPageState();
}

class _RestaurantsPageState extends State<RestaurantsPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<dynamic> allRestaurants = [];
  List<dynamic> displayedRestaurants = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    _fetchRestaurants();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRestaurants() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await supabase.from('restaurant_profiles').select();
      if (!mounted) return;
      setState(() {
        allRestaurants = response as List<dynamic>;
        displayedRestaurants = allRestaurants;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching restaurants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load restaurants'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterRestaurants(String query) {
    final lower = query.toLowerCase();
    final filtered = allRestaurants.where((r) {
      final name = (r['restaurant_name'] ?? '') as String;
      final desc = (r['description'] ?? '') as String;
      return name.toLowerCase().contains(lower) ||
          desc.toLowerCase().contains(lower);
    }).toList();

    setState(() {
      displayedRestaurants = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching =
        _searchFocus.hasFocus || _searchController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchRestaurants,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Search + Refresh (only while typing)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          onChanged: _filterRestaurants,
                          decoration: InputDecoration(
                            hintText: 'Search restaurants',
                            prefixIcon: const Icon(Icons.search),
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
                        const SizedBox(width: 10),
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
                            onPressed: isLoading ? null : _fetchRestaurants,
                            child: const Icon(Icons.refresh),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Grid of restaurants
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : displayedRestaurants.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'No restaurants found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.82,
                              ),
                          itemCount: displayedRestaurants.length,
                          itemBuilder: (context, index) {
                            final r =
                                displayedRestaurants[index]
                                    as Map<String, dynamic>;
                            final name =
                                (r['restaurant_name'] ?? 'Restaurant')
                                    as String;
                            final desc = (r['description'] ?? '') as String;
                            final imageUrl = r['image_url'] as String?;
                            return _RestaurantCard(
                              name: name,
                              description: desc,
                              imageUrl: imageUrl,
                              onTap: () {
                                Provider.of<SearchProvider>(context, listen: false).setSearchQuery(name);
                                widget.onTabTapped(0);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final String name;
  final String description;
  final String? imageUrl;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imageFallback(),
                      )
                    : _imageFallback(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description.isEmpty
                        ? 'Tasty dishes and great service'
                        : description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: AppColors.surface,
      child: Icon(Icons.storefront, color: AppColors.textLight),
    );
  }
}