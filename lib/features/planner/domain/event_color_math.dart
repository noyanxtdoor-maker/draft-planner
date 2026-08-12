import 'dart:math' as math;

/// Deterministic, dependency-free color helpers shared by the recommended
/// palette selection, the custom-hex input, and their tests.
///
/// All functions operate on raw 0xAARRGGBB integers so they stay pure Dart and
/// can be unit-tested without Flutter.
abstract final class EventColorMath {
  /// Converts an ARGB color to a normalized HSL triple (h in [0, 360),
  /// s and l in [0, 1]).
  static ({double h, double s, double l}) toHsl(int argb) {
    final r = ((argb >> 16) & 0xFF) / 255.0;
    final g = ((argb >> 8) & 0xFF) / 255.0;
    final b = (argb & 0xFF) / 255.0;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final delta = max - min;
    double h = 0;
    if (delta != 0) {
      if (max == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (max == g) {
        h = 60 * ((b - r) / delta + 2);
      } else {
        h = 60 * ((r - g) / delta + 4);
      }
    }
    if (h < 0) {
      h += 360;
    }
    final l = (max + min) / 2;
    final s = delta == 0 ? 0.0 : delta / (1 - (2 * l - 1).abs());
    return (h: h, s: s.clamp(0.0, 1.0), l: l.clamp(0.0, 1.0));
  }

  /// Whether a color satisfies the approved light-muted/recommended
  /// constraints: moderate saturation and light-medium lightness, readable on
  /// the app's dark Planner surface.  The band matches the owner-approved
  /// light-muted palette (Part 12): every swatch sits in saturation
  /// 0.29-0.54 and lightness 0.64-0.75, so the bounds are deliberately
  /// generous while still excluding neon, muddy dark, and washed-out grays.
  static bool isMutedAndReadable(
    int argb, {
    double minSaturation = 0.22,
    double maxSaturation = 0.60,
    double minLightness = 0.55,
    double maxLightness = 0.80,
  }) {
    final hsl = toHsl(argb);
    return hsl.s >= minSaturation &&
        hsl.s <= maxSaturation &&
        hsl.l >= minLightness &&
        hsl.l <= maxLightness;
  }

  /// OKLab perceptual color difference (ΔE) between two ARGB colors.
  static double okLabDistance(int a, int b) {
    final labA = _toOkLab(a);
    final labB = _toOkLab(b);
    final dL = labA.l - labB.l;
    final da = labA.a - labB.a;
    final db = labA.b - labB.b;
    return math.sqrt(dL * dL + da * da + db * db);
  }

  /// Two colors are considered indistinguishable on the app's dark surface
  /// when their raw OKLab ΔE falls below this threshold.
  ///
  /// Raw OKLab distances are small (maximum possible across sRGB is roughly
  /// 1.5; JND is around 0.02-0.04), so the value is intentionally far below
  /// CIELAB-style thresholds.  The recommended palette and its tests enforce
  /// a minimum distance of 0.05 from every existing color.
  static bool isNearDuplicate(int a, int b, {double threshold = 0.05}) {
    return okLabDistance(a, b) < threshold;
  }

  /// WCAG relative luminance (0..1) of an ARGB color.
  static double relativeLuminance(int argb) {
    double channel(double value) {
      final normalized = value / 255.0;
      return normalized <= 0.03928
          ? normalized / 12.92
          : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel(((argb >> 16) & 0xFF).toDouble());
    final g = channel(((argb >> 8) & 0xFF).toDouble());
    final b = channel((argb & 0xFF).toDouble());
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// WCAG contrast ratio between two ARGB colors (1..21).
  static double contrastRatio(int a, int b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Whether the color is bright enough to be a legible accent dot on the
  /// dark Event surface.  Used only for the custom-hex warning.
  static bool hasPoorContrastOnDarkSurface(int argb, {double minRatio = 1.4}) {
    return contrastRatio(argb, 0xFF181A1E) < minRatio;
  }

  /// Whether the color is bright enough to glare on the dark interface.
  static bool isExcessivelyBright(int argb, {double maxLuminance = 0.82}) {
    return relativeLuminance(argb) > maxLuminance;
  }

  /// Derives the Event block surface from a light-muted accent (Part 15
  /// PMG tonal discipline).
  ///
  /// The surface is the accent's hue blended into a controlled neutral
  /// gray/charcoal veil:
  ///
  ///   * chroma is cut to at most ~30% saturation;
  ///   * lightness is pushed to a medium-dark band (0.34-0.50) so the block
  ///     separates from the black Planner without reading as a bright card;
  ///   * a final ~22% blend toward the neutral at the same lightness removes
  ///     the last candy/bright residue.
  ///
  /// The result is the approved "faded color block on black": dusty,
  /// desaturated, gray-mixed, comfortable against the dark timeline, and
  /// never near-black muddy.  White text maintains contrast on the medium
  /// surface.  This supersedes the earlier light-muted derivation (Part 11:
  /// "light muted" was insufficient).
  static int lightMutedSurfaceArgb(int argb) {
    final hsl = toHsl(argb);
    final lightness = (hsl.l * 0.62 + 0.10).clamp(0.34, 0.50);
    final saturation = (hsl.s * 0.38).clamp(0.06, 0.30);
    final base = fromHsl(h: hsl.h, s: saturation, l: lightness);
    final neutral = fromHsl(h: hsl.h, s: 0.0, l: lightness);
    const grayMix = 0.22;
    final r =
        ((((base >> 16) & 0xFF) * (1 - grayMix) +
                ((neutral >> 16) & 0xFF) * grayMix))
            .round()
            .clamp(0, 255);
    final g =
        ((((base >> 8) & 0xFF) * (1 - grayMix) +
                ((neutral >> 8) & 0xFF) * grayMix))
            .round()
            .clamp(0, 255);
    final b = (((base & 0xFF) * (1 - grayMix) + (neutral & 0xFF) * grayMix))
        .round()
        .clamp(0, 255);
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }

  /// Converts an HSL triple (h in [0, 360), s and l in [0, 1]) to an
  /// 0xAARRGGBB integer.
  static int fromHsl({
    required double h,
    required double s,
    required double l,
  }) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    final double r;
    final double g;
    final double b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    return 0xFF000000 |
        ((((r + m) * 255).round().clamp(0, 255)) << 16) |
        ((((g + m) * 255).round().clamp(0, 255)) << 8) |
        (((b + m) * 255).round().clamp(0, 255));
  }

  /// Parses a six-digit RGB hex string, with or without a leading '#', into
  /// an 0xAARRGGBB integer.  Returns null for wrong length, non-hex
  /// characters, or alpha/8-digit input.
  static int? parseHex(String input) {
    var value = input.trim();
    if (value.startsWith('#')) {
      value = value.substring(1);
    }
    if (value.length != 6) {
      return null;
    }
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) {
      return null;
    }
    return 0xFF000000 | parsed;
  }

  /// Normalizes a validated RGB value to '#RRGGBB' uppercase.
  static String formatHex(int argb) {
    final rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static ({double l, double a, double b}) _toOkLab(int argb) {
    double channel(double value) {
      final normalized = value / 255.0;
      return normalized <= 0.04045
          ? normalized / 12.92
          : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel(((argb >> 16) & 0xFF).toDouble());
    final g = channel(((argb >> 8) & 0xFF).toDouble());
    final b = channel((argb & 0xFF).toDouble());

    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    final lCbrt = _cbrt(l);
    final mCbrt = _cbrt(m);
    final sCbrt = _cbrt(s);

    return (
      l: 0.2104542553 * lCbrt + 0.7936177850 * mCbrt - 0.0040720468 * sCbrt,
      a: 1.9779984951 * lCbrt - 2.4285922050 * mCbrt + 0.4505937099 * sCbrt,
      b: 0.0259040371 * lCbrt + 0.7827717662 * mCbrt - 0.8086757660 * sCbrt,
    );
  }

  static double _cbrt(double value) =>
      math.pow(value.abs(), 1 / 3).toDouble() * value.sign;
}
