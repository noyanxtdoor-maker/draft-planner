import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';

void main() {
  test('canonical highlight pink is shared by the dark color scheme', () {
    const expectedRose = Color(0xFFF9B7C7);
    final scheme = AppTheme.dark().colorScheme;

    expect(AppTheme.rose, expectedRose);
    expect(scheme.primary, expectedRose);
    expect(scheme.onPrimary, const Color(0xFF340012));
  });

  test('Q4: primary and surface text meet WCAG AA contrast', () {
    final scheme = AppTheme.dark().colorScheme;

    expect(
      _contrast(scheme.primary, scheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(scheme.surface, scheme.onSurface),
      greaterThanOrEqualTo(4.5),
    );
  });

  // ------------------------------------------------------------------ B1

  test('B1: AppTheme.light() exists and keeps the rose brand', () {
    final scheme = AppTheme.light().colorScheme;

    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, AppTheme.rose);
    expect(scheme.onPrimary, const Color(0xFF340012));
    expect(AppTheme.rose, const Color(0xFFF9B7C7));
  });

  test('B1: light critical contrast pairs meet locked thresholds', () {
    final scheme = AppTheme.light().colorScheme;

    // Body text on the primary light surface (>= 4.5:1, AA).
    expect(
      _contrast(scheme.surface, scheme.onSurface),
      greaterThanOrEqualTo(4.5),
    );
    // Primary (rose) buttons/labels with dark maroon on-color (>= 4.5:1).
    expect(
      _contrast(scheme.primary, scheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    // Secondary text on the light surface (>= 4.5:1, AA).
    expect(
      _contrast(scheme.secondary, scheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    // Warning role on the light surface (>= 4.5:1 for text roles).
    expect(
      _contrast(AppTheme.lightWarning, scheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    // Outline / border role reaches the 3:1 UI-component boundary.
    expect(
      _contrast(scheme.outline, scheme.surface),
      greaterThanOrEqualTo(3.0),
    );
  });

  test('B1: AppTheme.dark() critical token values are identical to baseline', () {
    final scheme = AppTheme.dark().colorScheme;

    expect(scheme.primary, const Color(0xFFF9B7C7));
    expect(scheme.onPrimary, const Color(0xFF340012));
    expect(scheme.surface, const Color(0xFF181A1E));
    expect(scheme.onSurface, const Color(0xFFF4F1F2));
    expect(scheme.outline, const Color(0xFF454850));
    expect(AppTheme.background, const Color(0xFF0D0E10));
    expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0D0E10));
  });
}

double _contrast(Color first, Color second) {
  final light = first.computeLuminance() >= second.computeLuminance()
      ? first
      : second;
  final dark = identical(light, first) ? second : first;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}
