import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const Color _primaryColor = Colors.redAccent;
  static const Color _secondaryColor = Colors.amber;

  // Dark theme colors
  static const Color _darkSurface = Color(0xFF1A1A2E);
  static const Color _darkBackground = Color(0xFF121222);
  static const Color _darkCard = Color(0xFF1E1E36);
  static const Color _darkTextPrimary = Colors.white;
  static const Color _darkTextSecondary = Colors.white70;
  static const Color _darkDivider = Color(0xFF2A2A2A);

  // Light theme colors
  static const Color _lightSurface = Color(0xFFF5F5F5);
  static const Color _lightBackground = Color(0xFFFFFBFE);
  static const Color _lightCard = Colors.white;
  static const Color _lightTextPrimary = Color(0xFF1C1B1F);
  static const Color _lightTextSecondary = Color(0xFF49454F);
  static const Color _lightDivider = Color(0xFFE0E0E0);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: _darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _darkTextPrimary,
      ),
      scaffoldBackgroundColor: _darkBackground,
      cardColor: _darkCard,
      dividerTheme: const DividerThemeData(
        color: _darkDivider,
        thickness: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _darkTextSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        indicatorColor: _primaryColor.withValues(alpha: 0.2),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: _darkTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: _darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: _darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: _darkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: _darkTextPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: _darkTextSecondary, fontSize: 14),
        labelLarge: TextStyle(
          color: _primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: const IconThemeData(
        color: _darkTextSecondary,
        size: 24,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _primaryColor,
        secondary: _secondaryColor,
        surface: _lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _lightTextPrimary,
      ),
      scaffoldBackgroundColor: _lightBackground,
      cardColor: _lightCard,
      dividerTheme: const DividerThemeData(
        color: _lightDivider,
        thickness: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _lightCard,
        foregroundColor: _lightTextPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightCard,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _lightTextSecondary,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightCard,
        indicatorColor: _primaryColor.withValues(alpha: 0.2),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: _lightTextPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: _lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: _lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: _lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: _lightTextPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: _lightTextSecondary, fontSize: 14),
        labelLarge: TextStyle(
          color: _primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(
        color: _lightTextSecondary,
        size: 24,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  /// 主题模式名称
  static String themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  /// 主题模式图标
  static IconData themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.system:
        return Icons.settings_brightness;
    }
  }
}
