import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

Future<void> deleteGuestUserAccount(BuildContext context) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  final session = supabase.auth.currentSession;

  if (user == null || session == null) {
    print('No user is currently logged in.');
    return;
  }

  // Ask for confirmation
  final confirmDelete = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Confirm Delete Account'),
        content: const Text(
            'All the data of this account will be deleted. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), // Confirm
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false), // Cancel
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );

  // Abort if user cancels
  if (confirmDelete != true || confirmDelete == null) return;

  try {
    // Delete role-specific profile
    final role = user.userMetadata?['role'] as String?;
    if (role != null) {
      final tableName = {
        'customer': 'customer_profiles',
        'driver': 'driver_profiles',
        'restaurant': 'restaurant_profiles',
      }[role];
      if (role=='restaurant'){
        await supabase.from('dishes').delete().eq('user_id_res', user.id);
      }
      if (tableName != null) {
        print(tableName+"table deleting");
        await supabase.from(tableName).delete().eq('user_id', user.id);
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
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else {
      print('Failed to delete user: ${httpResponse.body}');
    }
  } catch (e) {
    print('Error deleting user account: $e');
  }
}
