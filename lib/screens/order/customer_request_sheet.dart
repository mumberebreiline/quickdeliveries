import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/product.dart';
import '../../providers/order_provider.dart';
import '../../widgets/custom_button.dart';

/// Lets a customer describe a dish that isn't on the menu at all. It's
/// added to their cart as a Product with price 0 — the vendor sees it on
/// Incoming Orders and quotes a real price there before accepting.
class CustomRequestSheet extends StatefulWidget {
  const CustomRequestSheet({super.key});

  @override
  State<CustomRequestSheet> createState() => _CustomRequestSheetState();
}

class _CustomRequestSheetState extends State<CustomRequestSheet> {
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;

    final suggestedPrice = double.tryParse(_priceController.text.trim()) ?? 0;

    final customProduct = Product(
      id: 'custom_${const Uuid().v4()}',
      name: 'Custom request: $description',
      description: 'Not on the standard menu — vendor to confirm & quote.',
      price: suggestedPrice,
      imageUrl: '',
      category: 'Custom',
    );

    context.read<OrderProvider>().addToCart(customProduct);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask for something else',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Describe what you'd like. The vendor will confirm it and quote "
            "a final price before it's accepted.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What do you want?',
              hintText: 'e.g. Chapati with beef stew, extra spicy',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "What you'd pay (optional, UGX)",
            ),
          ),
          const SizedBox(height: 20),
          CustomButton(
            label: 'Add to cart',
            fullWidth: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
