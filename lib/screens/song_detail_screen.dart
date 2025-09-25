import 'package:flutter/material.dart';

class SongDetailScreen extends StatelessWidget {
  const SongDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "Song Detail Screen",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}