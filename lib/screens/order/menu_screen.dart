/*
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
*/

import 'package:flutter/material.dart';
// TODO: Import your target screens here
import 'breakfast_screen.dart';
import 'lunch_screen.dart';
import 'supper_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Meal'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Breakfast Button
            Expanded(
              child: CategoryCard(
                title: 'Breakfast',
                imageUrl: 'assets/images/Ugandan-Rolex.jpg',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BreakfastScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Lunch Button
            Expanded(
              child: CategoryCard(
                title: 'Lunch',
                imageUrl: 'assets/jollof-rice.jpg',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LunchScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Supper Button
            Expanded(
              child: CategoryCard(
                title: 'Supper',
                imageUrl: 'assets/jollof-rice.jpg',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SupperScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable Widget for the Tappable Image Card
class CategoryCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const CategoryCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
            // Dark Overlay to make text readable
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(100),
              ),
            ),
            // Centered Title Text
            Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
