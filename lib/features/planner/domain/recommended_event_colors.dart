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
