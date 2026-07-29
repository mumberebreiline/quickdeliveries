import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import 'order_detail_screen.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';

// ============================================================
// 📂 YOUR ACTUAL FIRESTORE STRUCTURE (from the console screenshot)
// ============================================================
//   Categories (collection)
//     └─ Breakfast (document)     ← has fields: Description, Image,
//                                    Name, Order, isActive
//          └─ Meals (subcollection)  ← the actual food items live here
// ============================================================

class BreakfastSelectionScreen extends StatelessWidget {
  const BreakfastSelectionScreen({super.key});

  // Points at: Categories/Breakfast/Meals
  Stream<QuerySnapshot> _mealsStream() {
    return FirebaseFirestore.instance
        .collection('Categories')
        .doc('Breakfast')
        .collection('Meals')
        .snapshots();
  }

  // Turns one "Meals" document into a FoodItem. Checks a capitalized
  // field name first (matching your Categories documents), then
  // falls back to a lowercase version, so this works either way.
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
      category: 'Breakfast',
    );
  }

  void _openCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Breakfast',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          // 🛒 Cart icon with a live badge showing how many items are
          // currently in the cart — same pattern as every other
          // selection screen. Updates automatically whenever the cart
          // changes anywhere in the app.
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
      // StreamBuilder listens to Firestore live — the screen updates
      // automatically the moment data changes, with no manual refresh.
      body: StreamBuilder<QuerySnapshot>(
        stream: _mealsStream(),
        builder: (context, snapshot) {
          // Something went wrong talking to Firestore (e.g. security
          // rules blocked the read, or there's no internet).
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load breakfast items:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Still waiting on the first response from Firestore.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // The connection worked, but the "Meals" subcollection under
          // the "Breakfast" document is empty — add documents there,
          // not to a top-level "foods" collection.
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No breakfast items found.\n\n'
                  'Add documents inside:\n'
                  'Categories → Breakfast → Meals',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // GridView.builder arranges the cards responsively.
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              // Picks as many columns as actually fit at ~180px
              // each, instead of a fixed count that only reacts
              // to portrait vs. landscape — this genuinely fills
              // a wide desktop window with more columns, rather
              // than stretching 2-3 cards across the whole
              // screen. Same pattern already used successfully
              // in menu_screen.dart's category grid.
              maxCrossAxisExtent: 180,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio:
                  0.68, // taller cards so there's room for buttons
            ),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final food = _mealFromDoc(docs[index].id, data);
              return _BreakfastCard(food: food);
            },
          );
        },
      ),
    );
  }
}

// One card in the grid: picture, name, price, an "Order Now" button
// that opens the final order screen, and a smaller "Add to Cart"
// button for a quick 1-item add without leaving this page.
class _BreakfastCard extends StatelessWidget {
  final FoodItem food;

  const _BreakfastCard({required this.food});

  void _openOrderScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OrderDetailScreen(food: food)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tapping the picture also opens the order screen.
          Expanded(
            child: GestureDetector(
              onTap: () => _openOrderScreen(context),
              child: Image.network(
                food.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                // Shows a placeholder if the picture link is broken
                // or hasn't been added yet.
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.free_breakfast,
                    size: 40,
                    color: Colors.brown,
                  ),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tapping the name also opens the order screen.
                GestureDetector(
                  onTap: () => _openOrderScreen(context),
                  child: Text(
                    food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'UGX ${food.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // 🟧 The "active order" button — takes the user straight
                // to the final order screen where they set the quantity.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openOrderScreen(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'ORDER NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Quick "Add to Cart" — adds 1 of this item straight
                // away, without opening the order screen.
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'ADD TO CART',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
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
