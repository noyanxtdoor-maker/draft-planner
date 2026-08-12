import 'package:flutter/material.dart';

/// The single production typography source.  Feature screens may adjust color
/// or weight for emphasis, but the size and line-height tokens stay here so a
/// text-scale change cannot make one flow drift away from the rest of the app.
abstract final class AppTypography {
  static const TextStyle pageTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle secondary = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle micro = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle button = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle metricLarge = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle metricCompact = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 22,
    height: 26 / 22,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle bottomNavLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle plannerEventTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 17 / 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle plannerEventTime = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w400,
  );
}

abstract final class AppTheme {
  /// Canonical app highlight pink shared by existing highlight roles.
  static const Color rose = Color(0xFFF9B7C7);
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
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        toolbarHeight: 72,
        titleTextStyle: AppTypography.pageTitle,
      ),
      textTheme: const TextTheme(
        displayLarge: AppTypography.pageTitle,
        headlineSmall: AppTypography.metricLarge,
        titleLarge: AppTypography.pageTitle,
        titleMedium: AppTypography.sectionTitle,
        bodyLarge: AppTypography.body,
        bodyMedium: AppTypography.cardTitle,
        bodySmall: AppTypography.secondary,
        labelLarge: AppTypography.button,
        labelMedium: AppTypography.micro,
        labelSmall: AppTypography.micro,
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outline),
        ),
      ),
      // Compact internal dialogs: 86-90% width on phones, 18-20 sp title,
      // 14-15 sp body, 18-22 dp corner radius.  Root screens do not use
      // AlertDialog for main content, so this scopes to dialog surfaces.
      dialogTheme: const DialogThemeData(
        insetPadding: EdgeInsets.symmetric(horizontal: 22, vertical: 28),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 19,
          height: 24 / 19,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      // Pack 2 accent restraint (shared tokens -> component -> every root):
      // the selected root uses a restrained accent (canonical rose), while
      // unselected roots use a neutral gray.  No filled indicator or pink bar
      // background; selection stays legible in dark mode.
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF101113),
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppTheme.rose
                : const Color(0xFF9CA0A6),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.bottomNavLabel.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppTheme.rose
                : const Color(0xFF9CA0A6),
          ),
        ),
      ),
    );
  }
}
