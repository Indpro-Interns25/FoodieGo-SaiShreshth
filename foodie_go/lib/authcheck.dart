import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      String? type = user.userMetadata?['role'] as String?;
      
      if (type == null) {
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/login');
        });
        return Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      // Navigate based on the role
      if (type == 'customer') {
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/homepage');
        });
      } else if (type == 'driver') {
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/driv_homepage');
        });
      } else if (type == 'restaurant') {
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/rest_homepage');
        });
      } else {
        // Unknown role fallback
        Future.microtask(() {
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }

      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    } else {
      // User not logged in
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
  }
}
