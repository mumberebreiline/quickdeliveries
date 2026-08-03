import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../screens/order/cart_screen.dart';

/// A single CartButton used across the app. It exposes a static GlobalKey
/// (cartKey) that other code can use as the fly-to-cart target.
class CartButton extends StatelessWidget {
  static final GlobalKey cartKey = GlobalKey();

  const CartButton({super.key});

  void _openCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.itemCount;
        return IconButton(
          key: cartKey,
          onPressed: () => _openCart(context),
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            child: const Icon(Icons.shopping_basket),
          ),
        );
      },
    );
  }
}
