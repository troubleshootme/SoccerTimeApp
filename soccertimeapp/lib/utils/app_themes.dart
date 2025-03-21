import 'package:flutter/material.dart';

class AppThemes {
  // Dark theme colors from the image
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkPrimaryBlue = Color(0xFF254079);
  static const Color darkSecondaryBlue = Color(0xFF3A5795);
  static const Color darkGreen = Color(0xFF4CAF50);
  static const Color darkRed = Color(0xFFE57373);
  static const Color darkButtonText = Colors.white;
  static const Color darkText = Colors.white;
  static const Color darkCardBackground = Color(0xFF333333);
  static const Color darkPauseButton = Color(0xFF3F51B5);
  static const Color darkSettingsButton = Color(0xFF673AB7);
  static const Color darkResetButton = Color(0xFFFF5722);
  static const Color darkExitButton = Color(0xFFE91E63);
  
  // Light theme colors (inverting most of the dark theme colors)
  static const Color lightBackground = Color(0xFFF5F5F5); // Off-white background
  static const Color lightPrimaryBlue = Color(0xFF2C4A89); // Darker blue for better contrast
  static const Color lightSecondaryBlue = Color(0xFF1D366A); // Even darker blue for secondary elements
  static const Color lightGreen = Color(0xFF2E7D32); // Darker green for better contrast
  static const Color lightRed = Color(0xFFC62828); // Darker red for better contrast
  static const Color lightButtonText = Colors.white;
  static const Color lightText = Colors.black87;
  static const Color lightCardBackground = Color(0xFFEAEAEA); // Light gray card background
  static const Color lightPauseButton = Color(0xFF303F9F); // Darker indigo for better contrast
  static const Color lightSettingsButton = Color(0xFF5E35B1); // Darker purple for better contrast
  static const Color lightResetButton = Color(0xFFE64A19); // Darker orange for better contrast
  static const Color lightExitButton = Color(0xFFD81B60); // Darker pink for better contrast

  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkPrimaryBlue,
      colorScheme: ColorScheme.dark(
        primary: darkPrimaryBlue,
        secondary: darkSecondaryBlue,
        background: darkBackground,
        error: darkRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkPrimaryBlue,
        foregroundColor: darkText,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: darkCardBackground,
        elevation: 4,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkSecondaryBlue,
          foregroundColor: darkButtonText,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkButtonText,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: darkCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimaryBlue,
      colorScheme: ColorScheme.light(
        primary: lightPrimaryBlue,
        secondary: lightSecondaryBlue,
        background: lightBackground,
        error: lightRed,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightPrimaryBlue,
        foregroundColor: lightButtonText,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: lightCardBackground,
        elevation: 2,
        margin: EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimaryBlue,
          foregroundColor: lightButtonText,
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimaryBlue,
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: lightBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
      ),
    );
  }
} 