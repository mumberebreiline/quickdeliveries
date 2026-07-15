import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/product.dart';
import '../../providers/order_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/featured_item_card.dart';
import '../../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _categories = ['All', 'Breakfast', 'Mains', 'Drinks', 'Snacks'];
  static const _rotatingMessages = [
    'Freshly prepared today',
    'Delivering across Makerere',
    "Pick your building and time — we'll handle the route",
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(
        () => _messageIndex = (_messageIndex + 1) % _rotatingMessages.length,
      );
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  List<Product> get _featuredItems =>
      SampleMenu.items.where((p) => p.isFeatured).toList();

  List<Product> get _filteredItems {
    return SampleMenu.items.where((p) {
      final matchesCategory =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(context)),
                SliverToBoxAdapter(child: _buildSearchBar()),
                SliverToBoxAdapter(child: _buildCategoryChips()),
                if (_selectedCategory == 'All' &&
                    _searchQuery.isEmpty &&
                    _featuredItems.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildFeaturedCarousel(orderProvider),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: _filteredItems.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Center(
                              child: Text(
                                'No dishes match — try a different search or category',
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final product = _filteredItems[index];
                            return ProductCard(
                              product: product,
                              onAdd: () => orderProvider.addToCart(product),
                            );
                          }, childCount: _filteredItems.length),
                        ),
                ),
              ],
            ),
            _buildCartBar(context, orderProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Our Menu', style: AppTheme.display(size: 26)),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _rotatingMessages[_messageIndex],
                    key: ValueKey(_messageIndex),
                    style: AppTheme.body(
                      size: 13,
                      color: AppColors.charcoal.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withOpacity(0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.storefront_outlined,
                color: AppColors.primaryGreen,
              ),
              tooltip: 'Vendor login',
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.vendorLogin),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.charcoal.withOpacity(0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          style: AppTheme.body(size: 14),
          decoration: InputDecoration(
            hintText: 'Search dishes...',
            hintStyle: AppTheme.body(
              size: 14,
              color: AppColors.charcoal.withOpacity(0.4),
            ),
            prefixIcon: const Icon(Icons.search, color: AppColors.primaryGreen),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedCategory = category),
              labelStyle: AppTheme.body(
                size: 13,
                weight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.charcoal,
              ),
              selectedColor: AppColors.primaryGreen,
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primaryGreen.withOpacity(0.2),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCarousel(OrderProvider orderProvider) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Popular right now', style: AppTheme.display(size: 17)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _featuredItems.length,
              itemBuilder: (context, index) {
                final product = _featuredItems[index];
                return FeaturedItemCard(
                  product: product,
                  onAdd: () => orderProvider.addToCart(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar(BuildContext context, OrderProvider orderProvider) {
    final hasItems = orderProvider.cartItemCount > 0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      left: 16,
      right: 16,
      bottom: hasItems ? 16 : -80,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primaryGreen,
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, AppRoutes.order),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_bag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${orderProvider.cartItemCount} item${orderProvider.cartItemCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      formatUgx(orderProvider.cartTotal),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
