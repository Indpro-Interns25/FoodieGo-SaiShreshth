import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 212, 179, 156),
      
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 212, 179, 156),
      ),
      
      body: Center(
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
                          'Login:',
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
                    // Password textbox
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
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

                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children:[
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context,'/forgotpassword');
                          }, 
                          child: 
                            Text('Forgot Password?', 
                              style: TextStyle(
                                color: Color.fromARGB(255, 243, 105, 77),
                                
                              ),
                            ), 
                        )
                      ]
                    ),

                    // Login Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            // login logic
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 243, 105, 77),
                          ),
                          child: const Text(
                            'Login',
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
                            Navigator.pushNamed(context, '/register');
                          }, 
                          child: const Text(
                            'Register',
                            style: TextStyle(fontSize: 18, color: Color.fromARGB(255, 243, 105, 77)),
                          ),
                        )
                      ]
                    ),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}