import 'package:flutter/material.dart';

class FoodCard extends StatelessWidget {
  final String name;
  final int price;

  const FoodCard({super.key, required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const CircleAvatar(radius: 28, child: Icon(Icons.fastfood)),
        title: Text(name),
        subtitle: Text("UGX $price"),
        trailing: ElevatedButton(onPressed: () {}, child: const Text("Add")),
      ),
    );
  }
}
