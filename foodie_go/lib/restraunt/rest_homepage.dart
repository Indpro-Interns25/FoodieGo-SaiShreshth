import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../auth/logout.dart';
import '../intro.dart';
import '../auth/logout.dart';
import '../auth/delete_user.dart';
import '../constants.dart';

import 'menu.dart';
import 'orders.dart';
import 'payments.dart';
import 'reviews.dart';
import 'analytics.dart';
import 'profile.dart';

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

  @override
  void dispose() {
    super.dispose();
  }


  Future<void> fetchUsername() async {
    print("user: "+user!.toString());
    print("userid: "+user!.id);
    try {
      final response = await Supabase.instance.client
          .from('restaurant_profiles')
          .select('restaurant_name')
          .eq('user_id', user!.id);
      print("response: "+response.toString());
      if (mounted) {
        setState(() {
          username = response[0]['restaurant_name'] as String?;
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
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text('FoodieGo-Rest', style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 25,
        ),),
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
                    child: Icon(Icons.person, size: 35, color: AppColors.primary,),
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
                color: AppColors.primary,
              ),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Profile()),
                );
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
                _onItemTapped(1);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.payment_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Payments'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(2);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.star_border_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Reviews'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(3);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.analytics_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Analytics'),
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(4);
              },
            ),
            ListTile(title: SizedBox(height: 150)),
            // ListTile(
            //   leading: const Icon(
            //     Icons.shopping_bag_outlined,
            //     color: AppColors.primary,
            //   ),
            //   title: const Text('My Orders'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     // Navigate to orders page
            //     // Navigator.pushNamed(context, '/orders');
            //   },
            // ),
            // const Divider(),
            // ListTile(
            //   leading: const Icon(
            //     Icons.support_agent_outlined,
            //     color: AppColors.primary,
            //   ),
            //   title: const Text('Reviews'),
            //   onTap: () {
            //     Navigator.pop(context);
            //     // Navigate to support page
            //     // Navigator.pushNamed(context, '/support');
            //   },
            // ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: AppColors.primary,
              ),
              title: const Text('Logout'),
              onTap: () async {
                await LogoutHelper.logout(context);
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
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'For any problems, please contact support@foodiego.com',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),


      body: IndexedStack(
        index: _selectedIndex,
        children: [
          Menu(),
          Orders(),
          Payments(),
          Reviews(),
          Analytics(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items:<BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded , color: AppColors.primary,),
            label: 'Menu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded , color: AppColors.primary,),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment_rounded , color: AppColors.primary,),
            label: 'Payments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_border_rounded , color: AppColors.primary,),
            label: 'Reviews',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_rounded , color: AppColors.primary,),
            label: 'Analytics',
          )
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