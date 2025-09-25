import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "Dashboard Screen",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}