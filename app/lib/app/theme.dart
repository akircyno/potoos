import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Potoos brand palette
  static const midnightBurgundy = Color(0xFF21070D);
  static const deepMaroon = Color(0xFF4A1220);
  static const velvetMaroon = Color(0xFF6B1C2E);
  static const garnetHighlight = Color(0xFF8A2438);
  static const softGold = Color(0xFFC4973A);
  static const brightGold = Color(0xFFF1C85B);
  static const warmCream = Color(0xFFFAF6F0);
  static const pearlCream = Color(0xFFFFF8E8);
  static const featherTaupe = Color(0xFFB9A58A);
  static const charcoalInk = Color(0xFF24191B);

  // Legacy aliases kept for backward compat with existing widgets
  static const maroon = velvetMaroon;
  static const maroonLight = garnetHighlight;
  static const maroonFaint = Color(0xFFF7EDEF);
  static const maroonTint = Color(0xFFF0D9DE);
  static const goldLight = Color(0xFFE8C87A);
  static const goldFaint = Color(0xFFFBF5E6);
  static const creamLine = Color(0xFFE9DED0);
  static const ink = charcoalInk;
  static const mutedInk = featherTaupe;
  static const navMuted = Color(0xFFC0A89A);
  static const white = Color(0xFFFFFFFF);
}

class AppTheme {
  const AppTheme._();

  static const headingFont = 'GeneralSans';
  static const bodyFont = 'Inter';

  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.maroon,
        primary: AppColors.maroon,
        secondary: AppColors.softGold,
        surface: AppColors.white,
      ),
      fontFamily: bodyFont,
      scaffoldBackgroundColor: AppColors.warmCream,
      useMaterial3: true,
    );

    final bodyTheme = base.textTheme.apply(
      fontFamily: bodyFont,
      bodyColor: AppColors.ink,
      displayColor: AppColors.deepMaroon,
    );

    return base.copyWith(
      textTheme: bodyTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: headingFont,
          color: AppColors.deepMaroon,
          fontSize: 32,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: const TextStyle(
          fontFamily: headingFont,
          color: AppColors.deepMaroon,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        headlineMedium: const TextStyle(
          fontFamily: headingFont,
          color: AppColors.deepMaroon,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        titleLarge: const TextStyle(
          fontFamily: headingFont,
          color: AppColors.deepMaroon,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: bodyTheme.bodyMedium?.copyWith(
          color: AppColors.ink,
          fontSize: 15,
        ),
        labelLarge: bodyTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.warmCream,
        foregroundColor: AppColors.deepMaroon,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: headingFont,
          color: AppColors.deepMaroon,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.maroon,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.maroon,
          side: const BorderSide(color: AppColors.creamLine),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.creamLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.creamLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.softGold, width: 1.4),
        ),
      ),
    );
  }
}
