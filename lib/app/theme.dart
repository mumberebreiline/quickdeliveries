import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the app. The palette keeps the green/orange identity
/// already established, but warms up everything around it — a campus food
/// stall should feel inviting, not like a corporate dashboard.
class AppColors {
  static const primaryGreen = Color(0xFF1B5E20);
  static const accentOrange = Color(0xFFEF6C00);
  static const gold = Color(
    0xFFFFC947,
  ); // the one "special" accent — featured items, badges
  static const cream = Color(0xFFFFFBF2); // background, warm not stark
  static const charcoal = Color(
    0xFF2B2118,
  ); // text — warm dark brown, not flat black
  static const softGreenTint = Color(
    0xFFE8F5E9,
  ); // card backgrounds, success states

  // kept for any file still referencing the old int-based constants
  static const int primaryGreenValue = 0xFF1B5E20;
  static const int accentOrangeValue = 0xFFEF6C00;
}

class AppTheme {
  static const primaryGreen = AppColors.primaryGreen;
  static const accentOrange = AppColors.accentOrange;

  /// Display face — rounded and warm, for headers and anything that
  /// should feel like a friendly campus vendor rather than a chain.
  static TextStyle display({
    double size = 24,
    FontWeight weight = FontWeight.w700,
  }) {
    return GoogleFonts.fredoka(
      fontSize: size,
      fontWeight: weight,
      color: AppColors.charcoal,
    );
  }

  /// Body face — clean and highly readable, does the actual work.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.charcoal,
    );
  }

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryGreen,
        primary: AppColors.primaryGreen,
        secondary: AppColors.accentOrange,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: TextTheme(
        headlineMedium: display(size: 26),
        headlineSmall: display(size: 20),
        titleLarge: display(size: 18, weight: FontWeight.w600),
        bodyLarge: body(size: 15),
        bodyMedium: body(size: 14),
        bodySmall: body(
          size: 12,
          color: AppColors.charcoal.withValues(alpha: 0.6),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.fredoka(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 19,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
