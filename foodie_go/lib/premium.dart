import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Premium extends StatefulWidget {
  const Premium({super.key});
  @override
  State<Premium> createState() => _PremiumState();
}

class _PremiumState extends State<Premium> {
  @override

  Widget build(BuildContext context) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        const Text(
                          'Premium plans coming soon!',
                          style: TextStyle(
                            color: Color.fromARGB(255, 243, 105, 77),
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    
  }
}