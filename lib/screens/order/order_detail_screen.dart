import 'package:flutter/material.dart';
import 'food_item.dart';
import '../../services/cart_service.dart';
import 'cart_screen.dart';

// The STANDARD order screen — used by every category EXCEPT Main
// Courses (Breakfast, Drinks, Popular, Vegetarian all import this).
// No accompaniments dropdown here on purpose — only Main Courses has
// one, via main_course_order_detail_screen.dart.
//
// Opens when the user taps a food's picture, name, or "ORDER NOW"
// button on a selection screen. Lets them pick a quantity, then
// either add it to the cart or make an order — both routes go
// through the cart, which is the ONLY screen that actually writes
// an order to Firestore (delivery location, time, and phone number
// are all collected there, not here).
class OrderDetailScreen extends StatefulWidget {
  final FoodItem food;

  const OrderDetailScreen({super.key, required this.food});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  int _quantity = 1;
  late final TextEditingController _quantityController;

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

  // MAKE ORDER — adds this item to the cart, then takes the customer
  // straight to CartScreen to finish there (phone number, delivery
  // time, delivery location, and the actual Firestore write all
  // happen on that screen — kept in one place instead of duplicated
  // across every category's detail screen).
  void _makeOrder() {
    CartService.instance.addItem(widget.food, _quantity);
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
    final orientation = MediaQuery.of(context).orientation;

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
      // Portrait keeps the original stacked layout. Landscape switches
      // to picture-on-the-left, details-on-the-right so the wider
      // screen is actually used instead of just centering a narrow
      // column with empty space on both sides.
      body: orientation == Orientation.landscape
          ? _buildLandscapeLayout(context)
          : _buildPortraitLayout(context),
    );
  }

  // ============================================================
  // 📱 PORTRAIT — unchanged from before: everything stacked in one
  // scrollable column.
  // ============================================================
  Widget _buildPortraitLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildFoodImage(height: 200),
          const SizedBox(height: 20),
          _buildNameAndPrice(),
          const SizedBox(height: 24),
          _buildQuantityStepper(),
          const SizedBox(height: 24),
          _buildTotal(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ============================================================
  // 🖥️ LANDSCAPE — picture fills the left side, everything else
  // (name, price, quantity, total, buttons) scrolls on the right.
  // ============================================================
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildFoodImage(height: double.infinity),
          ),
        ),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNameAndPrice(alignLeft: true),
                const SizedBox(height: 20),
                _buildQuantityStepper(),
                const SizedBox(height: 20),
                _buildTotal(alignLeft: true),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- Shared pieces (used by both layouts) ----------------

  Widget _buildFoodImage({required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        widget.food.imageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: height == double.infinity ? null : height,
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const Icon(Icons.fastfood, size: 60),
        ),
      ),
    );
  }

  Widget _buildNameAndPrice({bool alignLeft = false}) {
    return Column(
      crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          widget.food.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'UGX ${widget.food.price.toStringAsFixed(0)} each',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQuantityStepper() {
    return Row(
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildTotal({bool alignLeft = false}) {
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: Text(
        'Total: UGX ${_total.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _addToCart,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text(
              'ADD TO CART',
              style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text(
              'MAKE ORDER',
              style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}