import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../order/menu_screen.dart';
import 'about_us_screen.dart';
import 'feedback_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final List<String> images = [
    "assets/images/food1.jpg",
    "assets/images/food2.jpg",
    "assets/images/food3.jpg",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Sliding food images

          CarouselSlider(
            options: CarouselOptions(
              height: double.infinity,
              viewportFraction: 1,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
            ),
            items: images.map((image) {
              return Image.asset(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
              );
            }).toList(),
          ),

          // Dark transparent layer

          Container(
            color: Colors.black.withValues(alpha: 0.45),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top navigation

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        "assets/images/logo.png",
                        height: 55,
                      ),
                      Row(
                        children: [
                          navItem(
                            context,
                            "Menu",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MenuScreen(),
                              ),
                            ),
                          ),
                          navItem(
                            context,
                            "Login",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(),
                              ),
                            ),
                          ),
                          navItem(
                            context,
                            "About Us",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AboutUsScreen(),
                              ),
                            ),
                          ),
                          navItem(
                            context,
                            "Feedback",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const FeedbackScreen(),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const Spacer(),

                // Center content

                const Text(
                  "Delicious meals\nmade with love",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuScreen()//MealCategoryScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "START ORDER",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget navItem(BuildContext context, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}