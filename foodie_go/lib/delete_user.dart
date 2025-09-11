import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

Future<void> deleteGuestUserAccount(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  final session = supabase.auth.currentSession;
  final role = user?.userMetadata?['role'];

  if (user == null || session == null) {
    print('No user is currently logged in.');
    return;
  }

  try {
    // Delete role-specific profile
    if (role != null) {
      final tableName = {
        'customer': 'customer_profiles',
        'driver': 'driver_profiles',
        'restaurant': 'restaurant_profiles',
      }[role];

      if (tableName != null) {
        final response = await supabase
            .from(tableName)
            .delete()
            .eq('user_id', user.id);

        // if (response.error != null) {
        //   print('Failed to delete profile: ${response.error!.message}');
        //   return;
        // }
      }
    }

    // Delete Supabase auth user via Flask endpoint
    final accessToken = session.accessToken;
    final httpResponse = await http.post(
      Uri.parse('https://foodie-go-flask.vercel.app/delete_user'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (httpResponse.statusCode == 200) {
      print('User account deleted successfully.');
      await supabase.auth.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      print('Failed to delete user: ${httpResponse.body}');
    }
  } catch (e) {
    print('Error deleting user account: $e');
  }
}
