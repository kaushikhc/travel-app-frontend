import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Vibrant Harmonious Color Tokens
  static const Color primaryColor = Color(0xFF6C5CE7); // Deep Purple Accent
  static const Color secondaryColor = Color(0xFF00CEC9); // Bright Cyan Accent
  static const Color accentCoral = Color(0xFFFF7675); // Coral
  static const Color darkBackground = Color(0xFF0F172A); // Slate Dark 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate Dark 800
  static const Color darkCard = Color(0xFF334155); // Slate Dark 700
  
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate Light 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);

  // Modern Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: darkSurface,
        error: accentCoral,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: const TextStyle(color: Color(0xFFE2E8F0)),
        bodyMedium: const TextStyle(color: Color(0xFF94A3B8)),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }

  // Modern Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: lightSurface,
        error: accentCoral,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        titleLarge: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        bodyLarge: const TextStyle(color: Color(0xFF334155)),
        bodyMedium: const TextStyle(color: Color(0xFF64748B)),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
