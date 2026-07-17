/*
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../order/order_finalize_screen.dart';
import '../order/sauce_item.dart'; // Using the global shared model
*/
/*
// Model to represent a sauce item cleanly from Firestore data
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
*/


/*
  // Factory constructor to map Firestore document snapshots easily
  void SauceItem.dynamic fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SauceItem(
      id: doc.id,
      name: data['name'] ?? 'Unknown Sauce',
      price: data['price'] ?? '\$0.00',
      imageUrl: data['imageUrl'] ?? 'https://unsplash.com', // fallback placeholder
    );
  }
}

class MeatSauceScreen extends StatefulWidget {
  const MeatSauceScreen({super.key});

  @override
  State<MeatSauceScreen> createState() => _MeatSauceScreenState();
}

class _MeatSauceScreenState extends State<MeatSauceScreen> {
  int cartCount = 0;

  void addToCart() {
    setState(() {
      cartCount++;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to cart!'),
        duration: Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meat Sauces'),
        centerTitle: true,
      ),
      // StreamBuilder listens to Firestore collection modifications in real-time
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('meat_sauces').snapshots(),
        builder: (context, snapshot) {
          // 1. Handle Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Handle Errors
          if (snapshot.hasError) {
            return Center(child: Text('Error loading data: ${snapshot.error}'));
          }

          // 3. Handle Empty State
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No sauces available at the moment.'));
          }

          // 4. Map Firestore documents to our local clean Model
          final List<SauceItem> meatSauces = snapshot.data!.docs
              .map((doc) => SauceItem.fromFirestore(doc))
              .toList();

          // 5. Build the 2-column Grid Layout
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: meatSauces.length,
            itemBuilder: (context, index) {
              final item = meatSauces[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderFinalizeScreen(selectedItem: item),
                  ),
                ),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            // Error builder for broken Firestore image links
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.price,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                                  onPressed: addToCart,
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to structural checkout path
        },
        child: Badge(
          label: Text('$cartCount'),
          isLabelVisible: cartCount > 0,
          child: const Icon(Icons.shopping_cart),
        ),
      ),
    );
  }
}
*/
// PLACEHOLDER BELOW

import 'package:flutter/material.dart';
class MeatSauceScreen extends StatelessWidget {
  const MeatSauceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Meat Sauces Menu')));
}
