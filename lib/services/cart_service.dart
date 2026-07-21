import 'package:flutter/foundation.dart';
import '../screens/order/food_item.dart';

// One line in the cart: a food item + how many of it were ordered +
// any accompaniments (sides/extras) chosen for it.
// Each accompaniment looks like: {"name": ..., "price": ...}
class CartItem {
  final FoodItem food;
  int quantity;
  final List<Map<String, dynamic>> accompaniments;

  CartItem({
    required this.food,
    required this.quantity,
    this.accompaniments = const [],
  });

  double get accompanimentsTotal =>
      accompaniments.fold(0.0, (sum, item) => sum + (item['price'] as num).toDouble());

  // Accompaniments are per-portion, so they scale with quantity too —
  // 2x "beef stew" with rice means 2 servings of rice as well.
  double get total => (food.price + accompanimentsTotal) * quantity;
}

// A simple shared cart that any screen in the app can add to, read
// from, or change. This keeps the cart in memory only (it resets if
// the app closes) — good enough while you're building things out.
// TODO: once you're ready, swap this for a real backend cart saved
// per-user, so it survives the app closing/reopening.
class CartService extends ChangeNotifier {
  CartService._internal();
  static final CartService instance = CartService._internal();

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  // Two cart lines only merge (bump quantity) if they're the SAME
  // food with the SAME accompaniments selected. A beef stew with rice
  // and a beef stew with no sides stay as two separate lines, since
  // they're different orders.
  bool _sameAccompaniments(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    final namesA = a.map((item) => item['name']).toSet();
    final namesB = b.map((item) => item['name']).toSet();
    return namesA.length == namesB.length && namesA.containsAll(namesB);
  }

  void addItem(
    FoodItem food,
    int quantity, {
    List<Map<String, dynamic>> accompaniments = const [],
  }) {
    final existingIndex = _items.indexWhere((item) =>
        item.food.id == food.id && _sameAccompaniments(item.accompaniments, accompaniments));

    if (existingIndex >= 0) {
      // Already in the cart with the same accompaniments — just bump quantity
      _items[existingIndex].quantity += quantity;
    } else {
      _items.add(CartItem(food: food, quantity: quantity, accompaniments: accompaniments));
    }
    notifyListeners();
  }

  // Changes a cart item's quantity directly (used by the +/- buttons
  // on the cart screen). Removes the item entirely if quantity hits 0.
  //
  // NOTE: takes the actual CartItem, not just a food ID — since the
  // same food can now appear as two separate cart lines with
  // different accompaniments, matching by ID alone could accidentally
  // change the wrong line.
  void updateQuantity(CartItem item, int quantity) {
    final index = _items.indexOf(item);
    if (index < 0) return;

    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index].quantity = quantity;
    }
    notifyListeners();
  }

  // Removes one specific cart line completely, regardless of quantity.
  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.total);

  // Empties the cart — call this right after an order has been
  // saved to the database, so old items don't linger around.
  void clear() {
    _items.clear();
    notifyListeners();
  }
}