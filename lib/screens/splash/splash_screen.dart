import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../utils/constants.dart';

/// The very first thing anyone sees — a full-bleed autoplay carousel of
/// dishes, matching the hero pattern from Atukunda's branch. Both login
/// paths live in the corner here: customer sign-in is entirely optional
/// (there's always a way to skip straight to ordering as a guest), the
/// vendor's is required to reach her dashboard.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
            items: MenuCategories.heroImages.map((image) {
              return Image.asset(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: Colors.black26, width: double.infinity),
              );
            }).toList(),
          ),

          // Dark transparent layer so text/icons stay readable over any photo
          Container(color: Colors.black.withValues(alpha: 0.45)),

          SafeArea(
            child: Column(
              children: [
                // Corner login icons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quick Deliveries',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Row(
                        children: [
                          _CornerIconButton(
                            icon: Icons.person_outline,
                            tooltip: 'Customer login (optional)',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.customerLogin,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CornerIconButton(
                            icon: Icons.storefront_outlined,
                            tooltip: 'Vendor login',
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.vendorLogin,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Center content
                const Text(
                  'Delicious meals\nmade with love',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fresh Ugandan dishes, delivered across Makerere',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, AppRoutes.home),
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
                    'ORDER NOW',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CornerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
