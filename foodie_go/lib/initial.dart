import 'package:flutter/material.dart';
import 'dart:async';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override

  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Page'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Initial Page data'),
            SizedBox(height: 20),
            Loading(),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: (){
                Navigator.pushNamed(context, '/first');
              }, 
              child: Text('First Page')
            ),
            SizedBox(height: 20),
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

class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  int count=0;
  Timer? t;

  @override
  void initState(){
    super.initState();
    counter();
  }

  void counter() {
    t = Timer.periodic(Duration(milliseconds: 300), (timer) {
      setState(() {
        count=(count+1)%3;
      });
    });
  }

  void dispose(){
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon( Icons.square_rounded, size: count == 0 ? 30 : count == 2 ? 10 : 20 , color: Colors.orange ),
        SizedBox(width: 10),
        Icon( Icons.square_rounded, size: count == 1 ? 30 :20 , color: Colors.blue ),
        SizedBox(width: 10),
        Icon( Icons.square_rounded, size: count == 2 ? 30 : count == 0 ? 10 : 20 , color: Colors.yellow, ),
      ],
    );
  }
}