import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import 'order_detail_screen.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';

// ============================================================
// 📂 YOUR ACTUAL FIRESTORE STRUCTURE
// ============================================================
//   Categories (collection)
//     └─ Drinks (document)
//          └─ Meals (subcollection)  ← the actual drink items live here
// ============================================================

class DrinksSelectionScreen extends StatelessWidget {
  const DrinksSelectionScreen({super.key});

  Stream<QuerySnapshot> _mealsStream() {
    return FirebaseFirestore.instance
        .collection('Categories')
        .doc('Drinks')
        .collection('Meals')
        .snapshots();
  }

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
      // Fixed: this was hardcoded to 'Breakfast', which meant every
      // drink was silently mistagged with the wrong category.
      category: 'Drinks',
    );
  }

  void _openCart(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final crossAxisCount = orientation == Orientation.landscape ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Drinks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          // 🛒 Cart icon with a live badge — same pattern as the other
          // selection screens.
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
                  'Could not load drinks:\n${snapshot.error}',
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
                  'No drinks found.\n\n'
                  'Add documents inside:\n'
                  'Categories → Drinks → Meals',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount, // 👈 2 in portrait, 3 in landscape
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.68,
            ),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final food = _mealFromDoc(docs[index].id, data);
              return _DrinkCard(food: food);
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
class _DrinkCard extends StatelessWidget {
  final FoodItem food;

  const _DrinkCard({required this.food});

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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  child: const Icon(Icons.local_drink, size: 40, color: Colors.blueGrey),
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
                const SizedBox(height: 4),
                // Fixed: was 'UGX${price.toStringAsFixed(2)}' — no
                // space, and 2 decimals where the rest of the app uses 0.
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