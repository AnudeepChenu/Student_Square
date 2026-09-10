import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: const Color(0xFFFF3B30),
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF1E1E1E),
      primary: Color(0xFFFF3B30),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    primaryColor: const Color(0xFFFF3B30),
    colorScheme: const ColorScheme.light(
      surface: Color(0xFFF2F2F7), // Light grey container for contrast against pure white
      primary: Color(0xFFFF3B30),
    ),
  );
}