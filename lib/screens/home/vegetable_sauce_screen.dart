
import 'package:flutter/material.dart';
class VegetableSauceScreen extends StatelessWidget {
  const VegetableSauceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Vegetable Sauces Menu')));
}


//UNCOMMENT FOR MORE WORK
/*
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../order/sauce_item.dart'; // Using the global shared model
import '../order/order_finalize_screen.dart'; // Adjust if path differs

class VegetableSauceScreen extends StatefulWidget {
  const VegetableSauceScreen({super.key});

  @override
  State<VegetableSauceScreen> createState() => _VegetableSauceScreenState();
}

class _VegetableSauceScreenState extends State<VegetableSauceScreen> {
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
        title: const Text('Vegetable Sauces'),
        centerTitle: true,
      ),
      // Real-time stream pointing to your vegetable_sauces collection
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vegetable_sauces').snapshots(),
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
            return const Center(child: Text('No vegetable sauces available right now.'));
          }

          // 4. Map snapshots using our unified model
          final List<SauceItem> vegSauces = snapshot.data!.docs
              .map((doc) => SauceItem.fromFirestore(doc))
              .toList();

          // 5. Render 2-column layout grid
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: vegSauces.length,
            itemBuilder: (context, index) {
              final item = vegSauces[index];
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
                      // Sauce Image
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            item.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      // Sauce Details
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
      // Floating cart indicator in the bottom right corner
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