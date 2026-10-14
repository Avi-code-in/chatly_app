import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF5B4DFF);
  static const Color primaryLight = Color(0xFF7B6CFF);
  static const Color primaryDark = Color(0xFF4A3DE8);
  static const Color background = Color(0xFFF8F9FE);
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8F92A1);
  static const Color bubbleMe = Color(0xFF5B4DFF);
  static const Color bubbleOther = Color(0xFFF0F0F5);
  static const Color online = Color(0xFF00C853);
  static const Color unreadBadge = Color(0xFF5B4DFF);
  static const Color divider = Color(0xFFEDEDF2);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.white,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
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
      );
}
