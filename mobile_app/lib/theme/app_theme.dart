import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color _lightCanvas = Color(0xFFF6F4EF);
  static const Color _lightSurface = Color(0xFFFFFCF7);
  static const Color _lightPrimary = Color(0xFF3E63DD);
  static const Color _lightSecondary = Color(0xFF7A8DAF);
  static const Color _lightTertiary = Color(0xFF2F566B);
  static const Color _lightOutline = Color(0xFFE2DCD0);

  static const Color _darkCanvas = Color(0xFF151922);
  static const Color _darkSurface = Color(0xFF1C212B);
  static const Color _darkPrimary = Color(0xFF9DB2FF);
  static const Color _darkSecondary = Color(0xFFA0AFCB);
  static const Color _darkTertiary = Color(0xFF8BB3C5);
  static const Color _darkOutline = Color(0xFF2F3745);

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _lightPrimary,
        brightness: Brightness.light,
        primary: _lightPrimary,
        secondary: _lightSecondary,
        tertiary: _lightTertiary,
        surface: _lightSurface,
        surfaceContainerHighest: const Color(0xFFF0ECE2),
        outline: _lightOutline,
      ),
      scaffoldBackgroundColor: _lightCanvas,
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E2634),
          letterSpacing: -0.8,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E2634),
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E2634),
          letterSpacing: -0.6,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E2634),
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3A455D),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0x00FFFFFF),
        elevation: 0,
        foregroundColor: Color(0xFF1E2634),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _lightSurface,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x12000000),
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _lightOutline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFCF7),
        indicatorColor: const Color(0xFFE7EAFA),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? const Color(0xFF314998) : const Color(0xFF6E7788),
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFFE7EAFA)
                : Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFF314998)
                : const Color(0xFF5A6475);
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightPrimary,
          side: const BorderSide(color: _lightOutline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F5EE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2DCD0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2DCD0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lightPrimary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFECE8E0),
        selectedColor: const Color(0xFFDEE4F8),
        side: const BorderSide(color: Color(0xFFD9D2C4)),
        labelStyle: const TextStyle(color: Color(0xFF454D5C)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _darkPrimary,
        brightness: Brightness.dark,
        primary: _darkPrimary,
        secondary: _darkSecondary,
        tertiary: _darkTertiary,
        surface: _darkSurface,
        surfaceContainerHighest: const Color(0xFF252C38),
        outline: _darkOutline,
      ),
      scaffoldBackgroundColor: _darkCanvas,
      textTheme: textTheme.copyWith(
        displaySmall: textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFEEF2F9),
          letterSpacing: -0.8,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFEEF2F9),
          letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: const Color(0xFFEEF2F9),
          letterSpacing: -0.6,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFFEEF2F9),
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFFD9DEEA),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0x00000000),
        elevation: 0,
        foregroundColor: Color(0xFFEEF2F9),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x33000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _darkOutline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1C212B),
        indicatorColor: const Color(0xFF2A3344),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? const Color(0xFFE9EEFB) : const Color(0xFFA8B0C1),
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFF30374A)
                : Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? const Color(0xFFE9EEFB)
                : const Color(0xFFB7BFCE);
          }),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: const Color(0xFF101522),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkPrimary,
          side: const BorderSide(color: _darkOutline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF232A36),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF343C4D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF343C4D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _darkPrimary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A303C),
        selectedColor: const Color(0xFF354059),
        side: const BorderSide(color: Color(0xFF3A4354)),
        labelStyle: const TextStyle(color: Color(0xFFDDE3F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
