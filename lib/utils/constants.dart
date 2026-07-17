import '../models/location.dart';
import '../models/product.dart';

class AppConfig {
  /// How wide each delivery time-window bucket is. Orders that want food
  /// around the same time get grouped together so the vendor can batch-cook
  /// and batch-deliver instead of making separate trips.
  static const Duration deliveryWindowSize = Duration(minutes: 30);

  /// Assumed average speed (km/h) for a vendor walking/boda-boda-ing around
  /// campus. Used only to *estimate* arrival times for flagging risk of
  /// lateness — replace with real Google Directions durations once the Maps
  /// integration is wired up.
  static const double assumedSpeedKmh = 12.0;

  /// If an order's estimated arrival is more than this many minutes past
  /// the customer's preferred time, it gets flagged as at-risk in the plan.
  static const int latenessGraceMinutes = 15;
}

/// Preset list of common delivery points around Makerere University main
/// campus. Coordinates are approximate — good enough to prototype and test
/// the route logic with; swap in precise GPS pins (or let the vendor drop a
/// pin per building) before going to production.
class CampusLocations {
  static const vendorBase = Location(
    id: 'vendor_base',
    name: 'Vendor Kitchen / Stall',
    latitude: 0.33280,
    longitude: 32.56750,
    description: 'Starting point for every delivery route',
  );

  static const List<Location> buildings = [
    Location(
      id: 'main_building',
      name: 'Main Building',
      latitude: 0.33170,
      longitude: 32.56900,
    ),
    Location(
      id: 'cit_building',
      name: 'CIT Building (Block B)',
      latitude: 0.33430,
      longitude: 32.57170,
    ),
    Location(
      id: 'library',
      name: 'University Library',
      latitude: 0.33230,
      longitude: 32.56980,
    ),
    Location(
      id: 'lumumba_hall',
      name: 'Lumumba Hall',
      latitude: 0.33590,
      longitude: 32.57120,
    ),
    Location(
      id: 'livingstone_hall',
      name: 'Livingstone Hall',
      latitude: 0.33020,
      longitude: 32.56680,
    ),
    Location(
      id: 'mary_stuart_hall',
      name: 'Mary Stuart Hall',
      latitude: 0.33380,
      longitude: 32.56600,
    ),
    Location(
      id: 'ctf1',
      name: 'CTF1 Lecture Complex',
      latitude: 0.33350,
      longitude: 32.57050,
    ),
    Location(
      id: 'freedom_square',
      name: 'Freedom Square',
      latitude: 0.33260,
      longitude: 32.56850,
    ),
    Location(
      id: 'school_of_law',
      name: 'School of Law',
      latitude: 0.33110,
      longitude: 32.56820,
    ),
  ];

