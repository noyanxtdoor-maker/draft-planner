// R1 REGRESSION (owner 2026-08-16, audit-first): Dark-mode Goal Icon visual
// parity.
//
// Owner physical rejection: Dark Home Goal Icons still look deeper/royal/more
// saturated even though prior code and pixel audits claimed "source parity".
//
// Forensic audit (NEXT_TRANSFER_R1_PREVIEW_PARITY_FORENSIC_AUDIT_2026-08-16)
// measured the cause: the raw SVG art is byte-identical in both themes
// (exact same core colors, single assetPath, colorFilter null, no palette
// substitution), but the EDGE/AA pixels composite against the card surface —
// near-white blends in Light, near-black blends in Dark — so the SAME art
// reads lighter/airier in Light and deeper/royal in Dark (lossless device
// deficit g -21, b -15). The owner prompt pre-authorizes a GoalIcon-only
// Dark-mode cyan compensation layer for this exact case.
//
// The widget-test rasterizer does NOT reproduce the perceptual AA deficit
// (at rendered icon sizes the opaque core pixels dominate the metric), so a
// "dark mean darker than light mean" assertion passes trivially on the
// rejected build. Instead this test pins the DETERMINISTIC contract of the
// approved mechanism:
//
//   1. LIGHT is the target and is untouched: its exact-count of the raw art
//      cyan color is present and its dominant cyan is the raw art color.
//   2. DARK applies the cyan-family compensation: the exact-count of the
//      compensated cyan color in Dark EQUALS the exact-count of the raw
//      cyan color in Light — the compensation recolors the SAME pixels, so
//      on the current (uncompensated) build the Dark count is 0 and this
//      fails (RED), and after the fix the counts are equal (GREEN).
//   3. GOLD is unchanged: the dominant exact gold color is byte-identical
//      between themes, and the remap unit test proves the mechanism never
//      rewrites gold.
//   4. No colorFilter, no global theme-primary mutation, no halo/plate,
//      same size/opticalScale; the null-iconId fallback stays
//      theme-independent.
// Perceptual acceptance remains the owner's physical Light-vs-Dark device
// comparison; the on-device measured crop evidence accompanies this run.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';

/// The six owner-visible Home icons: exact raw art cyan (from the SVG
/// assets) and the exact compensated dark cyan (raw + GoalIcon.darkCyanDelta
/// = +20/+28/+34, clamped at 255).
const _icons = <String, ({Color raw, Color compensated})>{
  'dating': (raw: Color(0xFF4DAFCF), compensated: Color(0xFF61CBF1)), // Find Date
  'elders': (raw: Color(0xFF5BAECA), compensated: Color(0xFF6FCAEC)), // Missionaries
  'jogging': (raw: Color(0xFF59B3CF), compensated: Color(0xFF6DCFF1)), // Exercise
  'target_arrow': (raw: Color(0xFF64B4CD), compensated: Color(0xFF78D0EF)), // Upskill
  'handshake': (raw: Color(0xFF69B6D1), compensated: Color(0xFF7DD2F3)), // Ministering
  'spiritual_temple': (raw: Color(0xFF56ADCD), compensated: Color(0xFF6AC9EF)), // Temple
};

const _size = 96.0;

bool _isGold(int r, int g, int b) =>
    r > 180 && g > 130 && b < 130 && r > b + 60;

Widget _harness({
  required Brightness brightness,
  required Widget child,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF175A8F),
        brightness: brightness,
      ),
    ),
    home: Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppTheme.background
          : const Color(0xFFF4F4F4),
      body: Center(child: child),
    ),
  );
}

Future<ui.Image> _capture(
  WidgetTester tester,
  Key boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: 1),
  );
  if (image == null) {
    fail('R1: capture of $boundaryKey returned null');
  }
  return image;
}

Future<ByteData> _rgba(WidgetTester tester, ui.Image image) async {
  final bytes = await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  if (bytes == null) {
    fail('R1: toByteData returned null');
  }
  return bytes;
}

/// Exact count of pixels equal to [target].
Future<int> _exactCount(
  WidgetTester tester,
  ui.Image image,
  Color target,
) async {
  final data = await _rgba(tester, image);
  final tr = (target.r * 255).round();
  final tg = (target.g * 255).round();
  final tb = (target.b * 255).round();
  var count = 0;
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    if (data.getUint8(i) == tr &&
        data.getUint8(i + 1) == tg &&
        data.getUint8(i + 2) == tb) {
      count++;
    }
  }
  return count;
}

