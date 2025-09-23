import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/delete_user.dart';
import '../intro.dart';
import '../constants.dart';

import 'home.dart';
import 'restraunts.dart';
import 'cart.dart';
import 'profile.dart';
import 'orders.dart';
import 'cart_provider.dart';
import 'checkout.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<HomeState> _homeKey = GlobalKey<HomeState>();
  bool hasSeenIntro = false;

  final user = Supabase.instance.client.auth.currentUser;
  String? username;
  int _selectedIndex = 0;

  Timer? _confirmationTimer;
  bool _showConfirmationPopup = false;
  bool _wasLoggedOut = true;
  bool _confirming = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    checkFirstTime();
    fetchUsername();
    Provider.of<CartProvider>(context, listen: false).loadCart().then((_) {
      // After loading cart, check if logged in and cart not empty
      final cart = Provider.of<CartProvider>(context, listen: false);
      if (user != null && cart.cartCount > 0 && _wasLoggedOut) {
        _showConfirmationPopup = true;
        _startConfirmationTimer();
        _wasLoggedOut = false;
        _showPopup();
      }
    });

    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      if (event == AuthChangeEvent.signedIn) {
        final cart = Provider.of<CartProvider>(context, listen: false);
        if (cart.cartCount > 0 && _wasLoggedOut) {
          _showConfirmationPopup = true;
          _startConfirmationTimer();
          _wasLoggedOut = false;
          _showPopup();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _wasLoggedOut = true;
        _cancelConfirmationTimer();
      }
    });
  }

  Future<void> fetchUsername() async {
    try {
      final response = await Supabase.instance.client
          .from('customer_profiles')
          .select('username')
          .eq('user_id', user!.id)
          .single();

      if (mounted) {
        setState(() {
          username = response['username'] as String;
        });
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
  }

  void _startConfirmationTimer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(const Duration(minutes: 5), () {
      // Expire the order after 5 minutes - clear cart
      Provider.of<CartProvider>(context, listen: false).clearCart();
      if (mounted) {
        setState(() {
          _showConfirmationPopup = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order expired due to no confirmation.')),
        );
      }
    });
  }

  void _cancelConfirmationTimer() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
  }

  void _showPopup() {
    if (!_showConfirmationPopup) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return; // Prevent multiple dialogs
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Order Confirmation'),
            content: const Text('Please confirm your order within 5 minutes.'),
            actions: [
              TextButton(
                onPressed: _cancelling ? null : () async {
                  setState(() => _cancelling = true);
                  await Provider.of<CartProvider>(context, listen: false).clearCart();
                  setState(() => _cancelling = false);
                  Navigator.of(context).pop();
                  setState(() {
                    _showConfirmationPopup = false;
                  });
                  _cancelConfirmationTimer();
                },
                child: _cancelling
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _confirming ? null : () {
                  setState(() => _confirming = true);
                  Navigator.of(context).pop();
                  setState(() {
                    _showConfirmationPopup = false;
                    _confirming = false;
                  });
                  _cancelConfirmationTimer();
                  // Navigate to CheckoutPage
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CheckoutPage()),
                    );
                  }
                },
                child: _confirming
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );
    });
  }

  Future<void> _confirmOrder() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final orders = await supabase
          .from('orders')
          .select('id, status')
          .eq('user_id', user.id)
          .eq('status', 'waiting for confirmation')
          .order('placed_at', ascending: false)
          .limit(1);

      if (orders != null && orders.isNotEmpty) {
        final orderId = orders[0]['id'];
        await supabase
            .from('orders')
            .update({'status': 'confirmed'})
            .eq('id', orderId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order confirmed successfully!')),
          );
        }
      }
    } catch (e) {
      print('Error confirming order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to confirm order')),
        );
      }
    }
  }

  Future<void> checkFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('seen_intro') ?? false;
    if (mounted) {
      setState(() {
        hasSeenIntro = seen;
      });
    }
  }

  Future<void> _setIntroAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_intro', true);
    if (mounted) {
      setState(() {
        hasSeenIntro = true;
      });
    }
  }

  Future<void> _onItemTapped(int index) async {
    if (index == 0) {
      _homeKey.currentState?.resetSearch();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!hasSeenIntro) {
      return IntroductionPage(onComplete: _setIntroAsSeen);
    }
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'FoodieGo',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        automaticallyImplyLeading: true,
        backgroundColor: AppColors.secondary,
        iconTheme: const IconThemeData(
          color: AppColors.primary,
        ),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 35,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username ?? 'Guest User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
              ),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 4; // Set to Profile tab
                });
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
              ),
              title: const Text('My Orders'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 2; // Set to My Orders tab
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.support_agent_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Support'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to support page
                // Navigator.pushNamed(context, '/support');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.primary,
              ),
              title: const Text('Logout'),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: AppColors.primary,
              ),
              title: const Text('Delete account'),
              onTap: () async {
                deleteGuestUserAccount(context);
              },
            ),
          ],
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Home(key: _homeKey),
          RestaurantsPage(onTabTapped: _onItemTapped),
          OrdersPage(
            onPageInit: () {
              setState(() {
                _selectedIndex = 0; // Reset to Home tab
              });
            },
            showAppBar: _selectedIndex != 2, // Hide app bar when accessed via bottom nav
          ),
          CartPage(),
          Profile(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.local_restaurant_rounded,
              color: AppColors.primary,
            ),
            label: 'Restaurants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long, color: AppColors.primary),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(
            icon: Consumer<CartProvider>(
              builder: (context, cart, child) {
                final hasItems = cart.cartCount > 0;
                
                final baseIcon = Icon(
                  hasItems
                      ? Icons.shopping_cart_checkout
                      : Icons.shopping_cart_outlined,
                  color: AppColors.primary,
                );
                if (!hasItems) return baseIcon;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    baseIcon,
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            cart.cartCount > 99 ? '99+' : '${cart.cartCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: AppColors.background,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
