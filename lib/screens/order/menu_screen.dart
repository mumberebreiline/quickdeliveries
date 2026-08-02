import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'breakfast_selection_screen.dart';
import '../home/popular_screen.dart';
import '../home/login_screen.dart';
import '../home/about_us_screen.dart';
import '../home/feedback_screen.dart';
import 'food_selection_screen.dart';
import 'vegetarian_meals_screen.dart';
import 'drinks.dart';
import 'cart_screen.dart';
import '../../services/cart_service.dart';
import 'food_item.dart';
import 'order_detail_screen.dart';
import 'main_course_order_detail_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MenuScreenBody();
  }
}

class _MenuScreenBody extends StatefulWidget {
  const _MenuScreenBody();

  @override
  State<_MenuScreenBody> createState() => _MenuScreenBodyState();
}

class _MenuScreenBodyState extends State<_MenuScreenBody> {
  // Controls whether the search box is showing in the AppBar
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 👇 This list controls the cards on this page.
  // "title" = the word shown under the picture (and it's tappable!)
  // "image" = where Flutter should find the picture file
  // "screen" = which page to open when the picture or text is tapped
  List<Map<String, Object>> _categories() {
    return [
      {
        "title": "Breakfast",
        "image": "assets/images/images (89).jpeg",
        "screen": const BreakfastSelectionScreen(),
      },
      {
        "title": "Main Courses",
        "image": "assets/images/menu4.jpg",
        "screen": const FoodSelectionScreen(),
      },
      {
        // Was "Screenshot_2026-07-12-20-11-25-60.jpg" — that file
        // doesn't exist in assets/images/, so this tile was silently
        // falling back to a placeholder icon. Using an existing image
        // for now so the tile shows *something* real — swap in an
        // actual vegetarian photo whenever you have one, same folder.
        "title": "Vegetarian Special",
        "image": "assets/images/menu9.jpg",
        "screen": const VegetarianMealsScreen(),
      },
      {
        // Was "images (35).jpeg" — also missing, same fix as above.
        "title": "Drinks",
        "image": "assets/images/menu6.jpeg",
        "screen": const DrinksSelectionScreen(),
      },
      {
        // Was "Screenshot_2026-07-12-20-17-18-33.jpg" — also missing.
        "title": "Popular",
        "image":
            "assets/images/pngtree-jollof-rice-plate-west-african-spicy-tomato-dish-image_17435425.jpg",
        "screen": const PopularScreen(),
      },
    ];
  }

  // The options shown in the top-right dropdown menu.
  void _handleDropdownSelection(String value) {
    Widget screen;
    switch (value) {
      case "Menu":
        screen = const MenuScreen();
        break;
      case "Cart":
        screen = const CartScreen();
        break;
      case "Login":
        screen = const LoginScreen();
        break;
      case "About":
        screen = const AboutUsScreen();
        break;
      case "Feedback":
        screen = const FeedbackScreen();
        break;
      default:
        screen = const MenuScreen();
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // ============================================================
  // 🔍 DATABASE-BACKED SEARCH
  // ============================================================
  // A "collection group" query looks across EVERY "Meals" subcollection
  // at once — Categories/Breakfast/Meals, Categories/Drinks/Meals,
  // Categories/main courses/Meals, etc — instead of just one category.
  // That's what actually lets someone search "chapati" and find it
  // regardless of which category it lives under.
  Stream<QuerySnapshot> _allMealsStream() {
    return FirebaseFirestore.instance.collectionGroup('Meals').snapshots();
  }

  // Same field-picking pattern used across the app's other screens —
  // checks a capitalized key first, then falls back to lowercase.
  FoodItem _mealFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String pick(List<String> keys, String fallback) {
      for (final key in keys) {
        final value = data[key];
        if (value != null) return value.toString();
      }
      return fallback;
    }

    // The category a meal belongs to is the ID of its grandparent
    // document: Categories/{categoryId}/Meals/{mealId}.
    final categoryId = doc.reference.parent.parent?.id ?? '';

    return FoodItem(
      id: doc.id,
      name: pick(['Name', 'name'], 'Unnamed'),
      price: double.tryParse(pick(['Price', 'price'], '0')) ?? 0.0,
      imageUrl: pick(['Image', 'imageUrl', 'image'], ''),
      category: categoryId,
    );
  }

  void _openSearchResult(BuildContext context, FoodItem food) {
    final screen = food.category.toLowerCase() == 'main courses'
        ? MainCourseOrderDetailScreen(food: food)
        : OrderDetailScreen(food: food);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = _categories();
    final orientation = MediaQuery.of(context).orientation;
    final crossAxisCount = orientation == Orientation.landscape ? 3 : 2;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Color.fromARGB(255, 255, 150, 4)),
                decoration: const InputDecoration(
                  hintText: "Search for a dish...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim());
                },
              )
            : const Text(
                'Select a Meal',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
        centerTitle: !_isSearching,
        backgroundColor: Colors.orange,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = "";
                }
              });
            },
          ),
          // 🛒 Cart icon with a live badge — same pattern as every
          // selection screen. Updates automatically whenever the cart
          // changes anywhere in the app.
          ListenableBuilder(
            listenable: CartService.instance,
            builder: (context, _) {
              final count = CartService.instance.itemCount;
              return IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                ),
                icon: Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.shopping_cart),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: _handleDropdownSelection,
            itemBuilder: (context) => const [
              PopupMenuItem(value: "Menu", child: Text("Menu")),
              PopupMenuItem(value: "Cart", child: Text("Cart")),
              PopupMenuItem(value: "Login", child: Text("Login")),
              PopupMenuItem(value: "About", child: Text("About")),
              PopupMenuItem(value: "Feedback", child: Text("Feedback")),
            ],
          ),
        ],
      ),
      // Once there's an actual search query, show live database results
      // instead of the category grid.
      body: _searchQuery.isEmpty
          ? _buildCategoryView(context, allCategories, crossAxisCount)
          : _buildSearchResults(context),
    );
  }

  Widget _buildCategoryView(
    BuildContext context,
    List<Map<String, Object>> allCategories,
    int crossAxisCount,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allCategories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, // 👈 2 in portrait, 3 in landscape
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final category = allCategories[index];
                return CategoryCard(
                  title: category["title"] as String,
                  imageUrl: category["image"] as String,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => category["screen"] as Widget),
                  ),
                );
              },
            ),
          ),

          // 🟩 Footer with the same tappable text, on an orange background.
          Container(
            width: double.infinity,
            color: const Color.fromARGB(255, 255, 153, 0),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: allCategories.map((category) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => category["screen"] as Widget),
                    ),
                    child: Text(
                      category["title"] as String,
                      style: const TextStyle(
                        color: Color.fromARGB(255, 252, 251, 249),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _allMealsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not search right now: ${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final query = _searchQuery.toLowerCase();
        final results = (snapshot.data?.docs ?? [])
            .map(_mealFromDoc)
            .where((food) => food.name.toLowerCase().contains(query))
            .toList();

        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No dishes found for "$_searchQuery"', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final food = results[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                onTap: () => _openSearchResult(context, food),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    food.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(Icons.fastfood),
                    ),
                  ),
                ),
                title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  food.category,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                trailing: Text(
                  'UGX ${food.price.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Reusable Widget for the Tappable Image Card
class CategoryCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const CategoryCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('Add your picture here'),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}