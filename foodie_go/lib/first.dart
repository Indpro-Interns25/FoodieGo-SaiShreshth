import 'package:flutter/material.dart';

class FirstPage extends StatelessWidget {
  const FirstPage({super.key});

  @override

  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('First Page'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('First Page data'),
            ElevatedButton(
              onPressed: (){
                Navigator.pushNamed(context, '/second');
              }, 
              child: Text('Second Page')
            ),
          ],
        )
      )
    );
  }
}