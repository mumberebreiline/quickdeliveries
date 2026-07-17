import 'package:flutter/material.dart';

// TODO: Import your target screens here
import 'breakfast_selection_screen.dart';
//import 'lunch_screen.dart';
//import 'supper_screen.dart';
import '../home/popular_screen.dart';
import '../home/login_screen.dart';
import '../home/about_us_screen.dart';
import '../home/feedback_screen.dart';
import 'food_selection_screen.dart';
import 'Vegetarian_meals_screen.dart';

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

  // 👇 This list controls the 4 cards on this page.
  // "title" = the word shown under the picture (and it's tappable!)
  // "image" = where Flutter should find the picture file
  // "screen" = which page to open when the picture or text is tapped
  //
  // Want to add a 5th category? Just copy one of the maps below,
  // change the "title" and "image", and add its "screen" widget.
  List<Map<String, Object>> _categories() {
    return [
      {
        "title": "Breakfast",
        "image": "assets/images/images (77).jpeg",
        "screen": const BreakfastSelectionScreen(),
      },
      {
        "title": "Lunch",
        "image": "assets/images/Screenshot_2026-07-12-20-14-18-85.jpg",
        "screen": const FoodSelectionScreen(),
      },
      {
        "title": "Supper",
        "image":
            "assets/images/pngtree-jollof-rice-plate-west-african-spicy-tomato-dish-image_17438884.jpg",
        "screen": const FoodSelectionScreen(),
      },
      {
        "title": "Popular",
        "image": "assets/images/Screenshot_2026-07-12-20-17-18-33.jpg",
        "screen": const PopularScreen(),
      },
      {
        "title": "Vegetarians",
        "image": "assets/images/Screenshot_2026-07-12-20-11-25-60.jpg",
        "screen": const VegetarianMealsScreen(),
      },
      {
        "title": "Drinks",
        "image": "assets/images/images (35).jpeg",
        "screen": const PopularScreen(),
      },
    ];
  }

  // The 4 options shown in the top-right dropdown menu.
  // Each one opens a different page when tapped.
  void _handleDropdownSelection(String value) {
    Widget screen;
    switch (value) {
      case "Menu":
        screen = const MenuScreen();
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = _categories();

    // Only keep the categories whose title matches what's typed in
    // the search box. If the box is empty, everything shows.
    final filteredCategories = allCategories.where((category) {
      final title = (category["title"] as String).toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        // When searching, the title turns into a text field.
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Color.fromARGB(255, 255, 152, 0)),
                decoration: const InputDecoration(
                  hintText: "Search meals...",
                  hintStyle: TextStyle(color: Color.fromARGB(255, 255, 152, 0)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              )
            : const Text('Select a Meal'),
        centerTitle: !_isSearching,
        actions: [
          // 🔍 Search bar (top right, before the dropdown)
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

          // ☰ Dropdown menu (top right, right after the search bar)
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: _handleDropdownSelection,
            itemBuilder: (context) => const [
              PopupMenuItem(value: "Menu", child: Text("Menu")),
              PopupMenuItem(value: "Login", child: Text("Login")),
              PopupMenuItem(value: "About", child: Text("About")),
              PopupMenuItem(value: "Feedback", child: Text("Feedback")),
            ],
          ),
        ],
      ),

      // SingleChildScrollView makes the WHOLE screen scrollable,
      // including the grid of pictures and the green footer below it.
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              // Always shows the pictures in a 2-column grid.
              child: GridView.builder(
                // These two lines let the grid live inside the
                // SingleChildScrollView above instead of trying to
                // scroll on its own.
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCategories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 👈 change this number for more/fewer columns
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  return CategoryCard(
                    title: category["title"] as String,
                    imageUrl: category["image"] as String,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => category["screen"] as Widget,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 🟩 Footer with the same tappable text, on a green background.
            // Column stacks the text items one under the other (a
            // vertical list) instead of side by side.
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
                        MaterialPageRoute(
                          builder: (context) => category["screen"] as Widget,
                        ),
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
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The picture itself — tapping it opens the category screen
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                // If Flutter can't find the picture file, this shows a
                // simple grey box with a message instead of crashing.
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

        // 👇 The text UNDER the picture — tapping this also opens the
        // same category screen as tapping the picture does.
        GestureDetector(
          onTap: onTap,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}