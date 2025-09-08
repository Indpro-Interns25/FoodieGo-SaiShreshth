import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Search extends StatefulWidget {
  const Search({super.key});
  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
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
                          'Search page',
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