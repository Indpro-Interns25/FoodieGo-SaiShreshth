import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'auth/login.dart';
import 'auth/register.dart';
import 'customer/cart_provider.dart';
import 'customer/search_provider.dart';
import 'customer/homepage.dart' as cust;
import 'auth/authcheck.dart';
import 'restraunt/rest_homepage.dart' as rest;
import 'driver/driv_homepage.dart' as driv;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nucuarmmdtfykmkqgdqh.supabase.co', // from Supabase settings
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51Y3Vhcm1tZHRmeWtta3FnZHFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5ODI5OTksImV4cCI6MjA3MjU1ODk5OX0.77vqQQ8Av7q8SQEUTtiowjDpIIauwM2fyxneModptew', // from Supabase settings
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CartProvider()..loadCart()),
        ChangeNotifierProvider(create: (context) => SearchProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/authcheck',
      routes: {
        '/': (context) => const AuthCheck(),
        '/authcheck': (context) => const AuthCheck(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/homepage': (context) => const cust.HomePage(),
        '/rest_homepage': (context) => const rest.HomePage(),
        '/driv_homepage': (context) => const driv.HomePage(),
      },
    );
  }
}
