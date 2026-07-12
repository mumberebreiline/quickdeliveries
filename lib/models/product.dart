/// A single menu item the vendor sells (matooke, rolex, juice, etc).
class Product {
  final String id;
  final String name;
  final String description;
  final double price; // in UGX
  final String imageUrl;
  final String category; // e.g. "Main", "Drink", "Snack"
  final bool isAvailable;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.category = 'Main',
    this.isAvailable = true,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      price: (map['price'] as num).toDouble(),
      imageUrl: map['imageUrl'] as String? ?? '',
      category: map['category'] as String? ?? 'Main',
      isAvailable: map['isAvailable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isAvailable': isAvailable,
    };
  }
}
