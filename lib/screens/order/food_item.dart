// This class represents ONE food item pulled out of Firestore.
// Think of it as a neat little box that holds a food's name,
// price, picture link, and category, so the rest of the app
// doesn't have to deal with raw Firestore data everywhere.
class FoodItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;

  FoodItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
  });

  // Turns a Firestore document into a FoodItem.
  // "id" is the document's own ID, "data" is its field/value map.
  factory FoodItem.fromFirestore(String id, Map<String, dynamic> data) {
    return FoodItem(
      id: id,
      name: data['name'] as String? ?? 'Unnamed',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'] as String? ?? '',
      category: data['category'] as String? ?? '',
    );
  }
}
