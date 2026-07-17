import 'package:flutter/material.dart';
import 'meat_sauce_screen.dart';
import 'vegetable_sauce_screen.dart';

class SauceScreen extends StatelessWidget {
  const SauceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sauce Category'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Meat Sauce Category
            Expanded(
              child: SauceCategoryCard(
                title: 'Meat Sauces',
                imageUrl: 'assets/beef-stew-30.jpg', //Meat sauce
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MeatSauceScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Vegetable Sauce Category
            Expanded(
              child: SauceCategoryCard(
                title: 'Vegetable Sauces',
                imageUrl: 'assets/images/Screenshot_2026-07-12-20-12-22-13.jpg', // Fresh veggies
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VegetableSauceScreen()),
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
class SauceCategoryCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const SauceCategoryCard({
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
            // Dark Overlay for readability
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(110),
              ),
            ),
            // Centered Title Text
            Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
