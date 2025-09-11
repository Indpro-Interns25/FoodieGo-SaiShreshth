import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logout.dart';
import 'intro.dart';

import 'home.dart';
import 'search.dart';
import 'cart.dart';
import 'profile.dart';
import 'premium.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool hasSeenIntro = false;

  final user = Supabase.instance.client.auth.currentUser;
  String? username;
  int _selectedIndex=0;

  @override
  void initState() {
    super.initState();
    checkFirstTime();
    fetchUsername();
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
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if(!hasSeenIntro) {
      return IntroductionPage(onComplete: _setIntroAsSeen);
    }
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 211, 201),
      
      appBar: AppBar(
        title: const Text('FoodieGo', style: TextStyle(
          color: Color.fromARGB(255, 243, 105, 77),
          fontWeight: FontWeight.bold,
          fontSize: 25,
        ),),
        automaticallyImplyLeading: true,
        backgroundColor: const Color.fromARGB(255, 185, 112, 61),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 243, 105, 77), //change your color here
        ),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: Color.fromARGB(255, 243, 105, 77),),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    username ?? 'Guest User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);

                // Navigate to profile page
                // Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.shopping_bag_outlined,
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              title: const Text('My Orders'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to orders page
                // Navigator.pushNamed(context, '/orders');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.favorite_border,
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              title: const Text('Favorites'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to favorites page
                // Navigator.pushNamed(context, '/favorites');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.location_on_outlined,
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              title: const Text('Delivery Addresses'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to addresses page
                // Navigator.pushNamed(context, '/addresses');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.support_agent_outlined,
                color: Color.fromARGB(255, 243, 105, 77),
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
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              title: const Text('Logout'),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),


      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Home(),
          Search(),
          Cart(),
          Profile(),
          Premium(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items:<BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Color.fromARGB(255, 243, 105, 77),),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search, color: Color.fromARGB(255, 243, 105, 77),),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart, color: Color.fromARGB(255, 243, 105, 77),),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person, color: Color.fromARGB(255, 243, 105, 77),),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/premium.png', width: 24, height: 24,),
            label: 'Premium',
          )
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 243, 105, 77),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: const Color.fromARGB(255, 224, 211, 201),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}