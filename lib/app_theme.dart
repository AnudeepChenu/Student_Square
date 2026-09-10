import 'package:flutter/material.dart';

class AppTheme {
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color accentRed = Color(0xFFFF3B30);
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightCardColor = Color(0xFFFFFFFF);
  
  // Semantic Colors
  static const Color statusGreen = Color(0xFF34C759);
  static const Color statusYellow = Color(0xFFFFCC00);
  static const Color statusRed = Color(0xFFFF3B30);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    primaryColor: accentRed,
    colorScheme: const ColorScheme.dark(
      surface: darkCardColor,
      primary: accentRed,
    ),
    fontFamily: 'SF Pro Display',
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    primaryColor: accentRed,
    colorScheme: const ColorScheme.light(
      surface: lightCardColor,
      primary: accentRed,
    ),
    fontFamily: 'SF Pro Display',
  );
}