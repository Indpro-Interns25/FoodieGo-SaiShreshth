import 'package:flutter/material.dart';

class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override

  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Page'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Second Page data'),
            ElevatedButton(
              onPressed: (){
                Navigator.pushNamed(context, '/first');
              }, 
              child: Text('First Page')
            ),
          ],
        )
      )
    );
  }
}