import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/routes.dart';
import '../../providers/customer_auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/category_tile.dart';
import '../customer/customer_login_screen.dart';
import '../order/category_menu_screen.dart';
import '../vendor/vendor_login_screen.dart';

/// The app's landing screen. A sliding photo hero up top — each slide is
/// itself clickable straight into that category's menu, the way Café
/// Javas' app uses its banner to promote a section rather than just
/// decorate the top of the screen — with the customer/vendor login
/// corners overlaid, and a horizontally-scrolling strip of category cards
/// below it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _heroIndex = 0;

  // Each hero slide doubles as a promo banner for one category — tapping
  // it goes straight into that category's menu, exactly like tapping a
  // Café Javas banner takes you into that section instead of just being
  // decorative.
  List<MenuCategory> get _heroSlides => MenuCategories.all;

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final customerAuth = context.watch<CustomerAuthProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 340,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CarouselSlider(
                    options: CarouselOptions(
                      height: 340,
                      viewportFraction: 1,
                      autoPlay: true,
                      autoPlayInterval: const Duration(seconds: 4),
                      onPageChanged: (index, reason) {
                        setState(() => _heroIndex = index);
                      },
                    ),
                    items: _heroSlides.map((category) {
                      return GestureDetector(
                        onTap: () => _openCategory(context, category),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              category.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: Colors.grey.shade400),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.35),
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.6),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _CornerAccountButton(
                            icon: Icons.person_outline,
                            label: customerAuth.isLoggedIn
                                ? (customerAuth.profile?.name ?? 'Account')
                                : 'Log in',
                            onTap: () {
                              if (customerAuth.isLoggedIn) {
                                _showCustomerAccountSheet(
                                  context,
                                  customerAuth,
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CustomerLoginScreen(),
                                  ),
                                );
                              }
                            },
                          ),
                          _CornerAccountButton(
                            icon: Icons.storefront_outlined,
                            label: 'Vendor',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VendorLoginScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 44,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _heroSlides[_heroIndex].displayLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Tap to explore',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white70,
                              size: 15,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Dot page indicator, so the sliding banner reads as
                  // navigable rather than purely decorative.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_heroSlides.length, (index) {
                        final isActive = index == _heroIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Browse by category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Swipe for more',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: MenuCategories.all.length,
                itemBuilder: (context, index) {
                  final category = MenuCategories.all[index];
                  final count = SampleMenu.items
                      .where((p) => p.category == category.categoryName)
                      .length;
                  return CategoryTile(
                    category: category,
                    itemCount: count,
                    onTap: () => _openCategory(context, category),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      floatingActionButton: orderProvider.cartItemCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.order),
              label: Text('View Cart (${orderProvider.cartItemCount})'),
              icon: const Icon(Icons.shopping_cart_checkout),
            )
          : null,
    );
  }

  void _openCategory(BuildContext context, MenuCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryMenuScreen(
          categoryName: category.categoryName,
          displayLabel: category.displayLabel,
        ),
      ),
    );
  }

  void _showCustomerAccountSheet(
    BuildContext context,
    CustomerAuthProvider customerAuth,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () {
                customerAuth.signOut();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerAccountButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CornerAccountButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
