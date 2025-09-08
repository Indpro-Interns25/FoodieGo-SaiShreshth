import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Cart extends StatefulWidget {
  const Cart({super.key});
  @override
  State<Cart> createState() => _CartState();
}

class _CartState extends State<Cart> {
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
                          'Your Cart',
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