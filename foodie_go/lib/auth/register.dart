import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserType {
  customer,
  restaurant,
  driver
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _restaurantNameController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();
  UserType _selectedUserType = UserType.customer;
  bool _isLoading = false;
  String? _errorMessage;
  String? _tempUserId;
  bool _emailSubmitted = false;

  Future<void> _handleRegister() async {
    if(!_emailSubmitted){
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_emailController.text.isEmpty ||
      _passwordController.text.isEmpty ||
      _usernameController.text.isEmpty) {
        throw const AuthException('Please fill in all fields.');
      }

      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'username': _usernameController.text.trim(),
          'role': _selectedUserType.toString().split('.').last,
        },
      );

      if (response.user == null) {
        throw const AuthException('Registration failed. Please try again.');
      }

      _tempUserId = response.user!.id;
      setState(() {
        _emailSubmitted = true;
      });
      if (mounted) {
        // Navigator.of(context).pushReplacementNamed('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please check your email to verify your account before logging in.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.\n'+error.toString();
        print(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // profile creation
    }else{
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
    );
    if(response.user == null || response.user!.emailConfirmedAt == null || _tempUserId == null || response.session == null){
      setState(() {
        _errorMessage = 'Please verify your email before creating profile.';
        _isLoading = false;
      });
      return;
    }
    try {
      if (_usernameController.text.isEmpty ||
      _phoneController.text.isEmpty) {
        throw const AuthException('Please fill in all fields.');
      }
      final phoneno = int.tryParse(_phoneController.text.trim());
      if (phoneno == null) {
        throw const AuthException('Please enter a valid phone number.');
      }

      switch (_selectedUserType) {
        case UserType.restaurant:
          if (_restaurantNameController.text.isEmpty || _addressController.text.isEmpty) {
            throw const AuthException('Please fill in all restaurant details.');
          }
          await Supabase.instance.client
            .from('restaurant_profiles')
            .insert({
              'user_id': _tempUserId,
              'username': _usernameController.text.trim(),
              'phone_no': phoneno,
              'restaurant_name': _restaurantNameController.text.trim(),
              'address': _addressController.text.trim(),
              'created_at': DateTime.now().toIso8601String(),
            });
          break;

        case UserType.driver:
          if (_vehicleNumberController.text.isEmpty) {
            throw const AuthException('Please enter vehicle number.');
          }
          await Supabase.instance.client
            .from('driver_profiles')
            .insert({
              'user_id': _tempUserId,
              'username': _usernameController.text.trim(),
              'phone_no': phoneno,
              'vehicle_number': _vehicleNumberController.text.trim(),
              'created_at': DateTime.now().toIso8601String(),
            });
          break;

        case UserType.customer:
          if (_addressController.text.isEmpty) {
            throw const AuthException('Please enter address.');
          }
          await Supabase.instance.client
            .from('customer_profiles')
            .insert({
              'user_id': _tempUserId,
              'username': _usernameController.text.trim(),
              'phone_no': phoneno,
              'address': _addressController.text.trim(),
              'created_at': DateTime.now().toIso8601String(),
            });
          break;
      }
      await Supabase.instance.client.auth.signOut(); // sign out after registration

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Registration successful!\nPlease log in.'),
            backgroundColor: Colors.green
          ),
        );
      }
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = '\t\tProfile creation failed.\n';
        print(error);
        if (error.toString().contains('Forbidden')) {
          const SnackBar(
            content: Text('A profile for this user may already exist.'),
            backgroundColor: Colors.red,
          );
          Navigator.of(context).pushReplacementNamed('/login');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _restaurantNameController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 212, 179, 156),
      resizeToAvoidBottomInset: true, // This helps handle keyboard properly

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 212, 179, 156),
      ),

      body: SafeArea(
        child: SingleChildScrollView( // Allow scrolling when keyboard appears
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
              minHeight: MediaQuery.of(context).size.height - AppBar().preferredSize.height - MediaQuery.of(context).padding.top,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0, // Add bottom padding when keyboard is visible
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      const Text(
                        'Register:',
                        style: TextStyle(
                          color: Color.fromARGB(255, 243, 105, 77),
                          fontWeight: FontWeight.bold,
                          fontSize: 25,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Username textbox
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                            hoverColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // usertype dropdown
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: DropdownButtonFormField<UserType>(
                          initialValue: _selectedUserType,
                          decoration: InputDecoration(
                            labelText: 'Register as',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (UserType? newValue) {
                            setState(() {
                              _selectedUserType = newValue!;
                            });
                          },
                          items: UserType.values.map((UserType type) {
                            return DropdownMenuItem<UserType>(
                              value: type,
                              child: Text(type.toString().split('.').last),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Appropriate fields for user type selected
                  if (_selectedUserType == UserType.restaurant) ...[
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            controller: _restaurantNameController,
                            decoration: InputDecoration(
                              labelText: 'Restaurant Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else if (_selectedUserType == UserType.driver) ...[
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            controller: _vehicleNumberController,
                            decoration: InputDecoration(
                              labelText: 'Vehicle Number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ]
                  else if (_selectedUserType == UserType.customer) ...[
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  // contact number textbox
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Contact Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Email textbox
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            hoverColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Password textbox
                  Row(
                    children: [
                      const SizedBox(width: 20),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Display error message if any
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  // Register Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          // register logic
                          if (!_isLoading) {
                            _handleRegister();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 243, 105, 77),
                        ),
                        child: _isLoading ?
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )

                        : Text(
                          _emailSubmitted ? 'Create Profile' : 'Verify Email',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Register option redirect
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 243, 105, 77)),
                        ),
                      )
                    ]
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
