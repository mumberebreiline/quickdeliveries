import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "About Us",
        ),
      ),
      body: const Center(
        child: Text(
          "Learn more about our company and mission",
          style: TextStyle(
            fontSize: 25,
          ),
        ),
      ),
    );
  }
}
