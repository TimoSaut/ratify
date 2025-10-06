import 'package:flutter/material.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "Album Detail Screen",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
