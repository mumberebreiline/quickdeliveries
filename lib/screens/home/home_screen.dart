import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/routes.dart';
import '../../providers/order_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/product_card.dart';

/// The customer's menu screen — the same dishes and green/orange styling
/// from the original mock-up, now backed by the Product model and cart in
/// OrderProvider instead of a hardcoded list of Maps.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu, color: Colors.white),
        title: const Text('Our Menu'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: orderProvider.cartItemCount == 0
                    ? null
                    : () => Navigator.pushNamed(context, AppRoutes.order),
              ),
              if (orderProvider.cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${orderProvider.cartItemCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Text(
              'Enjoy our delicious local dishes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: SampleMenu.items.length,
              itemBuilder: (context, index) {
                final product = SampleMenu.items[index];
                return ProductCard(
                  product: product,
                  onAdd: () => orderProvider.addToCart(product),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: orderProvider.cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.order),
              label: Text('View Cart (${orderProvider.cartItemCount})'),
              icon: const Icon(Icons.shopping_cart_checkout),
            )
          : null,
    );
  }
}
