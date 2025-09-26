import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final supabase = Supabase.instance.client;
  List<dynamic> allItems = [];
  List<dynamic> displayedItems = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchMenuItems();
  }

  Future<void> fetchMenuItems() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await supabase
          .from('dishes')
          .select()
          .eq('user_id_res', supabase.auth.currentUser!.id);
      print("response: "+response.toString());
      if (mounted) {
        setState(() {
          allItems = response as List<dynamic>;
          displayedItems = allItems;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error fetching menu items: $e');
    }
  }

  void filterItems(String query) {
    final filtered = allItems.where((item) {
      final name = item['name'] as String;
      return name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      displayedItems = filtered;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }


  Future<bool> updateAvailability(String dishId, bool availability) async {
    
  
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  final session = supabase.auth.currentSession;
  if (user == null || session == null) {
    print('No user is currently logged in.');
    return false;
  }
  try {
    // Call your API here to update the database
    final accessToken = session.accessToken;
    final response = await http.post(
      Uri.parse('$flaskApiUrl/updateDish'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'mode' : 'updateAvailability',
        'dish_id': dishId,
        'availability': availability,
      },)
    );
    print(response.body);
    print(response.statusCode);
    return response.statusCode == 200;
  } catch (e) {
    print('Error updating availability: $e');
    return false;
  }
}


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        title: null,
        automaticallyImplyLeading: false,
        flexibleSpace: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        filled: true,
                        fillColor: theme.inputDecorationTheme.fillColor ?? Colors.white,
                        prefixIcon: Icon(Icons.search, color: AppColors.primary),
                        contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(color: AppColors.primary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: filterItems,
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: fetchMenuItems,
                        child: ListView.builder(
                            itemCount: displayedItems.length,
                            itemBuilder: (context, index) {
                final item = displayedItems[index];
                item['isUpdating'] = item['isUpdating'] ?? false;
                bool isUpdating = item['isUpdating'] ?? false; // Track update state
                // print("Item_data: "+item.toString());
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          item['description'] ?? 'No description available.',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '\Rs. ${item['price'].toString()}',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            Row(
                              children: [
                                Text("Available:"),
                                Switch(
                                  value: item['availability'] ?? false,
                                  activeColor: AppColors.primary,
                                  activeTrackColor: AppColors.primary.withOpacity(0.5),
                                  onChanged: isUpdating
                                    ? null
                                    : (value) {
                                        print('Switch toggled for ${item['id']} to $value');
                                        setState(() {
                                          item['availability'] = value;
                                          item['isUpdating'] = true;
                                        });
                                        updateAvailability(item['id'], value).then((success) {
                                          print('Update result: $success');
                                          setState(() {
                                            item['isUpdating'] = false;
                                            if (!success) {
                                              item['availability'] = !value;
                                            }
                                          });
                                        });
                                      },

                                ),
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    // Open edit screen or show modal
                                    // openEditDialog(item);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
                            ),
                      ),
              ),
            ],
          ),

          // Add Dish Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    // Controllers for form fields
                    final nameController = TextEditingController();
                    final descriptionController = TextEditingController();
                    final imageController = TextEditingController();
                    final priceController = TextEditingController();
                    bool isAvailable = true;

                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          backgroundColor: AppColors.background,
                          title: const Text('Add New Dish'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(labelText: 'Dish Name'),
                                ),
                                TextField(
                                  controller: descriptionController,
                                  decoration: const InputDecoration(labelText: 'Description'),
                                ),
                                TextField(
                                  controller: imageController,
                                  decoration: const InputDecoration(labelText: 'Image URL'),
                                ),
                                TextField(
                                  controller: priceController,
                                  decoration: const InputDecoration(labelText: 'Price'),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                ),
                                Row(
                                  children: [
                                    const Text('Available:'),
                                    Switch(
                                      value: isAvailable,
                                      activeColor: AppColors.primary,
                                      activeTrackColor: AppColors.primary.withOpacity(0.5),
                                      onChanged: (val) {
                                        setState(() {
                                          isAvailable = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(), // Cancel
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                // Insert into Supabase
                                final name = nameController.text.trim();
                                final description = descriptionController.text.trim();
                                final image = imageController.text.trim();
                                final price = double.tryParse(priceController.text.trim()) ?? 0.0;

                                if (name.isEmpty || price <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter valid name and price')),
                                  );
                                  return;
                                }

                                try {
                                  await supabase.from('dishes').insert({
                                    'user_id_res': supabase.auth.currentUser!.id,
                                    'name': name,
                                    'description': description,
                                    'image': image,
                                    'price': price,
                                    'availability': isAvailable,
                                  });

                                  // Refresh menu
                                  await fetchMenuItems();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Dish added successfully.'), backgroundColor: Colors.green),
                                  );
                                  Navigator.of(context).pop(); // Close dialog
                                } catch (e) {
                                  print('Error adding dish: $e');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to add dish'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),

          ),
        ],
      ),
    );
  }
}



            