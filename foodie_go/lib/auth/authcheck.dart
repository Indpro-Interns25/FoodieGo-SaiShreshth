import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'delete_user.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _navigated = false; // Ensure navigation happens only once

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  Future<void> _checkUser() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _redirect('/login');
    } else {
      String? type = user.userMetadata?['role'] as String?;
      if (type == null) {
        _redirect('/login');
      } else {
        if (type == 'customer') {
          _redirect('/homepage');
        } else if (type == 'driver') {
          _redirect('/driv_homepage');
        } else if (type == 'restaurant') {
          _redirect('/rest_homepage');
        } else {
          _redirect('/login');
        }
      }
    }
  }

  void _redirect(String route) {
    if (!_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed(route);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username = user?.userMetadata?['username']; // or from user_metadata
    print(username);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 211, 201),
      appBar: AppBar(
        title: const Text(
          'FoodieGo',
          style: TextStyle(
            color: Color.fromARGB(255, 243, 105, 77),
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 212, 179, 156),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 243, 105, 77),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color.fromARGB(255, 243, 105, 77)),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
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
                    child: Icon(Icons.person, size: 35, color: Color.fromARGB(255, 243, 105, 77)),
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
              leading: const Icon(Icons.support_agent_outlined, color: Color.fromARGB(255, 243, 105, 77)),
              title: const Text('Support'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/support');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Color.fromARGB(255, 243, 105, 77)),
              title: const Text('Logout'),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Color.fromARGB(255, 243, 105, 77),
              ),
              title: const Text('Delete account'),
              onTap: () async {
                deleteGuestUserAccount(context);
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
