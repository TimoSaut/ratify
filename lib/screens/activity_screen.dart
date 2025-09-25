import 'package:flutter/material.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "Activity Screen",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}