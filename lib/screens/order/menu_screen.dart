import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Our Menu",
        ),
      ),
      body: const Center(
        child: Text(
          "Food items will appear here",
          style: TextStyle(
            fontSize: 25,
          ),
        ),
      ),
    );
  }
}
