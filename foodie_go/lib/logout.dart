import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class Logout extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
      await Supabase.instance.client.auth.signOut();

      // after logout, navigate back to login
      Navigator.pushReplacementNamed(context, '/login');
      const SnackBar(
        content: Text('Logged out successfully'),
        backgroundColor: Colors.green,
      );
    }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.logout, color: const Color.fromARGB(255, 243, 105, 77),),
      onPressed: () => {
        _logout(context),
      },
    );
  }
}