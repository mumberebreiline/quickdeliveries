import 'package:flutter/material.dart';

class BreakfastScreen extends StatelessWidget {
  const BreakfastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Breakfast'),
      ),
      body: const Center(
        child: Text('Breakfast items will appear here'),
      ),
    );
  }
}
