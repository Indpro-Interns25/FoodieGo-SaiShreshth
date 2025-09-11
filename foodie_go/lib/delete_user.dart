import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

Future<void> deleteGuestUserAccount(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  final session = Supabase.instance.client.auth.currentSession;

  if (user != null && session != null) {
    try {
      final accessToken = session.accessToken;

      final response = await http.post(
        Uri.parse('https://foodie-go-flask.vercel.app/delete_user'), // Replace with your Flask endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        print('User account deleted successfully.');
        await Supabase.instance.client.auth.signOut();
        Navigator.of(context).pushReplacementNamed('/login');
      } else {
        print('Failed to delete user: ${response.body}');
      }
    } catch (e) {
      print('Error deleting user account: $e');
    }
  } else {
    print('No user is currently logged in.');
  }
}
