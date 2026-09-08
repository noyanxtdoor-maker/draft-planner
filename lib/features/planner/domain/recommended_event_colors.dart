/// The Next Transfer Recommended Colors palette.
///
/// These are the owner-approved 32 canonical opaque colors surfaced by the
/// shared Recommended Colors action in Event Colors Settings and Edit Event
/// Type. Existing saved defaults and historical occurrence snapshots stay
/// untouched; this vocabulary governs new deliberate selections only.
///
library;

import 'package:rmplanner/core/colors/vs11_color_system.dart';

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
    // The first fifteen preserve the familiar Event recommendation names.
    RecommendedEventColor(
      name: 'Dusty Rose',
      argb: Vs11ColorSystem.p30TaupeGray,
    ),
    RecommendedEventColor(
      name: 'Faded Mauve',
      argb: Vs11ColorSystem.p26OrchidViolet,
    ),
    RecommendedEventColor(
      name: 'Gray Lavender',
      argb: Vs11ColorSystem.p27Mulberry,
    ),
    RecommendedEventColor(
      name: 'Faded Periwinkle',
      argb: Vs11ColorSystem.p24DeepBlue,
    ),
    RecommendedEventColor(
      name: 'Gray Blue',
      argb: Vs11ColorSystem.p22SteelBlue,
    ),
    RecommendedEventColor(
      name: 'Muted Teal',
      argb: Vs11ColorSystem.p18ReferenceTeal,
    ),
    RecommendedEventColor(
      name: 'Grayed Sage',
      argb: Vs11ColorSystem.p14LeafGreen,
    ),
    RecommendedEventColor(
      name: 'Dusty Olive',
      argb: Vs11ColorSystem.p12DeepOlive,
    ),
    RecommendedEventColor(name: 'Dusty Ochre', argb: Vs11ColorSystem.p08Rust),
    RecommendedEventColor(
      name: 'Warm Muted Tan',
      argb: Vs11ColorSystem.p10WarmOchre,
    ),
    RecommendedEventColor(
      name: 'Dusty Peach',
      argb: Vs11ColorSystem.p03TerracottaRose,
    ),
    RecommendedEventColor(
      name: 'Faded Terracotta',
      argb: Vs11ColorSystem.p04PlumBrown,
    ),
    RecommendedEventColor(
      name: 'Muted Violet',
      argb: Vs11ColorSystem.p28OrchidPlum,
    ),
    RecommendedEventColor(
      name: 'Dusty Orchid',
      argb: Vs11ColorSystem.p31LavenderGray,
    ),
    RecommendedEventColor(
      name: 'Gray Mauve',
      argb: Vs11ColorSystem.p29CoolGray,
    ),
    // The remaining owner-approved vocabulary remains selectable before a
    // custom color is needed; it is not a second Event-Type color pool.
    RecommendedEventColor(
      name: 'Rose Ember',
      argb: Vs11ColorSystem.p01RoseEmber,
    ),
    RecommendedEventColor(
      name: 'Dusty Crimson',
      argb: Vs11ColorSystem.p02DustyCrimson,
    ),
    RecommendedEventColor(
      name: 'Burnt Apricot',
      argb: Vs11ColorSystem.p05BurntApricot,
    ),
    RecommendedEventColor(name: 'Copper', argb: Vs11ColorSystem.p06Copper),
    RecommendedEventColor(
      name: 'Ochre Orange',
      argb: Vs11ColorSystem.p07OchreOrange,
    ),
    RecommendedEventColor(
      name: 'Antique Gold',
      argb: Vs11ColorSystem.p09AntiqueGold,
    ),
    RecommendedEventColor(
      name: 'Olive Gold',
      argb: Vs11ColorSystem.p11OliveGold,
    ),
    RecommendedEventColor(name: 'Moss', argb: Vs11ColorSystem.p13Moss),
    RecommendedEventColor(
      name: 'Forest Sage',
      argb: Vs11ColorSystem.p15ForestSage,
    ),
    RecommendedEventColor(
      name: 'Jade Green',
      argb: Vs11ColorSystem.p16JadeGreen,
    ),
    RecommendedEventColor(name: 'Deep Teal', argb: Vs11ColorSystem.p17DeepTeal),
    RecommendedEventColor(
      name: 'Slate Teal',
      argb: Vs11ColorSystem.p19SlateTeal,
    ),
    RecommendedEventColor(name: 'Blue Teal', argb: Vs11ColorSystem.p20BlueTeal),
    RecommendedEventColor(name: 'Denim', argb: Vs11ColorSystem.p21Denim),
    RecommendedEventColor(
      name: 'Indigo Blue',
      argb: Vs11ColorSystem.p23IndigoBlue,
    ),
    RecommendedEventColor(
      name: 'Dusty Violet',
      argb: Vs11ColorSystem.p25DustyViolet,
    ),
    RecommendedEventColor(
      name: 'Slate Gray',
      argb: Vs11ColorSystem.p32SlateGray,
    ),
  ];

  static RecommendedEventColor? byArgb(int argb) {
    for (final color in colors) {
      if (Vs11ColorSystem.sameOpaqueRgb(color.argb, argb)) {
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
    // Calibrated only where an inherited companion failed the locked
    // accent-to-surface perceptual separation floor. The accent values are
    // immutable; retained values are byte-for-byte legacy companions.
    Vs11ColorSystem.p30TaupeGray: 0xFF58464E, // Dusty Rose (retained)
    Vs11ColorSystem.p26OrchidViolet: 0xFF4D444B, // Faded Mauve
    Vs11ColorSystem.p27Mulberry: 0xFF38363F, // Gray Lavender
    Vs11ColorSystem.p24DeepBlue: 0xFF3F434F, // Faded Periwinkle
    Vs11ColorSystem.p22SteelBlue: 0xFF484F56, // Gray Blue (retained)
    Vs11ColorSystem.p18ReferenceTeal: 0xFF373D3E, // Muted Teal
    Vs11ColorSystem.p14LeafGreen: 0xFF4E544A, // Grayed Sage (retained)
    Vs11ColorSystem.p12DeepOlive: 0xFF514F44, // Dusty Olive
    Vs11ColorSystem.p08Rust: 0xFF5B5243, // Dusty Ochre (retained)
    Vs11ColorSystem.p10WarmOchre: 0xFF45403B, // Warm Muted Tan
    Vs11ColorSystem.p03TerracottaRose: 0xFF5A4944, // Dusty Peach (retained)
    Vs11ColorSystem.p04PlumBrown: 0xFF4E423F, // Faded Terracotta
    Vs11ColorSystem.p28OrchidPlum: 0xFF423D4B, // Muted Violet
    Vs11ColorSystem.p31LavenderGray: 0xFF3E363E, // Dusty Orchid
    Vs11ColorSystem.p29CoolGray: 0xFF2D2A2D, // Gray Mauve
  };
}

/// Returns the locked dark main event-block surface partner for an exact
/// Recommended Color accent, or null when the accent is not a palette member.
int? recommendedSurfaceArgbForAccent(int accentArgb) {
  return RecommendedEventColorSurfacePartners.byAccentArgb[accentArgb];
}
