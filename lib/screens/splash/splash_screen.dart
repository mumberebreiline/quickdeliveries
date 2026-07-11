import 'dart:math' as math;
import 'package:flutter/material.dart';

class QDColors {
  static const navy = Color(0xFF0A1130);
  static const orange = Color(0xFFFF9B2F);
  static const orangeDeep = Color(0xFFE8790C);
  static const amberGlow = Color(0xFFFFC24D);
  static const steelBlue = Color(0xFF5B7FA6);
  static const teal = Color(0xFF3FE0D0);
  static const white = Color(0xFFFFFFFF);
  static const lightBlue = Color(0xFF8FB8FF);
}

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  final Duration displayDuration;

  const SplashScreen({
    super.key,
    required this.nextScreen,
    this.displayDuration = const Duration(milliseconds: 2800),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.82, end: 1.0)
      .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));
  late final Animation<double> _textSlide = CurvedAnimation(
      parent: _entrance, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.displayDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) =>
              FadeTransition(opacity: animation, child: widget.nextScreen),
        ),
      );
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QDColors.navy,
      body: AnimatedBuilder(
        animation: _loop,
        builder: (context, _) {
          final t = _loop.value;
          final bob = math.sin(t * 2 * math.pi) * 6;
          final glowPulse = 0.55 + 0.35 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _BackgroundGlowPainter())),
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 260,
                          child: Transform.translate(
                            offset: Offset(0, bob),
                            child: _ScooterArt(glowPulse: glowPulse, wheelSpin: t),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(_textSlide),
                          child: FadeTransition(
                            opacity: _textSlide,
                            child: _BrandText(glowPulse: glowPulse),
                          ),
                        ),
                        const SizedBox(height: 26),
                        FadeTransition(
                          opacity: _textSlide,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                QDColors.orange.withOpacity(0.85),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackgroundGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.75);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [QDColors.orange.withOpacity(0.10), QDColors.navy.withOpacity(0.0)],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScooterArt extends StatelessWidget {
  final double glowPulse;
  final double wheelSpin;

  const _ScooterArt({required this.glowPulse, required this.wheelSpin});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 18,
          child: Container(
            width: 210,
            height: 3,
            decoration: BoxDecoration(
              color: QDColors.steelBlue.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 55,
          child: Transform.rotate(
            angle: -0.12,
            child: _GlowWrap(
              glowColor: QDColors.amberGlow,
              intensity: glowPulse,
              child: const Icon(Icons.location_on, size: 64, color: QDColors.amberGlow),
            ),
          ),
        ),
        Positioned(
          top: 78,
          left: 34,
          child: _GlowWrap(
            glowColor: QDColors.steelBlue,
            intensity: 0.4,
            child: Container(
              width: 74,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF3A4A63),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF5B7FA6), width: 1.4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  3,
                  (i) => Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C9CC4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 18,
          right: 4,
          child: _GlowWrap(
            glowColor: QDColors.orange,
            intensity: glowPulse,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [QDColors.orange, QDColors.orangeDeep],
              ).createShader(bounds),
              child: const Icon(Icons.electric_moped, size: 150, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 30,
          child: Transform.rotate(
            angle: wheelSpin * 2 * math.pi,
            child: Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: QDColors.teal.withOpacity(0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowWrap extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double intensity;

  const _GlowWrap({required this.child, required this.glowColor, required this.intensity});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.45 * intensity),
            blurRadius: 40 * intensity,
            spreadRadius: 6 * intensity,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BrandText extends StatelessWidget {
  final double glowPulse;

  const _BrandText({required this.glowPulse});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          fontFamily: 'Roboto',
        ),
        children: [
          const TextSpan(text: 'quick deliver', style: TextStyle(color: QDColors.white)),
          TextSpan(
            text: 'ys',
            style: TextStyle(color: QDColors.lightBlue.withOpacity(0.9 + 0.1 * glowPulse)),
          ),
        ],
      ),
    );
  }
}