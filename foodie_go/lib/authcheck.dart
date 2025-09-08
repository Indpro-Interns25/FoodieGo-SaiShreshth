import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      // User is logged in, navigate to HomePage
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/homepage');
      });
    } else {
      // User is not logged in, navigate to LoginPage
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/login');
      });
    }

    // While checking the auth state, show a loading indicator
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}