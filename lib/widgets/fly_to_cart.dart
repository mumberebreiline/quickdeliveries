import 'package:flutter/material.dart';

/// A reusable "fly to cart" animation — the item visually arcs from
/// wherever it was tapped straight to the cart icon, shrinking and
/// fading as it goes. This is the actual visual feedback customers
/// notice; a plain SnackBar saying "Added!" is easy to miss, but
/// watching something physically fly into the cart is not.
///
/// Usage: give the cart icon a GlobalKey, then call FlyToCart.animate()
/// from wherever "Add to Cart" gets tapped, passing that same key and
/// the tap position.
class FlyToCart {
  /// Call this the moment "Add to Cart" is tapped.
  ///
  /// [context] - any BuildContext currently in the tree (e.g. the
  /// button's own context).
  /// [cartKey] - the GlobalKey attached to the cart icon widget in the
  /// AppBar (or wherever it lives) that this should fly toward.
  /// [startPosition] - where the animation begins, usually the tapped
  /// button's position (see FlyToCart.startFromWidget below for an
  /// easy way to get this).
  /// [icon] - what actually flies; defaults to a small cart/food icon,
  /// but you can pass the actual meal's thumbnail image instead for a
  /// nicer effect.
  static void animate({
    required BuildContext context,
    required GlobalKey cartKey,
    required Offset startPosition,
    Widget? icon,
  }) {
    final overlay = Overlay.of(context);
    final cartRenderBox =
        cartKey.currentContext?.findRenderObject() as RenderBox?;
    if (cartRenderBox == null) {
      // Cart icon isn't actually on screen right now (e.g. this
      // screen doesn't show one) - nothing sensible to animate toward,
      // so just skip it rather than crash.
      return;
    }
    final endPosition = cartRenderBox.localToGlobal(
      cartRenderBox.size.center(Offset.zero),
    );

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FlyingIcon(
        start: startPosition,
        end: endPosition,
        onComplete: () => entry.remove(),
        child:
            icon ??
            const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.orange,
              child: Icon(Icons.shopping_cart, color: Colors.white, size: 18),
            ),
      ),
    );
    overlay.insert(entry);
  }

  /// Convenience helper - finds the global screen position of whatever
  /// widget this key is attached to (e.g. the "Add to Cart" button
  /// itself), so you don't have to compute RenderBox math by hand at
  /// every call site.
  static Offset startFromWidget(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}

class _FlyingIcon extends StatefulWidget {
  final Offset start;
  final Offset end;
  final Widget child;
  final VoidCallback onComplete;

  const _FlyingIcon({
    required this.start,
    required this.end,
    required this.child,
    required this.onComplete,
  });

  @override
  State<_FlyingIcon> createState() => _FlyingIconState();
}

class _FlyingIconState extends State<_FlyingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            duration: const Duration(milliseconds: 700),
            vsync: this,
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onComplete();
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInCubic.transform(_controller.value);

        // A slight upward arc rather than a flat straight line - looks
        // like the item is genuinely being tossed into the cart,
        // instead of just sliding across the screen.
        final arcHeight = 80.0;
        final dx = widget.start.dx + (widget.end.dx - widget.start.dx) * t;
        final dy =
            widget.start.dy +
            (widget.end.dy - widget.start.dy) * t -
            arcHeight * (1 - (2 * t - 1) * (2 * t - 1));

        final scale = 1.0 - (0.7 * t); // shrinks as it approaches the cart
        final opacity =
            1.0 - (t > 0.7 ? (t - 0.7) / 0.3 : 0.0); // fades near the end

        return Positioned(
          left: dx - 18,
          top: dy - 18,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: widget.child),
          ),
        );
      },
    );
  }
}
