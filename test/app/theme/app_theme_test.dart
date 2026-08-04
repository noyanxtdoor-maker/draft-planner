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
}

double _contrast(Color first, Color second) {
  final light = first.computeLuminance() >= second.computeLuminance()
      ? first
      : second;
  final dark = identical(light, first) ? second : first;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}
