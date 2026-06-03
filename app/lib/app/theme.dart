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

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 40;
  static const double xxl = 56;

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusPill = 999;
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.velvetMaroon.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get float => [
        BoxShadow(
          color: AppColors.midnightBurgundy.withValues(alpha: 0.18),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.velvetMaroon.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get header => [
        BoxShadow(
          color: AppColors.midnightBurgundy.withValues(alpha: 0.28),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get primaryButton => [
        BoxShadow(
          color: AppColors.velvetMaroon.withValues(alpha: 0.28),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get goldButton => [
        BoxShadow(
          color: AppColors.brightGold.withValues(alpha: 0.30),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppGradients {
  const AppGradients._();

  static const LinearGradient header = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.midnightBurgundy, AppColors.deepMaroon],
  );

  static const LinearGradient splash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.midnightBurgundy, AppColors.deepMaroon],
  );

  static const LinearGradient darkCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.deepMaroon, AppColors.velvetMaroon],
  );
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
          letterSpacing: -0.5,
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
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: bodyTheme.bodyMedium?.copyWith(
          color: AppColors.ink,
          fontSize: 15,
          height: 1.55,
        ),
        labelLarge: bodyTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmCream,
        foregroundColor: AppColors.deepMaroon,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          color: AppColors.deepMaroon,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.velvetMaroon,
          foregroundColor: AppColors.pearlCream,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.charcoalInk,
          side: const BorderSide(color: AppColors.creamLine, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.creamLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: const BorderSide(color: AppColors.creamLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide:
              const BorderSide(color: AppColors.brightGold, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      dividerColor: AppColors.creamLine,
      dividerTheme: const DividerThemeData(
        color: AppColors.creamLine,
        thickness: 0.6,
        space: 0,
      ),
    );
  }
}
