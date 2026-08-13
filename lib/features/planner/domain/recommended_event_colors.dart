/// The Next Transfer Recommended Colors palette.
///
/// These are the 15 colors surfaced by the shared Recommended Colors action
/// in Event Colors Settings and Edit Event Type.  Every value follows the
/// PMG tonal discipline (Final Planner correction, Part 14): dusty, faded,
/// gray-mixed, and comfortable on the black Planner — never fresh green,
/// candy pastel, neon, or muddy.  The six fixed Goal-linked Event Types are
/// assigned from this same palette so the whole Planner belongs to one
/// coherent faded family.
///
/// The exact ordered list (5 columns x 3 rows) is locked:
///
///   Row 1: Dusty Rose, Faded Mauve, Gray Lavender, Faded Periwinkle,
///          Gray Blue
///   Row 2: Muted Teal, Grayed Sage, Dusty Olive, Dusty Ochre,
///          Warm Muted Tan
///   Row 3: Dusty Peach, Faded Terracotta, Muted Violet, Dusty Orchid,
///          Gray Mauve
library;

final class RecommendedEventColor {
  const RecommendedEventColor({required this.name, required this.argb});

  final String name;

  /// 0xAARRGGBB.
  final int argb;

  int get rgb => argb & 0x00FFFFFF;

  String get hex => _formatHex(rgb);

  static String _formatHex(int rgb) {
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

abstract final class RecommendedEventColorPalette {
  static const List<RecommendedEventColor> colors = <RecommendedEventColor>[
    RecommendedEventColor(name: 'Dusty Rose', argb: 0xFFC98BA7),
    RecommendedEventColor(name: 'Faded Mauve', argb: 0xFFB98CA8),
    RecommendedEventColor(name: 'Gray Lavender', argb: 0xFFA99BC9),
    RecommendedEventColor(name: 'Faded Periwinkle', argb: 0xFF9CA7D4),
    RecommendedEventColor(name: 'Gray Blue', argb: 0xFF8FA8C4),
    RecommendedEventColor(name: 'Muted Teal', argb: 0xFF77ADA9),
    RecommendedEventColor(name: 'Grayed Sage', argb: 0xFF90AE79),
    RecommendedEventColor(name: 'Dusty Olive', argb: 0xFFB0A971),
    RecommendedEventColor(name: 'Dusty Ochre', argb: 0xFFC8A15E),
    RecommendedEventColor(name: 'Warm Muted Tan', argb: 0xFFBFA384),
    RecommendedEventColor(name: 'Dusty Peach', argb: 0xFFD39A8A),
    RecommendedEventColor(name: 'Faded Terracotta', argb: 0xFFC27E6E),
    RecommendedEventColor(name: 'Muted Violet', argb: 0xFFA98FC9),
    RecommendedEventColor(name: 'Dusty Orchid', argb: 0xFFC08FB8),
    RecommendedEventColor(name: 'Gray Mauve', argb: 0xFFBE98AB),
  ];

  static RecommendedEventColor? byArgb(int argb) {
    for (final color in colors) {
      if (color.argb == argb) {
        return color;
      }
    }
    return null;
  }
}

/// Locked dark main event-block surface partners for the 15 Recommended
/// Colors (dark-surface correction, 2026-08-13).
///
/// The owner requires every Recommended Color to auto-resolve a consistently
/// DARK block surface with the accent clearly visible, in both Edit Event
/// Type and Settings -> Colors.  These partners are the accepted dark PMG
/// family (surface HSL lightness ~0.26-0.31, white-text contrast >= 7.0:1,
/// accent-vs-surface OKLab distance >= 0.20).  The table is keyed by the
/// exact palette accent so one accent always resolves to one surface, and it
/// stays co-located with the palette so the two can never desync.
///
/// The accent values are the locked Recommended palette values and are never
/// hand-tuned here.
abstract final class RecommendedEventColorSurfacePartners {
  static const Map<int, int> byAccentArgb = <int, int>{
    0xFFC98BA7: 0xFF58464E, // Dusty Rose
    0xFFB98CA8: 0xFF544A51, // Faded Mauve
    0xFFA99BC9: 0xFF4D4856, // Gray Lavender
    0xFF9CA7D4: 0xFF464A58, // Faded Periwinkle
    0xFF8FA8C4: 0xFF484F56, // Gray Blue
    0xFF77ADA9: 0xFF4A5454, // Muted Teal
    0xFF90AE79: 0xFF4E544A, // Grayed Sage
    0xFFB0A971: 0xFF565448, // Dusty Olive
    0xFFC8A15E: 0xFF5B5243, // Dusty Ochre
    0xFFBFA384: 0xFF575048, // Warm Muted Tan
    0xFFD39A8A: 0xFF5A4944, // Dusty Peach
    0xFFC27E6E: 0xFF584946, // Faded Terracotta
    0xFFA98FC9: 0xFF4E4758, // Muted Violet
    0xFFC08FB8: 0xFF554954, // Dusty Orchid
    0xFFBE98AB: 0xFF544A4F, // Gray Mauve
  };
}

/// Returns the locked dark main event-block surface partner for an exact
/// Recommended Color accent, or null when the accent is not a palette member.
int? recommendedSurfaceArgbForAccent(int accentArgb) {
  return RecommendedEventColorSurfacePartners.byAccentArgb[accentArgb];
}
