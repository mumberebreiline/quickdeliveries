/*
import 'package:cloud_firestore/cloud_firestore.dart';

class SauceItem {
  final String id;
  final String name;
  final String price;
  final String imageUrl;

  const SauceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
  });

  /// Factory constructor to safely map a Firestore DocumentSnapshot into a SauceItem object.
  factory SauceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return SauceItem(
      id: doc.id,
      name: data['name'] ?? 'Unknown Sauce',
      price: data['price'] ?? '\$0.00',
      imageUrl: data['imageUrl'] ?? 'https://unsplash.com', // Fallback placeholder image
    );
  }

  /// Converts a SauceItem object into a Map structure if you need to upload data back to Firestore later.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
    };
  }
}
*/

//PLACEHOLDER BELOW
import 'package:flutter/material.dart';
// TODO: Import your target screens here
import '../home/meat_sauce_screen.dart';
import '../home/vegetable_sauce_screen.dart';

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
                imageUrl: 'https://unsplash.com', // Bolognese/Meat sauce
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
                imageUrl: 'https://unsplash.com', // Fresh veggies/pesto
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
