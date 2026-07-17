import 'package:flutter/foundation.dart';
import '../screens/order/food_item.dart';

// One line in the cart: a food item + how many of it were ordered.
class CartItem {
  final FoodItem food;
  int quantity;

  CartItem({required this.food, required this.quantity});

  double get total => food.price * quantity;
}

// A simple shared cart that any screen in the app can add to.
// This keeps the cart in memory only (it resets if the app closes).
// TODO: once you're ready, swap this for a real backend cart
// (e.g. saved to Firestore per user, or to your Django API).
class CartService extends ChangeNotifier {
  CartService._internal();
  static final CartService instance = CartService._internal();

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  void addItem(FoodItem food, int quantity) {
    final existingIndex = _items.indexWhere((item) => item.food.id == food.id);

    if (existingIndex >= 0) {
      // Already in the cart — just bump up the quantity
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(food: food, quantity: quantity));
    }
    notifyListeners();
  }

  double get totalPrice =>
      _items.fold(0.0, (sum, item) => sum + item.total);

  // Empties the cart — call this right after an order has been
  // saved to the database, so old items don't linger around.
  void clear() {
    _items.clear();
    notifyListeners();
  }
}