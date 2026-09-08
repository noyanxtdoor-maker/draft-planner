/// The owner-approved, opaque VS-11 identity-color vocabulary.
///
/// This is deliberately a raw-ARGB vocabulary rather than a persistence
/// format. Existing Groups, Event Type preferences, and historic occurrence
/// snapshots continue to store their original raw ARGB values unchanged.
library;

final class Vs11CanonicalColor {
  const Vs11CanonicalColor({
    required this.id,
    required this.name,
    required this.argb,
  });

  final String id;
  final String name;
  final int argb;
}

abstract final class Vs11ColorSystem {
  static const int p01RoseEmber = 0xFFE2944E;
  static const int p02DustyCrimson = 0xFFE4825B;
  static const int p03TerracottaRose = 0xFFE89C72;
  static const int p04PlumBrown = 0xFFD77D78;
  static const int p05BurntApricot = 0xFFE3B756;
  static const int p06Copper = 0xFFEACC80;
  static const int p07OchreOrange = 0xFFBDB66D;
  static const int p08Rust = 0xFFD1A947;
  static const int p09AntiqueGold = 0xFFAF7C57;
  static const int p10WarmOchre = 0xFFC1955D;
  static const int p11OliveGold = 0xFFC8A97E;
  static const int p12DeepOlive = 0xFFADA66C;
  static const int p13Moss = 0xFF7FB06D;
  static const int p14LeafGreen = 0xFF6FC087;
  static const int p15ForestSage = 0xFF94BC88;
  static const int p16JadeGreen = 0xFF8FB59E;
  static const int p17DeepTeal = 0xFF76C6BC;
  static const int p18ReferenceTeal = 0xFF63AEA8;
  static const int p19SlateTeal = 0xFF51BBC8;
  static const int p20BlueTeal = 0xFF459A95;
  static const int p21Denim = 0xFF7698DA;
  static const int p22SteelBlue = 0xFF64B1E6;
  static const int p23IndigoBlue = 0xFF648AE6;
  static const int p24DeepBlue = 0xFFA19FE2;
  static const int p25DustyViolet = 0xFF8D72B1;
  static const int p26OrchidViolet = 0xFFA785BB;
  static const int p27Mulberry = 0xFF8E7FC8;
  static const int p28OrchidPlum = 0xFFBFA0CA;
  static const int p29CoolGray = 0xFFB373A2;
  static const int p30TaupeGray = 0xFFC96B8F;
  static const int p31LavenderGray = 0xFFD975B3;
  static const int p32SlateGray = 0xFFD987C5;

  static const List<Vs11CanonicalColor> colors = <Vs11CanonicalColor>[
    Vs11CanonicalColor(id: 'P01', name: 'Rose ember', argb: p01RoseEmber),
    Vs11CanonicalColor(id: 'P02', name: 'Dusty crimson', argb: p02DustyCrimson),
    Vs11CanonicalColor(
      id: 'P03',
      name: 'Terracotta rose',
      argb: p03TerracottaRose,
    ),
    Vs11CanonicalColor(id: 'P04', name: 'Plum brown', argb: p04PlumBrown),
    Vs11CanonicalColor(id: 'P05', name: 'Burnt apricot', argb: p05BurntApricot),
    Vs11CanonicalColor(id: 'P06', name: 'Copper', argb: p06Copper),
    Vs11CanonicalColor(id: 'P07', name: 'Ochre orange', argb: p07OchreOrange),
    Vs11CanonicalColor(id: 'P08', name: 'Rust', argb: p08Rust),
    Vs11CanonicalColor(id: 'P09', name: 'Antique gold', argb: p09AntiqueGold),
    Vs11CanonicalColor(id: 'P10', name: 'Warm ochre', argb: p10WarmOchre),
    Vs11CanonicalColor(id: 'P11', name: 'Olive gold', argb: p11OliveGold),
    Vs11CanonicalColor(id: 'P12', name: 'Deep olive', argb: p12DeepOlive),
    Vs11CanonicalColor(id: 'P13', name: 'Moss', argb: p13Moss),
    Vs11CanonicalColor(id: 'P14', name: 'Leaf green', argb: p14LeafGreen),
    Vs11CanonicalColor(id: 'P15', name: 'Forest sage', argb: p15ForestSage),
    Vs11CanonicalColor(id: 'P16', name: 'Jade green', argb: p16JadeGreen),
    Vs11CanonicalColor(id: 'P17', name: 'Deep teal', argb: p17DeepTeal),
    Vs11CanonicalColor(
      id: 'P18',
      name: 'Reference teal',
      argb: p18ReferenceTeal,
    ),
    Vs11CanonicalColor(id: 'P19', name: 'Slate teal', argb: p19SlateTeal),
    Vs11CanonicalColor(id: 'P20', name: 'Blue teal', argb: p20BlueTeal),
    Vs11CanonicalColor(id: 'P21', name: 'Denim', argb: p21Denim),
    Vs11CanonicalColor(id: 'P22', name: 'Steel blue', argb: p22SteelBlue),
    Vs11CanonicalColor(id: 'P23', name: 'Indigo blue', argb: p23IndigoBlue),
    Vs11CanonicalColor(id: 'P24', name: 'Deep blue', argb: p24DeepBlue),
    Vs11CanonicalColor(id: 'P25', name: 'Dusty violet', argb: p25DustyViolet),
    Vs11CanonicalColor(id: 'P26', name: 'Orchid violet', argb: p26OrchidViolet),
    Vs11CanonicalColor(id: 'P27', name: 'Mulberry', argb: p27Mulberry),
    Vs11CanonicalColor(id: 'P28', name: 'Orchid plum', argb: p28OrchidPlum),
    Vs11CanonicalColor(id: 'P29', name: 'Cool gray', argb: p29CoolGray),
    Vs11CanonicalColor(id: 'P30', name: 'Taupe gray', argb: p30TaupeGray),
    Vs11CanonicalColor(id: 'P31', name: 'Lavender gray', argb: p31LavenderGray),
    Vs11CanonicalColor(id: 'P32', name: 'Slate gray', argb: p32SlateGray),
  ];

  /// Comparison law for all uniqueness checks. Storage remains raw ARGB.
  static int opaqueRgb(int argb) => 0xFF000000 | (argb & 0x00FFFFFF);

  static bool sameOpaqueRgb(int left, int right) =>
      opaqueRgb(left) == opaqueRgb(right);

  static bool isCanonical(int argb) =>
      colors.any((color) => sameOpaqueRgb(color.argb, argb));

  static Vs11CanonicalColor? byOpaqueRgb(int argb) {
    for (final color in colors) {
      if (sameOpaqueRgb(color.argb, argb)) {
        return color;
      }
    }
    return null;
  }

  static int? nextUnused(Iterable<int> usedColors) {
    final used = usedColors.map(opaqueRgb).toSet();
    for (final color in colors) {
      if (!used.contains(color.argb)) {
        return color.argb;
      }
    }
    return null;
  }
}
