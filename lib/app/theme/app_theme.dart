import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color rose = Color(0xFFFF7895);
  static const Color background = Color(0xFF0D0E10);
  static const Color surface = Color(0xFF181A1E);
  static const Color outline = Color(0xFF454850);
  static const Color warning = Color(0xFFFFC857);
  static const Color eventAccent = Color(0xFF4CAF50);

  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: rose,
          brightness: Brightness.dark,
          surface: surface,
        ).copyWith(
          primary: rose,
          onPrimary: const Color(0xFF340012),
          surface: surface,
          onSurface: const Color(0xFFF4F1F2),
          outline: outline,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Color(0xFF101113),
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
