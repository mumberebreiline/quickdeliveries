import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/cart_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import '../../../models/location.dart';
import '../../../utils/constants.dart';
import '../../../widgets/location_status.dart';

// Shows everything currently in the cart, with a running total
// calculated from ALL items. Asks for the customer's name, phone number,2
// and preferred time. Delivery location is captured automatically from
// device GPS — no picker, nothing to select — the vendor's route
// optimizer needs a real destination and time to plan deliveries at all,
// but "where" doesn't need to be asked when the phone already knows.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationService = LocationService();

  Location? _customerLocation;
  bool _isLocating = false;
  String? _locationError;

  TimeOfDay? _selectedTime;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    // Captured as soon as the screen opens, so it's ready by the time
    // they tap "Place order" — no extra wait, no picker to fill in.
    _captureLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _customerLocation = Location(
          id: 'customer_${DateTime.now().millisecondsSinceEpoch}',
          name: location.name,
          latitude: location.latitude,
          longitude: location.longitude,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationError = e.toString();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  
  //MAKE ORDER — validates the phone number and delivery details,
  // takes everything currently in the cart, saves it as ONE order
  // document in Firestore (with the total calculated across all
  // items), then empties the cart.
  Future<void> _makeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_customerLocation == null) {
      // Try once more before giving up — covers the case where GPS
      // wasn't ready yet when the screen first opened.
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

    final cartItems = CartService.instance.items;
    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your cart is empty')));
      return;
    }

    setState(() => _isPlacingOrder = true);

    // If the picked time already passed today, assume tomorrow —
    // matches how the vendor's route optimizer buckets by time-of-day.
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
        'customerName': _nameController.text.trim(),
        // The vendor needs this to contact the customer about the order.
        'customerPhone': _phoneController.text.trim(),
        'items': cartItems
            .map(
              (item) => {
                'foodId': item.food.id,
                'name': item.food.name,
                'price': item.food.price,
                'quantity': item.quantity,
              },
            )
            .toList(),
        // Total calculated across every item in the cart, not just one.
        'total': CartService.instance.totalPrice,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        // These two are what the vendor's route optimizer actually needs —
        // without them there's no destination or timing to plan around.
        'deliveryLocation': _customerLocation!.toMap(),
        'preferredTime': Timestamp.fromDate(preferredTime),
      });

      CartService.instance.clear();

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
              child: Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
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
                                    Text(
                                      item.food.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'UGX ${item.total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                onPressed: () =>
                                    CartService.instance.updateQuantity(
                                      item.food.id,
                                      item.quantity - 1,
                                    ),
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.orange,
                              ),
                              Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () =>
                                    CartService.instance.updateQuantity(
                                      item.food.id,
                                      item.quantity + 1,
                                    ),
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.orange,
                              ),

                              IconButton(
                                onPressed: () => CartService.instance
                                    .removeItem(item.food.id),
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
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Your name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Phone number — required so the vendor can
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

                        //  Delivery location — captured automatically
                        // from device GPS, nothing to pick. This is what
                        // the vendor's route optimizer plans stops
                        // around.
                        LocationStatus(
                          isLocating: _isLocating,
                          location: _customerLocation,
                          error: _locationError,
                          onRetry: _captureLocation,
                        ),
                        const SizedBox(height: 12),

                        //  Preferred time — the other half of what the
                        // route optimizer needs to batch and sequence
                        // deliveries.
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
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            // Total calculated from every item in the cart.
                            Text(
                              'UGX ${CartService.instance.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isPlacingOrder
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'MAKE ORDER',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
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