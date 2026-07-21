import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/cart_service.dart';

// ============================================================
// 📍 COMMON LOCATIONS — EDIT THIS LIST
// ============================================================
// I don't have the exact list of common locations from your earlier
// code in this conversation, so these are placeholders. Replace them
// with your real ones (campus buildings, hostels, landmarks, etc).
// ============================================================
const List<String> _commonLocations = [
  'Main Gate',
  'Library',
  'Hostel A',
  'Hostel B',
  'Cafeteria',
  'Sports Complex',
];

// How the customer is telling us where to deliver to. Room details
// are now a separate OPTIONAL add-on below this, not a third choice.
enum _DeliveryLocationType { current, common }

// Shows everything in the cart, including accompaniments, with a
// running total. Before placing the order, the customer:
//   - optionally gives their name
//   - must give a phone number
//   - must pick a delivery time at least 30 minutes from now
//   - must specify a delivery location: their live GPS position, a
//     common location from a dropdown, or a room number + details
//
// This is the ONLY screen in the app that writes an order to
// Firestore — every "Make Order" button elsewhere routes through
// here first, so order submission lives in exactly one place.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController(); // optional
  final _phoneController = TextEditingController(); // required
  final _roomNumberController = TextEditingController();
  final _roomDetailsController = TextEditingController();

  DateTime? _selectedDeliveryTime;

  _DeliveryLocationType _locationType = _DeliveryLocationType.common;
  String? _selectedCommonLocation;
  Position? _currentPosition;
  bool _isCapturingLocation = false;

  bool _isPlacingOrder = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _roomNumberController.dispose();
    _roomDetailsController.dispose();
    super.dispose();
  }

  // ============================================================
  // ⏰ DELIVERY TIME — must be at least 30 minutes from right now
  // ============================================================
  Future<void> _pickDeliveryTime() async {
    final now = DateTime.now();
    final earliestAllowed = now.add(const Duration(minutes: 30));

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(earliestAllowed),
      helpText: 'Choose a delivery time (at least 30 min from now)',
    );
    if (pickedTime == null) return;

    var candidate = DateTime(now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);

    // If the picked time is earlier than 30 minutes from now, assume
    // they meant tomorrow (e.g. it's 11:50pm and they picked 12:10am).
    // TODO: if you want same-day-only delivery, replace this with a
    // validation error instead of rolling over to the next day.
    if (candidate.isBefore(earliestAllowed)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    setState(() => _selectedDeliveryTime = candidate);
  }

  bool _isDeliveryTimeStillValid() {
    if (_selectedDeliveryTime == null) return false;
    final earliestAllowed = DateTime.now().add(const Duration(minutes: 30));
    return !_selectedDeliveryTime!.isBefore(earliestAllowed);
  }

  String _formatDeliveryTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final today = DateTime.now();
    final isToday = time.year == today.year && time.month == today.month && time.day == today.day;
    return '${isToday ? "Today" : "Tomorrow"} at $hour:$minute $period';
  }

  // ============================================================
  // 📍 CURRENT LOCATION — asks for permission, then captures GPS
  // ============================================================
  Future<void> _captureCurrentLocation() async {
    setState(() => _isCapturingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are turned off. Please enable them and try again.';
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission was denied.';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission is permanently denied. Enable it in your device settings.';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() => _currentPosition = position);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _isCapturingLocation = false);
    }
  }

  // Checks that whichever primary location method is selected has
  // actually been filled in. Room details are optional, so they're
  // not checked here.
  bool _validateLocation() {
    switch (_locationType) {
      case _DeliveryLocationType.current:
        if (_currentPosition == null) {
          _showError('Please capture your current location');
          return false;
        }
        return true;
      case _DeliveryLocationType.common:
        if (_selectedCommonLocation == null) {
          _showError('Please choose a common location');
          return false;
        }
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Turns the chosen primary location (current GPS or a common
  // location) into a plain map, ready to save to Firestore — and
  // attaches room details on top if the customer filled them in,
  // regardless of which primary option was picked.
  Map<String, dynamic> _buildDeliveryLocationData() {
    final Map<String, dynamic> data;
    switch (_locationType) {
      case _DeliveryLocationType.current:
        data = {
          'type': 'current_location',
          'latitude': _currentPosition!.latitude,
          'longitude': _currentPosition!.longitude,
        };
        break;
      case _DeliveryLocationType.common:
        data = {
          'type': 'common_location',
          'locationName': _selectedCommonLocation,
        };
        break;
    }

    // Room details are optional and can accompany EITHER primary
    // location choice — only attach them if the customer typed a room number.
    if (_roomNumberController.text.trim().isNotEmpty) {
      data['room'] = {
        'roomNumber': _roomNumberController.text.trim(),
        'details': _roomDetailsController.text.trim(),
      };
    }

    return data;
  }

  // ============================================================
  // ✅ MAKE ORDER
  // ============================================================
  Future<void> _makeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    // Delivery time is optional — only validate it if the customer
    // actually picked one.
    if (_selectedDeliveryTime != null && !_isDeliveryTimeStillValid()) {
      _showError('That delivery time has passed — please pick a new one');
      return;
    }
    if (!_validateLocation()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please log in to place an order');
      return;
    }

    final cartItems = CartService.instance.items;
    if (cartItems.isEmpty) {
      _showError('Your cart is empty');
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user.uid,
        // Optional — may be an empty string if the customer skipped it.
        'customerName': _nameController.text.trim(),
        'customerPhone': _phoneController.text.trim(),
        'deliveryTime':
            _selectedDeliveryTime != null ? Timestamp.fromDate(_selectedDeliveryTime!) : null,
        'deliveryLocation': _buildDeliveryLocationData(),
        'items': cartItems
            .map((item) => {
                  'foodId': item.food.id,
                  'name': item.food.name,
                  'price': item.food.price,
                  'quantity': item.quantity,
                  'accompaniments': item.accompaniments,
                })
            .toList(),
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
      _showError('Could not place order: $e');
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---------------- Cart items ----------------
                  ...items.map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                    if (item.accompaniments.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '+ ${item.accompaniments.map((a) => a['name'] as String).join(', ')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'UGX ${item.total.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            CartService.instance.updateQuantity(item, item.quantity - 1),
                                        icon: const Icon(Icons.remove_circle_outline),
                                        color: Colors.orange,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      IconButton(
                                        onPressed: () =>
                                            CartService.instance.updateQuantity(item, item.quantity + 1),
                                        icon: const Icon(Icons.add_circle_outline),
                                        color: Colors.orange,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    onPressed: () => CartService.instance.removeItem(item),
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.grey,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),

                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),

                  // ---------------- Customer details ----------------
                  const Text('Your details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

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
                      if (value == null || value.trim().isEmpty) return 'Please enter your phone number';
                      if (value.trim().length < 9) return 'Enter a valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ---------------- Delivery time ----------------
                  const Text('Delivery time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Optional — if chosen, must be at least 30 minutes from now',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDeliveryTime,
                    icon: const Icon(Icons.access_time, color: Colors.orange),
                    label: Text(
                      _selectedDeliveryTime == null
                          ? 'Choose a delivery time (optional)'
                          : _formatDeliveryTime(_selectedDeliveryTime!),
                      style: const TextStyle(color: Colors.orange),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------------- Delivery location ----------------
                  const Text('Delivery location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  RadioListTile<_DeliveryLocationType>(
                    contentPadding: EdgeInsets.zero,
                    value: _DeliveryLocationType.current,
                    groupValue: _locationType,
                    activeColor: Colors.orange,
                    title: const Text('Use my current location'),
                    onChanged: (value) => setState(() => _locationType = value!),
                  ),
                  if (_locationType == _DeliveryLocationType.current) ...[
                    if (_currentPosition == null)
                      OutlinedButton.icon(
                        onPressed: _isCapturingLocation ? null : _captureCurrentLocation,
                        icon: _isCapturingLocation
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                              )
                            : const Icon(Icons.my_location, color: Colors.orange),
                        label: Text(_isCapturingLocation ? 'Getting location...' : 'Capture my location'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          foregroundColor: Colors.orange,
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Location captured (${_currentPosition!.latitude.toStringAsFixed(5)}, '
                              '${_currentPosition!.longitude.toStringAsFixed(5)})',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _captureCurrentLocation,
                            child: const Text('Refresh'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                  ],

                  RadioListTile<_DeliveryLocationType>(
                    contentPadding: EdgeInsets.zero,
                    value: _DeliveryLocationType.common,
                    groupValue: _locationType,
                    activeColor: Colors.orange,
                    title: const Text('Choose a common location'),
                    onChanged: (value) => setState(() => _locationType = value!),
                  ),
                  if (_locationType == _DeliveryLocationType.common) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCommonLocation,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text('Select a location'),
                      items: _commonLocations
                          .map((location) => DropdownMenuItem(value: location, child: Text(location)))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedCommonLocation = value),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 12),
                  const Text(
                    'Room / additional details (optional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add this alongside either location above — e.g. a room number '
                    'within a hostel, or a landmark near your current location.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _roomNumberController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Room / house number (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _roomDetailsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Additional details (floor, landmark, etc.)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text(
                        'UGX ${CartService.instance.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton(
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}