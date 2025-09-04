import 'package:flutter/material.dart';
// import 'initial.dart';
// import 'first.dart';
// import 'second.dart';
import 'login.dart';
import 'register.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',
      routes: {
        // '/':(context) => const HomePage(),
        // '/first':(context) => const FirstPage(),
        // '/second':(context) => const SecondPage(),
        '/login':(context) => const LoginPage(),
        '/register':(context) => const RegisterPage(),
      },
    );
  }
}
