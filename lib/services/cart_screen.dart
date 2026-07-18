import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/cart_service.dart';

// Shows everything currently in the cart, with a running total
// calculated from ALL items. Asks for the customer's phone number
// (so the vendor can reach them about the order), then sends the
// whole cart to Firestore as one order document.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  bool _isPlacingOrder = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ MAKE ORDER — validates the phone number, takes everything
  // currently in the cart, saves it as ONE order document in
  // Firestore (with the total calculated across all items), then
  // empties the cart.
  // ============================================================
  Future<void> _makeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to place an order')),
      );
      return;
    }

    final cartItems = CartService.instance.items;
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        // The vendor needs this to contact the customer about the order.
        'customerPhone': _phoneController.text.trim(),
        'items': cartItems
            .map((item) => {
                  'foodId': item.food.id,
                  'name': item.food.name,
                  'price': item.food.price,
                  'quantity': item.quantity,
                })
            .toList(),
        // Total calculated across every item in the cart, not just one.
        'total': CartService.instance.totalPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      CartService.instance.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed! The vendor will see it shortly.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
        backgroundColor: Colors.orange,
      ),
      // ListenableBuilder rebuilds this screen automatically whenever
      // an item is added, removed, or its quantity changes.
      body: ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final items = CartService.instance.items;

          if (items.isEmpty) {
            return const Center(
              child: Text('Your cart is empty', style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.food.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 64,
                                    height: 64,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.fastfood),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UGX ${item.total.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                onPressed: () => CartService.instance
                                    .updateQuantity(item.food.id, item.quantity - 1),
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.orange,
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                onPressed: () => CartService.instance
                                    .updateQuantity(item.food.id, item.quantity + 1),
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.orange,
                              ),

                              IconButton(
                                onPressed: () => CartService.instance.removeItem(item.food.id),
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom bar: phone number field, running total, Make Order
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 📞 Phone number — required so the vendor can
                        // reach the customer about this order.
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            hintText: 'e.g. 0770 123 456',
                            prefixIcon: Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.trim().length < 9) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            // Total calculated from every item in the cart.
                            Text(
                              'UGX ${CartService.instance.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPlacingOrder ? null : _makeOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                            child: _isPlacingOrder
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'MAKE ORDER',
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}