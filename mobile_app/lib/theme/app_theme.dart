import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF13678A),
        primary: const Color(0xFF13678A),
        secondary: const Color(0xFFF5A623),
        surface: const Color(0xFFF4F8FC),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFF10324A),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10324A)),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10324A)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD7E4EE)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E4EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD7E4EE)),
        ),
      ),
    );
  }
}
