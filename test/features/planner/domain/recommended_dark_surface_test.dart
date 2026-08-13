import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// Locked dark-surface correction contract (correction pack 02 + 03):
/// - exactly 15 explicit accent -> dark surface partners, 1:1 with the
///   RecommendedEventColorPalette;
/// - every mapped surface: relative luminance <= 0.10, white-text contrast
///   >= 7.0:1, accent-vs-surface OKLab dE >= 0.20;
/// - resolvedSurfaceArgb: unchanged accent preserves the current surface;
///   a changed recommended accent resolves its mapped dark partner; a
///   non-recommended accent keeps the previous generic derivation;
/// - fallback surface resolution (mutedSurfaceFromAccent / surfaceColor)
///   maps a recommended accent to the same dark partner.
void main() {
  group('recommended dark surface partners', () {
    test('every palette accent has exactly one dark surface partner', () {
      final partners = RecommendedEventColorSurfacePartners.byAccentArgb;
      expect(partners, hasLength(15));
      expect(partners, hasLength(RecommendedEventColorPalette.colors.length));
      // No duplicate accent keys and no orphan partners: the key set is
      // exactly the palette's accent set.
      expect(partners.keys.toSet(), hasLength(partners.length));
      for (final accentArgb in partners.keys) {
        expect(
          RecommendedEventColorPalette.byArgb(accentArgb),
          isNotNull,
          reason: 'every partner accent must be a palette member '
              '(no orphan/foreign accent)',
        );
      }
      for (final color in RecommendedEventColorPalette.colors) {
        expect(
          recommendedSurfaceArgbForAccent(color.argb),
          isNotNull,
          reason: '${color.name} must have exactly one dark partner',
        );
      }
      // A non-palette accent has no partner.
      expect(recommendedSurfaceArgbForAccent(0xFF123456), isNull);
      expect(recommendedSurfaceArgbForAccent(0xFF000000), isNull);
    });

    test('all 15 mapped surfaces satisfy the dark quality floor', () {
      for (final color in RecommendedEventColorPalette.colors) {
        final surfaceArgb = recommendedSurfaceArgbForAccent(color.argb)!;
        expect(
          EventColorMath.relativeLuminance(surfaceArgb),
          lessThanOrEqualTo(0.10),
          reason: '${color.name} surface must be dark (lum <= 0.10)',
        );
        expect(
          EventColorMath.contrastRatio(0xFFFFFFFF, surfaceArgb),
          greaterThanOrEqualTo(7.0),
          reason: '${color.name} surface must keep white text contrast '
              '>= 7.0:1',
        );
        expect(
          EventColorMath.okLabDistance(color.argb, surfaceArgb),
          greaterThanOrEqualTo(0.20),
          reason: '${color.name} accent must separate from its surface '
              '(OKLab dE >= 0.20)',
        );
      }
    });
  });

  group('color policy chokepoint', () {
    test('a changed recommended accent resolves its exact mapped dark '
        'surface', () {
      final target = RecommendedEventColorPalette.colors.first;
      final resolved = PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
        accentArgb: target.argb,
        currentAccentArgb: 0xFF123456,
        currentSurfaceArgb: 0xFFABCDEF,
      );
      expect(resolved, recommendedSurfaceArgbForAccent(target.argb));
      expect(resolved, isNot(0xFFABCDEF));
    });

    test('an unchanged accent preserves the current surface verbatim even '
        'for a recommended accent', () {
      const accentArgb = 0xFFC98BA7; // Dusty Rose — palette member.
      const currentSurfaceArgb = 0xFF112233;
      expect(
        PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
          accentArgb: accentArgb,
          currentAccentArgb: accentArgb,
          currentSurfaceArgb: currentSurfaceArgb,
        ),
        currentSurfaceArgb,
      );
    });

    test('a non-recommended accent keeps the previous generic derivation', () {
      const accentArgb = 0xFF676DA2;
      final resolved = PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
        accentArgb: accentArgb,
        currentAccentArgb: 0xFFA5975F,
        currentSurfaceArgb: 0xFF4A4634,
      );
      expect(
        resolved,
        PlannerEventBlockColorPolicy.mutedSurfaceFromAccent(
          const Color(accentArgb),
        ).toARGB32(),
      );
      // The generic path must still be the unchanged light-muted derivation.
      expect(
        resolved,
        EventColorMath.lightMutedSurfaceArgb(accentArgb),
      );
    });

    test('fallback surface resolution maps a recommended accent to its '
        'mapped dark partner', () {
      final target = RecommendedEventColorPalette.colors[6]; // Grayed Sage.
      final expected = recommendedSurfaceArgbForAccent(target.argb);
      expect(
        PlannerEventBlockColorPolicy.mutedSurfaceFromAccent(
          Color(target.argb),
        ).toARGB32(),
        expected,
      );
      expect(
        PlannerEventBlockColorPolicy.surfaceColor(
          Color(target.argb),
        ).toARGB32(),
        expected,
      );
    });
  });
}
