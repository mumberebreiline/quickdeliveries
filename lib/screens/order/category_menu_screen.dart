import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/routes.dart';
import '../../providers/order_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/product_card.dart';
import 'custom_request_sheet.dart';

/// Shows every dish in one category — reached by tapping that category's
/// photo tile ("salon") on the home screen. Ends with an option to request
/// something that isn't on the menu at all, so the customer is never
/// limited to exactly what's listed.
class CategoryMenuScreen extends StatelessWidget {
  final String categoryName;
  final String displayLabel;

  const CategoryMenuScreen({
    super.key,
    required this.categoryName,
    required this.displayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final items = SampleMenu.items
        .where((p) => p.category == categoryName)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(displayLabel),
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
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text("Don't see what you want? Ask for it"),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const CustomRequestSheet(),
                ),
              ),
            );
          }
          final product = items[index];
          return ProductCard(
            product: product,
            onAdd: () => orderProvider.addToCart(product),
          );
        },
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
