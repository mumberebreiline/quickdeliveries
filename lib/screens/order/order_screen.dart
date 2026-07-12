import 'package:flutter/material.dart';
import '../../models/product.dart';

class OrderScreen extends StatefulWidget {
  // This is how the screen "receives the selected product" (Step 1 in
  // your plan). Whoever opens this screen must supply a product —
  // `required` means Dart won't compile if someone forgets to pass one.
  final Product product;

  const OrderScreen({super.key, required this.product});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  // --- Step 2: quantity state ---
  // This lives in State (not the widget) because it changes over time
  // as the user taps + / -. setState() below is what redraws the screen
  // with the new number.
  int _quantity = 1;

  // --- Step 3: delivery time state ---
  // The currently selected dropdown value. Starts on "Now".
  String _deliveryTime = 'Now';
  final List<String> _deliveryOptions = [
    'Now',
    '30 Minutes',
    '1 Hour',
    '2 Hours',
    '3 Hours',
  ];

  // --- Step 4 (later): GPS location ---
  // Left as nulls for now — Step 4 in your plan is "add GPS using
  // geolocator", which we're deliberately NOT doing yet, per the
  // "build it in layers" advice. We'll fill these in once the UI works.
  double? _latitude;
  double? _longitude;

  void _increaseQuantity() {
    setState(() => _quantity++);
  }

  void _decreaseQuantity() {
    // Never let quantity go below 1 — doesn't make sense to order zero.
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  // Total price recalculates automatically any time this getter is
  // read, because build() re-reads it after every setState().
  int get _totalPrice => widget.product.price * _quantity;

  // --- Step 5 (later): send to backend ---
  // For now this just shows what WOULD be sent, using a SnackBar, so you
  // can see the payload working before Django is wired up.
  void _placeOrder() {
    // TODO(backend-dev): replace this with a real POST request once the
    // endpoint exists, e.g. using the `http` or `dio` package:
    //
    // final response = await http.post(
    //   Uri.parse('https://your-api.com/orders/'),
    //   body: jsonEncode(orderPayload),
    //   headers: {'Content-Type': 'application/json'},
    // );

    final orderPayload = {
      'product_title': widget.product.title,
      'quantity': _quantity,
      'delivery_time': _deliveryTime,
      'latitude': _latitude,   // still null until Step 4 is built
      'longitude': _longitude, // still null until Step 4 is built
      'total_price': _totalPrice,
    };

    // Just for now — proves the data is correct before there's a backend
    // to actually receive it.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order ready to send: $orderPayload')),
    );

    // Once the backend confirms the order, you'd navigate onward, e.g.:
    // Navigator.pushNamed(context, AppRoutes.orderStatus);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        title: Text(
          product.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name + unit price, straight from the model we
            // received in the constructor.
            Text(
              product.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Price: UGX ${product.price}',
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // --- Quantity selector (Step 2) ---
            const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _decreaseQuantity,
                ),
                Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _increaseQuantity,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Total price, recalculated live ---
            Text(
              'Total',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'UGX $_totalPrice',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 24),

            // --- Delivery time dropdown (Step 3) ---
            const Text('Delivery Time', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _deliveryTime,
              isExpanded: true,
              items: _deliveryOptions
                  .map((option) => DropdownMenuItem(value: option, child: Text(option)))
                  .toList(),
              onChanged: (value) {
                // value can technically be null (Flutter's API allows it),
                // so we guard against that before updating state.
                if (value != null) {
                  setState(() => _deliveryTime = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // --- Delivery address (Step 4, placeholder for now) ---
            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: const [
                Icon(Icons.location_on, color: Color(0xFF1B5E20)),
                SizedBox(width: 6),
                // This text is a placeholder. Once geolocator is added,
                // this will show the real detected address/coordinates
                // instead of this fixed string.
                Text('Current Location (will be detected)'),
              ],
            ),

            const Spacer(),

            // --- Place Order button (Step 5) ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _placeOrder,
                child: const Text('Place Order', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}