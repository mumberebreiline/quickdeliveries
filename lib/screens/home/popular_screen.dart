/*
import 'package:flutter/material.dart';

class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});

  // 👇 This is the list of popular meals shown on this page.
  // Want to add your own meal? Just copy one of the lines below
  // and change the "name" and "price".
  final List<Map<String, String>> meals = const [
    {"name": "Ugandan Rolex", "price": "\$2.50"},
    {"name": "Jollof Rice", "price": "\$4.50"},
    {"name": "Beef Burger & Chips", "price": "\$6.00"},
    {"name": "Chicken Curry", "price": "\$6.50"},
    {"name": "Grilled Fish & Rice", "price": "\$7.50"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Popular"),
        backgroundColor: Colors.orange,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: meals.length,
        itemBuilder: (context, index) {
          final meal = meals[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const Icon(Icons.star, color: Colors.orange),
              title: Text(
                meal["name"]!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Text(
                meal["price"]!,
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                // TODO: hook this up to your ordering/cart logic
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${meal["name"]} added to order")),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
*/

import 'package:flutter/material.dart';

class PopularScreen extends StatelessWidget {
  const PopularScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Popular Menu')));
}
