class Meal {

  final String id;

  final String name;

  final String category;

  final String image;

  final String description;

  final double price;

  final bool available;

  Meal({

    required this.id,

    required this.name,

    required this.category,

    required this.image,

    required this.description,

    required this.price,

    required this.available,

  });

  factory Meal.fromFirestore(

      Map<String, dynamic> json,

      String id) {

    return Meal(

      id: id,

      name: json['name'],

      category: json['category'],

      image: json['image'],

      description: json['description'],

      price: (json['price'] as num).toDouble(),

      available: json['available'],

    );

  }

}