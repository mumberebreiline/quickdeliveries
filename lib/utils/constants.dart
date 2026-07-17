import '../models/location.dart';
import '../models/product.dart';

/// App-wide constants. Colors match what's already used in homescreen.dart
/// so every screen we add stays visually consistent.
class AppColors {
  static const int primaryGreenValue = 0xFF1B5E20;
  static const int accentOrangeValue = 0xFFEF6C00; // Colors.orange[700]
}

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
      id: 'whole_matooke_meat',
      name: 'Whole Matooke with Meat',
      description: 'Steamed matooke served with a rich meat stew.',
      price: 8000,
      imageUrl: 'assets/images/IMG-whole-matooke-with-meat.jpg',
    ),
    Product(
      id: 'matooke_irish_chicken',
      name: 'Matooke and Irish with Chicken',
      description: 'Irish potatoes and matooke served with chicken.',
      price: 12000,
      imageUrl: 'assets/images/IMG-matookeandirish-with-chicken.jpg',
    ),
    Product(
      id: 'rice_beans',
      name: 'Rice with Beans',
      description: 'A hearty plate of rice and beans.',
      price: 5000,
      imageUrl: 'assets/images/IMG-rice-with-beans.jpg',
    ),
    Product(
      id: 'rice_peas',
      name: 'Rice with Peas',
      description: 'Rice served with peas stew.',
      price: 5000,
      imageUrl: 'assets/images/IMG-rice-with-peas.jpg',
    ),
    Product(
      id: 'rolex',
      name: 'Rolex',
      description: 'Fried chapati rolled with egg, tomato and avocado.',
      price: 7000,
      imageUrl: 'assets/images/IMG-rolex.jpg',
      category: 'Snack',
    ),
    Product(
      id: 'passion_juice',
      name: 'Passion Fruit Juice',
      description: 'Freshly squeezed passion fruit juice.',
      price: 3000,
      imageUrl: 'assets/images/IMG-passion-fruit-juice.jpg',
      category: 'Drink',
    ),
  ];
}
