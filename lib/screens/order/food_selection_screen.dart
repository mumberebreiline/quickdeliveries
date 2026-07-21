import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import 'main_course_order_detail_screen.dart';
import '../../services/cart_service.dart';
import '../../services/cart_screen.dart';

// ============================================================
// 📂 THIS SCREEN IS FOR "main courses" SPECIFICALLY
// ============================================================
// Points at: Categories/main courses/Meals
//
// This is the ONLY selection screen wired up to
// MainCourseOrderDetailScreen (the version WITH the accompaniments
// dropdown), because your Firestore data shows that's the category
// with meaningful accompaniments (e.g. "white rice").
//
// Your other selection screens (breakfast_selection_screen.dart,
// drinks.dart, vegetarian_meals_screen.dart) still import the plain
// order_detail_screen.dart — no changes needed there, they'll
// automatically NOT show a dropdown.
// ============================================================

class FoodSelectionScreen extends StatelessWidget {
  const FoodSelectionScreen({super.key});

  // Points at: Categories/main courses/Meals
  Stream<QuerySnapshot> _mealsStream() {
    return FirebaseFirestore.instance
        .collection('Categories')
        .doc('main courses')
        .collection('Meals')
        .snapshots();
  }

  // Turns one "Meals" document into a FoodItem. Checks a capitalized
  // field name first, then falls back to lowercase — your actual
  // "main courses" documents use lowercase (name/price/image), so
  // this covers both.
  FoodItem _mealFromDoc(String id, Map<String, dynamic> data) {
    String pick(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = data[key];
        if (value != null) return value.toString();
      }
      return fallback;
    }

    final priceString = pick(['Price', 'price'], '0');

    return FoodItem(
      id: id,
      name: pick(['Name', 'name'], 'Unnamed'),
      price: double.tryParse(priceString) ?? 0.0,
      imageUrl: pick(['Image', 'imageUrl', 'image'], ''),
      category: 'main courses',
    );
  }

  void _openCart(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Main Courses'),
        backgroundColor: Colors.orange,
        actions: [
          // 🛒 Cart icon with a live badge showing how many items are
          // currently in the cart. Updates automatically whenever the
          // cart changes anywhere in the app.
          ListenableBuilder(
            listenable: CartService.instance,
            builder: (context, _) {
              final count = CartService.instance.itemCount;
              return IconButton(
                onPressed: () => _openCart(context),
                icon: Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.shopping_cart),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _mealsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load main courses:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No main courses found.\n\n'
                  'Add documents inside:\n'
                  'Categories → main courses → Meals',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.68,
            ),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final food = _mealFromDoc(docs[index].id, data);
              return _MainCourseCard(food: food);
            },
          );
        },
      ),
    );
  }
}

// One card in the grid: picture, name, price, an "Order Now" button
// that opens the Main-Course-specific order screen (with the
// accompaniments dropdown), and a smaller "Add to Cart" button.
class _MainCourseCard extends StatelessWidget {
  final FoodItem food;

  const _MainCourseCard({required this.food});

  void _openOrderScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MainCourseOrderDetailScreen(food: food)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openOrderScreen(context),
              child: Image.network(
                food.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: const Icon(Icons.fastfood, size: 40),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => _openOrderScreen(context),
                  child: Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                const SizedBox(height: 2),
                // Fixed: was '\UGX...' which isn't valid Dart (that
                // backslash starts an invalid escape sequence).
                Text(
                  'UGX ${food.price.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openOrderScreen(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'ORDER NOW',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      CartService.instance.addItem(food, 1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${food.name} added to cart')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'ADD TO CART',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}