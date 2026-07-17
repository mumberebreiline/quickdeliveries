import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import 'order_detail_screen.dart';
import '../../services/cart_service.dart';

// Shows a scrollable list of food items pulled live from Firestore.
// Pass a "category" (like "Breakfast") to only show that category's
// foods, or leave it null to show everything in the "foods" collection.
class VegetarianMealsScreen extends StatelessWidget {
  final String? category;

  const VegetarianMealsScreen({super.key, this.category});

  // Builds the Firestore query. If a category was passed in, only
  // fetch foods that match it; otherwise fetch the whole collection.
  Stream<QuerySnapshot> _foodStream() {
    final collection = FirebaseFirestore.instance.collection('foods');
    if (category != null) {
      return collection.where('category', isEqualTo: category).snapshots();
    }
    return collection.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category ?? 'Vegetarian Meals'),
        backgroundColor: Colors.orange,
      ),
      // StreamBuilder rebuilds this screen automatically whenever the
      // data in Firestore changes — no manual refresh needed.
      body: StreamBuilder<QuerySnapshot>(
        stream: _foodStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No meals found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final food = FoodItem.fromFirestore(docs[index].id, data);
              return FoodListCard(food: food);
            },
          );
        },
      ),
    );
  }
}

// One card in the list: picture + name + price (all tappable to open
// the order/finalize screen) plus an "Add to Cart" button underneath.
class FoodListCard extends StatelessWidget {
  final FoodItem food;

  const FoodListCard({super.key, required this.food});

  void _openOrderDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailScreen(food: food)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Tapping the picture, name, or price opens the order screen.
            GestureDetector(
              onTap: () => _openOrderDetails(context),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      food.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      // Shows a placeholder if the picture link is broken
                      // or hasn't been added yet.
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.fastfood),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          width: 80,
                          height: 80,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${food.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Quick "Add to Cart" — adds 1 of this item straight away.
            // For choosing a different quantity, the user taps the
            // picture/name/price above to go to the order screen instead.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  CartService.instance.addItem(food, 1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${food.name} added to cart')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'ADD TO CART',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}