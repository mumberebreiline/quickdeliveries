class Category {

  final String id;

  final String name;

  final String image;

  Category({

    required this.id,

    required this.name,

    required this.image,

  });

  factory Category.fromFirestore(
      Map<String, dynamic> json,
      String id) {

    return Category(

      id: id,

      name: json['name'],

      image: json['image'],

    );
  }

}