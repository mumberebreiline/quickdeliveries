import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category.dart';
import '../models/meal.dart';

/// All Firestore reads/writes for the menu live here — this is what makes
/// the menu editable from the database instead of hardcoded per screen.
/// Two collections: `categories` (name + cover image) and `meals` (each
/// tagged with a `category` name matching one of those categories).
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Category>> streamCategories() {
    return _db
        .collection('categories')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Category.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Meal>> streamMealsByCategory(String category) {
    return _db
        .collection('meals')
        .where('category', isEqualTo: category)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Meal.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// The most-opened meals overall — the real "Popular" section, driven by
  /// actual access counts rather than a hand-picked list.
  Stream<List<Meal>> streamPopularMeals({int limit = 6}) {
    return _db
        .collection('meals')
        .orderBy('accessCount', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Meal.fromFirestore(doc.data(), doc.id))
              .toList(),
        );
  }

  /// Call this whenever someone opens a meal's details — that's what
  /// "accessed" means for the Popular ranking.
  Future<void> recordMealAccess(String mealId) {
    return _db.collection('meals').doc(mealId).update({
      'accessCount': FieldValue.increment(1),
    });
  }

  /// Runs once per app start. If the `categories` collection is completely
  /// empty (a fresh Firestore project with nothing added yet), this seeds
  /// a starter menu so the app isn't blank on first run — it never
  /// overwrites anything that's already there.
  Future<void> seedDefaultDataIfEmpty() async {
    final existingCategories = await _db
        .collection('categories')
        .limit(1)
        .get();
    if (existingCategories.docs.isNotEmpty) return;

    final categories = [
      {'name': 'Breakfast', 'image': 'assets/images/Breakfast/rolex1.jpg'},
      {'name': 'Lunch', 'image': 'assets/images/Lunch/Beef-Stew.jpg'},
      {'name': 'Drinks', 'image': 'assets/images/Drinks/food2.jpg'},
    ];
    for (final category in categories) {
      await _db.collection('categories').add(category);
    }

    final meals = [
      {
        'name': 'Rolex',
        'category': 'Breakfast',
        'image': 'assets/images/Breakfast/rolex1.jpg',
        'description': 'Ugandan rolled chapati with eggs and vegetables.',
        'price': 5000.0,
        'available': true,
        'accessCount': 0,
      },
      {
        'name': 'Pancakes',
        'category': 'Breakfast',
        'image': 'assets/images/Breakfast/pancakes.jpeg',
        'description': 'Fluffy pancakes served with syrup.',
        'price': 6000.0,
        'available': true,
        'accessCount': 0,
      },
      {
        'name': 'Beef Stew with Rice',
        'category': 'Lunch',
        'image': 'assets/images/Lunch/Beef-Stew.jpg',
        'description': 'Slow-cooked beef stew served with rice.',
        'price': 12000.0,
        'available': true,
        'accessCount': 0,
      },
      {
        'name': 'Chicken Luwombo',
        'category': 'Lunch',
        'image': 'assets/images/Lunch/Chicken-Luwombo-500x500.jpg',
        'description': 'Chicken steamed in banana leaves with groundnut sauce.',
        'price': 15000.0,
        'available': true,
        'accessCount': 0,
      },
      {
        'name': 'Jollof Rice',
        'category': 'Lunch',
        'image': 'assets/images/Lunch/jollof-rice.jpg',
        'description': 'Spiced West African tomato rice.',
        'price': 10000.0,
        'available': true,
        'accessCount': 0,
      },
      {
        'name': 'Fresh Fruit Juice',
        'category': 'Drinks',
        'image': 'assets/images/Drinks/food2.jpg',
        'description': 'Freshly squeezed seasonal fruit juice.',
        'price': 4000.0,
        'available': true,
        'accessCount': 0,
      },
    ];
    for (final meal in meals) {
      await _db.collection('meals').add(meal);
    }
  }
}
