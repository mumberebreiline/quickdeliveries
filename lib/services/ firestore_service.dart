class FirestoreService {

  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

}
Future<List<Category>> getCategories() async {

  final snapshot =
      await _db.collection("categories").get();

  return snapshot.docs.map((doc) {

    return Category.fromFirestore(

      doc.data(),

      doc.id,

    );

  }).toList();

}
Future<List<Meal>> getMealsByCategory(

String category,

) async {

  final snapshot = await _db

      .collection("meals")

      .where("category",

          isEqualTo: category)

      .get();

  return snapshot.docs.map((doc) {

    return Meal.fromFirestore(

      doc.data(),

      doc.id,

    );

  }).toList();

}