  static Location? findById(String id) {
    if (id == vendorBase.id) return vendorBase;
    for (final b in buildings) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// Starter menu built from the dishes already in assets/images/. Wire this
/// to a Firestore 'products' collection once the vendor wants to edit her
/// own menu from the app instead of from code.
class SampleMenu {
  static const List<Product> items = [
    Product(
      id: 'rolex',
      name: 'Rolex',
      description: 'Fried chapati rolled with egg, tomato and avocado.',
      price: 7000,
      imageUrl: 'assets/images/IMG-rolex.jpg',
      category: 'Breakfast',
      isFeatured: true,
    ),
    Product(
      id: 'full_english',
      name: 'Full English Breakfast with French Toast',
      description: 'Eggs, sausage, bacon and grilled tomato with French toast.',
      price: 15000,
      imageUrl:
          'assets/images/Breakfast/Full English Breakfast with French Toast.jpeg',
      category: 'Breakfast',
    ),
    Product(
      id: 'french_toast_berries',
      name: 'French Toast with Berries & Maple Syrup',
      description: 'Golden French toast topped with fresh berries and syrup.',
      price: 10000,
      imageUrl:
          'assets/images/Breakfast/French Toast With Berries & Maple Syrup.jpeg',
      category: 'Breakfast',
    ),
    Product(
      id: 'cheese_omelette',
      name: 'Cheese Omelette with Crispy Bacon',
      description: 'A cheesy folded omelette served with crispy bacon strips.',
      price: 9000,
      imageUrl:
          'assets/images/Breakfast/Cheese Omelette Wrapped With Crispy Bacon.jpeg',
      category: 'Breakfast',
    ),
    Product(
      id: 'egg_muffins',
      name: 'Egg Muffins with Toast & Fresh Grapes',
      description: 'Baked egg muffins served with buttered toast and grapes.',
      price: 8500,
      imageUrl:
          'assets/images/Breakfast/Egg Muffins with Toast & Fresh Grapes.jpeg',
      category: 'Breakfast',
    ),
    Product(
      id: 'scrambled_egg_wrap',
      name: 'Scrambled Egg & Vegetable Wrap',
      description:
          'Soft scrambled eggs and vegetables wrapped in a warm tortilla.',
      price: 7500,
      imageUrl: 'assets/images/Breakfast/Scrambled Egg & Vegetable Wrap.jpeg',
      category: 'Breakfast',
    ),
    Product(
      id: 'carrot_pancakes',
      name: 'Carrot Cake Pancakes with Walnuts & Cream',
      description: 'Fluffy carrot-cake-style pancakes with walnuts and cream.',
      price: 9500,
      imageUrl:
          'assets/images/Breakfast/Carrot Cake Pancakes with Walnuts & Cream.jpeg',
      category: 'Breakfast',
    ),
    Product(
      id: 'passion_juice',
      name: 'Passion Fruit Juice',
      description: 'Freshly squeezed passion fruit juice.',
      price: 3000,
      imageUrl: 'assets/images/IMG-passion-fruit-juice.jpg',
      category: 'Drinks',
    ),
    Product(
      id: 'whole_matooke_meat',
      name: 'Whole Matooke with Meat',
      description: 'Steamed matooke served with a rich meat stew.',
      price: 8000,
      imageUrl: 'assets/images/IMG-whole-matooke-with-meat.jpg',
      category: 'Mains',
      isFeatured: true,
    ),
    Product(
      id: 'matooke_irish_chicken',
      name: 'Matooke and Irish with Chicken',
      description: 'Irish potatoes and matooke served with chicken.',
      price: 12000,
      imageUrl: 'assets/images/IMG-matookeandirish-with-chicken.jpg',
      category: 'Mains',
    ),
    Product(
      id: 'rice_beans',
      name: 'Rice with Beans',
      description: 'A hearty plate of rice and beans.',
      price: 5000,
      imageUrl: 'assets/images/IMG-rice-with-beans.jpg',
      category: 'Mains',
    ),
    Product(
      id: 'rice_peas',
      name: 'Rice with Peas',
      description: 'Rice served with peas stew.',
      price: 5000,
      imageUrl: 'assets/images/IMG-rice-with-peas.jpg',
      category: 'Mains',
    ),
    Product(
      id: 'samosa',
      name: 'Samosa (2 pieces)',
      description: 'Crispy pastry filled with spiced minced meat.',
      price: 2500,
      imageUrl: 'assets/images/IMG-20260710-WA0023.jpg',
      category: 'Snacks',
    ),
  ];

  /// Hot drinks offered as a pairing with breakfast — shown as a dropdown
  /// on the order screen whenever the cart has a Breakfast item in it.
  /// These also show up normally under the Drinks category on their own.
  static const List<Product> breakfastDrinkAddOns = [
    Product(
      id: 'tea',
      name: 'Tea',
      description: 'Hot black tea.',
      price: 1500,
      imageUrl: 'assets/images/images (1).jpeg',
      category: 'Drinks',
    ),
    Product(
      id: 'milk_tea',
      name: 'Milk Tea',
      description: 'Tea brewed with milk, Ugandan-style.',
      price: 2000,
      imageUrl: 'assets/images/images (2).jpeg',
      category: 'Drinks',
    ),
    Product(
      id: 'coffee',
      name: 'Coffee',
      description: 'Hot black coffee.',
      price: 2000,
      imageUrl: 'assets/images/images (3).jpeg',
      category: 'Drinks',
    ),
    Product(
      id: 'hot_chocolate',
      name: 'Hot Chocolate',
      description: 'Warm, rich hot chocolate.',
      price: 2500,
      imageUrl: 'assets/images/images (7).jpeg',
      category: 'Drinks',
    ),
    Product(
      id: 'plain_milk',
      name: 'Milk',
      description: 'A warm glass of milk.',
      price: 1500,
      imageUrl: 'assets/images/images (8).jpeg',
      category: 'Drinks',
    ),
  ];
}

/// One menu category, represented by a single photo — tapping it is meant
/// to feel like walking into a themed room ("salon") full of related
/// dishes, the way Café Javas' menu splits into Breakfasts/Big
/// Meals/Drinks/Desserts as big tappable tiles rather than a flat list.
class CategoryInfo {
  final String name;
  final String imageUrl;

  const CategoryInfo({required this.name, required this.imageUrl});
}

class MenuCategories {
  static const List<CategoryInfo> categories = [
    CategoryInfo(name: 'Breakfast', imageUrl: 'assets/images/IMG-rolex.jpg'),
    CategoryInfo(
      name: 'Mains',
      imageUrl: 'assets/images/IMG-whole-matooke-with-meat.jpg',
    ),
    CategoryInfo(
      name: 'Drinks',
      imageUrl: 'assets/images/IMG-passion-fruit-juice.jpg',
    ),
    CategoryInfo(
      name: 'Snacks',
      imageUrl: 'assets/images/IMG-20260710-WA0023.jpg',
    ),
  ];

  /// Full-bleed background images for the landing screen's sliding hero —
  /// pulled from Atukunda's branch as requested. Copy these four files
  /// into assets/images/ (they're not in this project's asset folder yet):
  /// food1.jpg, food2.jpg, food3.jpg, IMG-20260710-WA0024.jpg
  static const List<String> heroImages = [
    'assets/images/food1.jpg',
    'assets/images/food2.jpg',
    'assets/images/food3.jpg',
    'assets/images/IMG-20260710-WA0024.jpg',
  ];
}
