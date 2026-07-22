import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'food_item.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../models/location.dart';
import '../../utils/constants.dart';
import '../../widgets/location_status.dart';

// The STANDARD order screen — used by every category EXCEPT Main
// Courses (Breakfast, Drinks, Popular, Vegetarian all import this).
// No accompaniments dropdown here on purpose — only Main Courses has
// one, via main_course_order_detail_screen.dart.
//
// Opens when the user taps a food's picture, name, or "ORDER NOW"
// button on a selection screen. Lets them pick a quantity, then
// either add it to the cart or place the order immediately.
class OrderDetailScreen extends StatefulWidget {
  final FoodItem food;

  const OrderDetailScreen({super.key, required this.food});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  int _quantity = 1;
  late final TextEditingController _quantityController;
  bool _isPlacingOrder = false;

  // Delivery location + time — captured automatically, same pattern as
  // cart_screen.dart. This screen places an order directly (skipping
  // the cart), so it needs its own copy of this.
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
        // Just the raw captured position — no attempt to guess which
        // named building it's closest to. That guess was the actual
        // source of wrong labels before (e.g. "Near Freedom Square"
        // when the customer was really at Nkrumah Hall); the routing
        // math was always using the precise coordinates regardless, so
        // dropping the label doesn't lose any accuracy — it just stops
        // presenting an estimate as if it were a confirmed fact.
        _customerLocation = Location(
          id: 'customer_${DateTime.now().millisecondsSinceEpoch}',
          name: "Customer's location",
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
    if (newQuantity < 1) newQuantity = 1; // never let it drop below 1
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

  double get _total => widget.food.price * _quantity;

  void _addToCart() {
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
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        'items': [
          {
            'foodId': widget.food.id,
            'name': widget.food.name,
            'price': widget.food.price,
            'quantity': _quantity,
          },
        ],
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

            const SizedBox(height: 16),

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
