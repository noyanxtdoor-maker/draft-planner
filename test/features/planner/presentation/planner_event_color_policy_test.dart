import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

void main() {
  test('contrast resolver chooses light text for dark surfaces', () {
    expect(
      PlannerEventBlockColorPolicy.textColor(
        const Color(0xFF404447),
        Brightness.dark,
      ),
      Colors.white,
    );
  });

  test('Planner Event text stays white even on bright surfaces', () {
    // Locked white-text rule: the block never switches title/time to black
    // (Dark baseline; Light uses the readable onSurface text contract).
    expect(
      PlannerEventBlockColorPolicy.textColor(
        const Color(0xFFF2E9E0),
        Brightness.dark,
      ),
      Colors.white,
    );
    expect(
      PlannerEventBlockColorPolicy.textColor(
        const Color(0xFFDEEDF2),
        Brightness.dark,
      ),
      Colors.white,
    );
  });

  test('contrast ratio is symmetric and deterministic', () {
    final lightOnDark = PlannerEventBlockColorPolicy.contrastRatio(
      Colors.white,
      const Color(0xFF404447),
    );
    final darkOnLight = PlannerEventBlockColorPolicy.contrastRatio(
      const Color(0xFF1B1B1F),
      const Color(0xFFF2E9E0),
    );
    expect(lightOnDark, greaterThan(4.5));
    expect(darkOnLight, greaterThan(4.5));
  });

  test(
    'faded surface derivation keeps the accent hue under a neutral veil',
    () {
      final surface = PlannerEventBlockColorPolicy.mutedSurfaceFromAccent(
        const Color(0xFF676DA2),
      );
      final accentHsl = HSLColor.fromColor(const Color(0xFF676DA2));
      final surfaceHsl = HSLColor.fromColor(surface);
      // Part 15 lock: the surface is the accent hue blended into a controlled
      // neutral charcoal veil — chroma is cut hard, lightness lands in the
      // medium-dark band, and the block separates from black without reading
      // as a bright card or a near-black muddy card.
      expect(surfaceHsl.hue, closeTo(accentHsl.hue, 2));
      expect(surfaceHsl.lightness, inInclusiveRange(0.34, 0.50));
      expect(surfaceHsl.saturation, lessThan(accentHsl.saturation * 0.55));
      expect(surfaceHsl.lightness, lessThan(accentHsl.lightness));
      expect(surface, isNot(accentHsl.toColor()));
      // The medium faded surface keeps white text legible.
      expect(
        PlannerEventBlockColorPolicy.textColor(
          surface,
          Brightness.dark,
        ),
        Colors.white,
      );
    },
  );

  test('resolved surface keeps the existing surface when the accent is '
      'unchanged and derives a new one when it changes', () {
    const accent = 0xFFA5975F;
    const surface = 0xFF4A4634;
    expect(
      PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
        accentArgb: accent,
        currentAccentArgb: accent,
        currentSurfaceArgb: surface,
      ),
      surface,
    );
    final changed = PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
      accentArgb: 0xFF676DA2,
      currentAccentArgb: accent,
      currentSurfaceArgb: surface,
    );
    expect(changed, isNot(surface));
    expect(
      changed,
      PlannerEventBlockColorPolicy.mutedSurfaceFromAccent(
        const Color(0xFF676DA2),
      ).toARGB32(),
    );
  });
}
