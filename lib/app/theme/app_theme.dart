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

  // ------------------------------------------------------------- B1 light
  // Light-theme semantic tokens (Pack B1 Appearance foundation).  The dark
  // palette above and the exact dark ColorScheme inside [dark] are untouched;
  // these tokens describe the Light appearance only.  Contrast is verified by
  // app_theme_test.dart (onSurface 15.2:1, secondary 5.4:1, outline 3.1:1,
  // warning 5.9:1 against [lightSurface]).

  /// Light app background (subtly warm, one step below [lightSurface]).
  static const Color lightBackground = Color(0xFFF1EFEB);

  /// Primary light surface (the audit's light candidate #F4F1F2).
  static const Color lightSurface = Color(0xFFF4F1F2);

  /// Elevated/container light surface.
  static const Color lightSurfaceVariant = Color(0xFFECEAE6);

  /// Primary light text color (15.2:1 on [lightSurface]).
  static const Color lightOnSurface = Color(0xFF1A1C1F);

  /// Secondary light text color (5.4:1 on [lightSurface]).
  static const Color lightSecondary = Color(0xFF5F6368);

  /// Light border/outline color (3.1:1 UI-component boundary on
  /// [lightSurface]).
  static const Color lightOutline = Color(0xFF85898C);

  /// Light warning/amber role (5.9:1 on [lightSurface]).
  static const Color lightWarning = Color(0xFF8A4F00);

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: rose,
          brightness: Brightness.light,
          surface: lightSurface,
        ).copyWith(
          primary: rose,
          onPrimary: const Color(0xFF340012),
          surface: lightSurface,
          onSurface: lightOnSurface,
          secondary: lightSecondary,
          onSecondary: lightOnSurface,
          outline: lightOutline,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
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
        color: lightSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutline),
        ),
      ),
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
        fillColor: lightSurface,
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
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: lightSurfaceVariant,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppTheme.rose
                : lightSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTypography.bottomNavLabel.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppTheme.rose
                : lightSecondary,
          ),
        ),
      ),
    );
  }

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
