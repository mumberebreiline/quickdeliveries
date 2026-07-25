import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';

class MainCourseOrderDetailScreen extends StatefulWidget {
  final FoodItem food;

  const MainCourseOrderDetailScreen({super.key, required this.food});

  @override
  State<MainCourseOrderDetailScreen> createState() =>
      _MainCourseOrderDetailScreenState();
}

// Quantity, accompaniments, and the food picture/details are the only
// things this screen still handles directly. Delivery location,
// preferred time, phone number, and the actual Firestore write all
// happen on CartScreen now — both "ADD TO CART" and "MAKE ORDER" just
// get the selection into the cart correctly and let CartScreen do the
// rest, the same way every other category's detail screen already
// works. That's what keeps this logic written in exactly one place
// instead of two slightly-different copies of the same thing.
class _MainCourseOrderDetailScreenState
    extends State<MainCourseOrderDetailScreen> {
  int _quantity = 1;
  late final TextEditingController _quantityController;

  final List<Map<String, dynamic>> _selectedAccompaniments = [];

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: _quantity.toString());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQuantity) {
    if (newQuantity < 1) newQuantity = 1;
    setState(() {
      _quantity = newQuantity;
      _quantityController.text = _quantity.toString();
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
    });
  }

  void _increment() => _updateQuantity(_quantity + 1);
  void _decrement() => _updateQuantity(_quantity - 1);

  void _onTypedQuantity(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) _updateQuantity(parsed);
  }

  Stream<QuerySnapshot> _accompanimentsStream() {
    return FirebaseFirestore.instance
        .collection('Categories')
        .doc(widget.food.category)
        .collection('Accompaniment')
        .snapshots();
  }

  dynamic _pick(
    Map<String, dynamic> data,
    List<String> keys,
    dynamic fallback,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) return value;
    }
    return fallback;
  }

  double _readPrice(Map<String, dynamic> data) {
    final raw = _pick(data, ['Price', 'price'], 0);
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  bool _readAvailable(Map<String, dynamic> data) {
    final raw = _pick(data, ['Available', 'available'], true);
    if (raw is bool) return raw;
    return raw.toString().toLowerCase() == 'true';
  }

  bool _isSelected(String id) =>
      _selectedAccompaniments.any((item) => item['id'] == id);

  void _toggleAccompaniment(
    String id,
    String name,
    double price,
    bool checked,
  ) {
    setState(() {
      if (checked) {
        _selectedAccompaniments.add({'id': id, 'name': name, 'price': price});
      } else {
        _selectedAccompaniments.removeWhere((item) => item['id'] == id);
      }
    });
  }

  double get _accompanimentsTotal => _selectedAccompaniments.fold(
    0.0,
    (sum, item) => sum + (item['price'] as double),
  );

  double get _total => (widget.food.price * _quantity) + _accompanimentsTotal;

  /// Adds every selected accompaniment as its own cart line — each one
  /// becomes a real FoodItem so CartService and CartScreen don't need
  /// to know anything special about "accompaniments" as a concept, they
  /// just see more items. Previously this only happened inside the old
  /// direct-Firestore _makeOrder() — meaning using "ADD TO CART" instead
  /// silently dropped every accompaniment. Calling this from both
  /// buttons now fixes that too.
  void _addAccompanimentsToCart() {
    for (final accompaniment in _selectedAccompaniments) {
      CartService.instance.addItem(
        FoodItem(
          id: accompaniment['id'] as String,
          name: '${accompaniment['name']} (accompaniment)',
          price: accompaniment['price'] as double,
          imageUrl: '',
          category: 'Accompaniment',
        ),
        1,
      );
    }
  }

  void _addToCart() {
    CartService.instance.addItem(widget.food, _quantity);
    _addAccompanimentsToCart();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_quantity x ${widget.food.name} added to cart')),
    );
    Navigator.pop(context);
  }

  // MAKE ORDER — adds this dish and any selected accompaniments to the
  // cart, then goes straight to CartScreen to finish there (phone
  // number, delivery time, delivery location, and the Firestore write
  // all happen on that one screen — same pattern as every other
  // category now, not a separate copy of the same logic here).
  void _makeOrder() {
    CartService.instance.addItem(widget.food, _quantity);
    _addAccompanimentsToCart();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
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
      appBar: AppBar(
        title: const Text('Finalize Order'),
        backgroundColor: Colors.orange,
        actions: [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                widget.food.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.fastfood, size: 60),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              widget.food.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'UGX ${widget.food.price.toStringAsFixed(0)} each',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _decrement,
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 32,
                  color: Colors.orange,
                ),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _quantityController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: _onTypedQuantity,
                  ),
                ),
                IconButton(
                  onPressed: _increment,
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 32,
                  color: Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: const Text(
                    'Add Accompaniments',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  leading: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.orange,
                  ),
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: _accompanimentsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Could not load accompaniments: ${snapshot.error}',
                            ),
                          );
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final allDocs = snapshot.data?.docs ?? [];
                        final availableDocs = allDocs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _readAvailable(data);
                        }).toList();

                        if (availableDocs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No accompaniments available'),
                          );
                        }

                        return Column(
                          children: availableDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = _pick(data, [
                              'name',
                              'Name',
                            ], 'Unnamed').toString();
                            final price = _readPrice(data);

                            return CheckboxListTile(
                              value: _isSelected(doc.id),
                              title: Text(name),
                              subtitle: Text(
                                price > 0
                                    ? 'UGX ${price.toStringAsFixed(0)}'
                                    : 'Free',
                              ),
                              activeColor: Colors.orange,
                              onChanged: (checked) {
                                _toggleAccompaniment(
                                  doc.id,
                                  name,
                                  price,
                                  checked ?? false,
                                );
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            if (_selectedAccompaniments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedAccompaniments.map((item) {
                  return Chip(
                    label: Text(item['name'] as String),
                    backgroundColor: Colors.orange.shade50,
                    onDeleted: () => _toggleAccompaniment(
                      item['id'] as String,
                      item['name'] as String,
                      item['price'] as double,
                      false,
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Total: UGX ${_total.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _addToCart,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'ADD TO CART',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _makeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'MAKE ORDER',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
