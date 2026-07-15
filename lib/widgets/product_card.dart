import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../models/product.dart';
import '../utils/helpers.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onAdd;

  const ProductCard({super.key, required this.product, required this.onAdd});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale = Tween(
    begin: 1.0,
    end: 0.85,
  ).chain(CurveTween(curve: Curves.easeOut)).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAdd() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onAdd();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              product.imageUrl,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 88,
                height: 88,
                color: AppColors.softGreenTint,
                child: const Icon(
                  Icons.fastfood,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTheme.display(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  product.description,
                  style: AppTheme.body(
                    size: 12,
                    color: AppColors.charcoal.withOpacity(0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatUgx(product.price),
                      style: AppTheme.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    ScaleTransition(
                      scale: _scale,
                      child: ElevatedButton(
                        onPressed: product.isAvailable ? _handleAdd : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          product.isAvailable ? 'Add' : 'Sold out',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
