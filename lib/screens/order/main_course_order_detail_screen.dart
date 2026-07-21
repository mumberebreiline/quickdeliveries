import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'food_item.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../models/location.dart';
import '../../utils/constants.dart';
import '../../widgets/location_status.dart';

// ============================================================
// 🍛 MAIN COURSES ONLY
// ============================================================
// This is a SEPARATE screen from order_detail_screen.dart, used
// ONLY when opening an item from the "main courses" category —
// wire this up from food_selection_screen.dart specifically.
//
// Why separate: your Firestore data shows accompaniments only make
// sense for main courses right now (e.g. Categories/main courses/
// Accompaniment/meal001 → "white rice"). Other categories technically
// have an Accompaniment subcollection too (like Breakfast's Twinings
// tea), but per your instructions only Main Courses should show this
// dropdown — every other category uses the plain order_detail_screen.dart
// instead, which has no dropdown at all.
//
// Your accompaniment documents aren't totally consistent — some have
// a Price and Available flag (Breakfast's Meal_007), others only have
// a "name" (main courses' meal001, e.g. "white rice" — a free side).
// This screen handles both: missing Price defaults to 0 (free),
// missing Available defaults to true (shown).
// ============================================================
class MainCourseOrderDetailScreen extends StatefulWidget {
  final FoodItem food;

  const MainCourseOrderDetailScreen({super.key, required this.food});

  @override
  State<MainCourseOrderDetailScreen> createState() =>
      _MainCourseOrderDetailScreenState();
}

class _MainCourseOrderDetailScreenState
    extends State<MainCourseOrderDetailScreen> {
  int _quantity = 1;
  late final TextEditingController _quantityController;

  // Each entry looks like: {"id": ..., "name": ..., "price": ...}
  final List<Map<String, dynamic>> _selectedAccompaniments = [];

  bool _isPlacingOrder = false;

  // Delivery location + time — same auto-capture pattern as
  // cart_screen.dart. This screen places an order directly (skipping
  // the cart), so it needs its own copy of this, not a shared cart.
  final _locationService = LocationService();
  Location? _customerLocation;
  bool _isLocating = false;
  String? _locationError;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: _quantity.toString());
    _captureLocation();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    final location = await _locationService.getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      if (location == null) {
        _locationError =
            'Could not detect your location — check that location access is '
            'allowed for this app, then try again.';
      } else {
        _customerLocation = Location(
          id: 'customer_${DateTime.now().millisecondsSinceEpoch}',
          name: CampusLocations.describeNearestBuilding(
            location.latitude,
            location.longitude,
          ),
          latitude: location.latitude,
          longitude: location.longitude,
        );
      }
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
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

  // Points at: Categories/main courses/Accompaniment
  Stream<QuerySnapshot> _accompanimentsStream() {
    return FirebaseFirestore.instance
        .collection('Categories')
        .doc(widget.food.category) // will be "main courses"
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

  // Defaults to 0 — your "white rice" style accompaniments have no
  // Price field at all, meaning they're free add-ons.
  double _readPrice(Map<String, dynamic> data) {
    final raw = _pick(data, ['Price', 'price'], 0);
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  // Defaults to true — accompaniments with no Available field (like
  // "white rice") should still show up as selectable.
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

  void _addToCart() {
    // TODO: extend CartService.addItem(...) to also accept the
    // accompaniments list if you want them to travel into the cart.
    CartService.instance.addItem(widget.food, _quantity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_quantity x ${widget.food.name} added to cart')),
    );
    Navigator.pop(context);
  }

  Future<void> _makeOrder() async {
    // main.dart already ensures someone's signed in (anonymously, if
    // they never logged in) before this screen is even reachable — this
    // is just a safety net in case that somehow didn't happen.
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await AuthService().ensureSignedIn();
      user = FirebaseAuth.instance.currentUser;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start a session — check your connection and try again',
          ),
        ),
      );
      return;
    }

    if (_customerLocation == null) {
      await _captureLocation();
    }
    if (_customerLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not detect your location — please check location '
            'permissions and try again',
          ),
        ),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a preferred time')),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final now = DateTime.now();
    var preferredTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    if (preferredTime.isBefore(now)) {
      preferredTime = preferredTime.add(const Duration(days: 1));
    }

    try {
      // Each accompaniment becomes its OWN entry in the items array,
      // instead of being nested inside the main dish's item — the
      // vendor's FoodOrder model only ever reads foodId/name/price/
      // quantity from each entry in this list, so anything nested one
      // level deeper (like the old 'accompaniments' sub-field) was
      // silently invisible on her screen even though it saved fine.
      final items = [
        {
          'foodId': widget.food.id,
          'name': widget.food.name,
          'price': widget.food.price,
          'quantity': _quantity,
        },
        for (final accompaniment in _selectedAccompaniments)
          {
            'foodId': accompaniment['id'],
            'name': '${accompaniment['name']} (accompaniment)',
            'price': accompaniment['price'],
            'quantity': 1,
          },
      ];

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'items': items,
        'total': _total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveryLocation': _customerLocation!.toMap(),
        'preferredTime': Timestamp.fromDate(preferredTime),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order placed! The vendor will see it shortly.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not place order: $e')));
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
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

            // 🥗 "Add Accompaniments" dropdown
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
                              // Shows "Free" instead of "UGX 0" for
                              // accompaniments with no price, like white rice.
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

            const SizedBox(height: 20),
            LocationStatus(
              isLocating: _isLocating,
              location: _customerLocation,
              error: _locationError,
              onRetry: _captureLocation,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Preferred time',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedTime == null
                      ? 'Choose a time'
                      : _selectedTime!.format(context),
                ),
              ),
            ),

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
                    onPressed: _isPlacingOrder ? null : _addToCart,
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
                    onPressed: _isPlacingOrder ? null : _makeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isPlacingOrder
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
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
