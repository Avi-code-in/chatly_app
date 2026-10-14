import 'package:flutter/material.dart';

class AppColors {
  // Modern Blue Palette
  static const Color primary = Color(0xFF4A6CF7);
  static const Color primaryLight = Color(0xFF6B8AFF);
  static const Color primaryDark = Color(0xFF2E4BC7);
  static const Color accent = Color(0xFF00D4FF);

  // Gradients
  static const Color gradientStart = Color(0xFF4A6CF7);
  static const Color gradientMid = Color(0xFF6B8AFF);
  static const Color gradientEnd = Color(0xFF8BA3FF);

  static const Color background = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFF0F2FF);
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8F92A1);
  static const Color bubbleMe = Color(0xFF4A6CF7);
  static const Color bubbleOther = Color(0xFFF0F2FF);
  static const Color online = Color(0xFF00C853);
  static const Color unreadBadge = Color(0xFF4A6CF7);
  static const Color divider = Color(0xFFEDEDF2);

  // Shadow Colors
  static const Color shadowBlue = Color(0x334A6CF7);
  static const Color shadowSoft = Color(0x0D000000);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        fontFamily: 'Roboto',
      );

  // Modern Blue Gradient
  static LinearGradient get blueGradient => const LinearGradient(
        colors: [
          Color(0xFF4A6CF7),
          Color(0xFF6B8AFF),
          Color(0xFF8BA3FF),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Light Blue Gradient
  static LinearGradient get softBlueGradient => const LinearGradient(
        colors: [
          Color(0xFFEEF1FF),
          Color(0xFFE0E6FF),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Glassmorphism Box Shadow
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get blueShadow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];
}
