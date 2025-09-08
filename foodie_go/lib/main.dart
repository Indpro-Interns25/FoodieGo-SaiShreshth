import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'initial.dart';
// import 'first.dart';
// import 'second.dart';
import 'login.dart';
import 'register.dart';
import 'homepage.dart';
import 'authcheck.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nucuarmmdtfykmkqgdqh.supabase.co',  // from Supabase settings
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im51Y3Vhcm1tZHRmeWtta3FnZHFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY5ODI5OTksImV4cCI6MjA3MjU1ODk5OX0.77vqQQ8Av7q8SQEUTtiowjDpIIauwM2fyxneModptew',              // from Supabase settings
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/authcheck',
      routes: {
        // '/':(context) => const HomePage(),
        // '/first':(context) => const FirstPage(),
        // '/second':(context) => const SecondPage(),
        '/':(context) => const AuthCheck(),
        '/authcheck':(context) => const AuthCheck(),
        '/login':(context) => const LoginPage(),
        '/register':(context) => const RegisterPage(),
        '/homepage':(context) => const HomePage(),
      },
    );
  }
}