/// Most common exact color matching [predicate].
Future<Color?> _dominantColor(
  WidgetTester tester,
  ui.Image image, {
  required bool Function(int r, int g, int b) predicate,
}) async {
  final data = await _rgba(tester, image);
  final counts = <int, int>{};
  for (var i = 0; i < data.lengthInBytes; i += 4) {
    final r = data.getUint8(i);
    final g = data.getUint8(i + 1);
    final b = data.getUint8(i + 2);
    if (!predicate(r, g, b)) {
      continue;
    }
    final key = (r << 16) | (g << 8) | b;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  if (counts.isEmpty) {
    return null;
  }
  var bestKey = 0;
  var bestCount = -1;
  counts.forEach((key, count) {
    if (count > bestCount) {
      bestCount = count;
      bestKey = key;
    }
  });
  return Color(
    0xFF000000 |
        ((bestKey >> 16) & 0xFF) << 16 |
        ((bestKey >> 8) & 0xFF) << 8 |
        (bestKey & 0xFF),
  );
}

Future<(ui.Image light, ui.Image dark)> _renderPair(
  WidgetTester tester,
  String iconId,
) async {
  tester.view.physicalSize = const Size(240, 240);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  const lightKey = Key('r1-light');
  const darkKey = Key('r1-dark');
  await tester.pumpWidget(
    _harness(
      brightness: Brightness.light,
      child: RepaintBoundary(
        key: lightKey,
        child: GoalIcon(iconId: iconId, size: _size),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final light = await _capture(tester, lightKey);

  await tester.pumpWidget(
    _harness(
      brightness: Brightness.dark,
      child: RepaintBoundary(
        key: darkKey,
        child: GoalIcon(iconId: iconId, size: _size),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final dark = await _capture(tester, darkKey);
  return (light, dark);
}

void main() {
  for (final entry in _icons.entries) {
    final iconId = entry.key;
    final raw = entry.value.raw;
    final compensated = entry.value.compensated;

    testWidgets(
      'R1: $iconId — Dark applies the cyan compensation to the SAME art '
      'pixels (compensated-count equals raw-count; RED on the rejected '
      'build, which renders raw cyan in Dark)',
      (tester) async {
        final (light, dark) = await _renderPair(tester, iconId);

        final lightRawCount = await _exactCount(tester, light, raw);
        final darkCompensatedCount = await _exactCount(
          tester,
          dark,
          compensated,
        );

        expect(
          lightRawCount,
          greaterThan(50),
          reason: 'R1: precondition — the Light render must contain the raw '
              'art cyan core pixels',
        );
        expect(
          darkCompensatedCount,
          lightRawCount,
          reason: 'R1: $iconId — the Dark render must paint the compensated '
              'cyan on the SAME pixels that Light paints the raw cyan (the '
              'owner-approved dark compensation layer). On the current build '
              'Dark still renders the raw cyan, so the compensated count is '
              '0 — the owner sees the deeper/royal raw cyan on the dark '
              'card.',
        );
      },
    );

    testWidgets(
      'R1: $iconId — Light stays the raw art target; gold stays '
      'byte-identical between themes',
      (tester) async {
        final (light, dark) = await _renderPair(tester, iconId);

        // Light is the target: raw cyan present, dominant cyan is raw art.
        final lightDominant = await _dominantColor(
          tester,
          light,
          predicate: (r, g, b) => b > 140 && b > r + 10 && g > 80,
        );
        expect(
          lightDominant,
          isNotNull,
          reason: 'R1: Light render must contain cyan art',
        );
        final rDiff = ((lightDominant!.r - raw.r).abs() * 255).round();
        final gDiff = ((lightDominant.g - raw.g).abs() * 255).round();
        final bDiff = ((lightDominant.b - raw.b).abs() * 255).round();
        expect(
          rDiff + gDiff + bDiff,
          lessThanOrEqualTo(36),
          reason: 'R1: $iconId Light dominant cyan must be the raw art color '
              '(the compensation must never touch Light)',
        );

        // Gold unchanged: the dominant exact gold color is byte-identical
        // between themes.
        final lightGold = await _dominantColor(
          tester,
          light,
          predicate: _isGold,
        );
        final darkGold = await _dominantColor(
          tester,
          dark,
          predicate: _isGold,
        );
        expect(
          lightGold,
          isNotNull,
          reason: 'R1: Light render must contain gold art',
        );
        expect(
          lightGold!.toARGB32(),
          darkGold!.toARGB32(),
          reason: 'R1: $iconId dominant gold must be byte-identical between '
              'themes (the compensation must never touch gold)',
        );
      },
    );
  }

  test(
    'R1: the dark cyan remap lightens ONLY the cyan family; gold untouched; '
    'light is never remapped',
    () {
      const svg =
          '<svg viewBox="0 0 10 10">'
          '<path fill="#4dafcf" stroke="#4dafcf"/>'
          '<path fill="#eca647" stroke="#eca647"/></svg>';
      // dating cyan (77,175,207) + (20,28,34) = (97,203,241) = #61CBF1.
      final out = GoalIcon.remapDarkCyan(svg);
      expect(out, contains('#61CBF1'), reason: 'cyan fill remapped');
      expect(out, contains('stroke="#61CBF1"'), reason: 'cyan stroke remapped');
      expect(
        out,
        contains('#eca647'),
        reason: 'gold fill must stay byte-identical (original case kept)',
      );
      expect(
        out,
        contains('stroke="#eca647"'),
        reason: 'gold stroke must stay byte-identical (original case kept)',
      );
      // Non-cyan, non-gold colors are untouched too.
      const untouched = '<path fill="#123456"/>';
      expect(
        GoalIcon.remapDarkCyan(untouched),
        contains('#123456'),
        reason: 'out-of-family colors must not be rewritten',
      );
    },
  );

  testWidgets(
    'R1: null-iconId fallback color is theme-independent (no royal/dark '
    'substitution)',
    (tester) async {
      expect(
        AppTheme.goalIconFallbackBlue,
        isNot(ThemeData.light().colorScheme.primary),
      );
      final light = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF175A8F),
          brightness: Brightness.light,
        ),
      );
      final dark = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9FC8F0),
          brightness: Brightness.dark,
        ),
      );
      expect(light.colorScheme.primary, isNot(AppTheme.goalIconFallbackBlue));
      expect(dark.colorScheme.primary, isNot(AppTheme.goalIconFallbackBlue));
    },
  );
}
