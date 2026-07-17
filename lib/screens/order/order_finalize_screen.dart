/*
import 'package:flutter/material.dart';
import '../home/meat_sauce_screen.dart';

class OrderFinalizeScreen extends StatelessWidget {
  final SauceItem selectedItem;

  const OrderFinalizeScreen({required this.selectedItem, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalize Order')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                selectedItem.imageUrl,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              selectedItem.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              selectedItem.price,
              style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${selectedItem.name} order added!')),
                );
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('Confirm Purchase', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
*/


import 'package:flutter/material.dart';
class OrderFinalizeScreen extends StatelessWidget {
  const OrderFinalizeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Vegetable Sauces Menu')));
}
