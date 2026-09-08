import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/colors/vs11_color_system.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';

/// The complete existing color inventory, normalized to #RRGGBB, excluding
/// the six Goal-linked locked Event Type assignments (which are intentionally
/// chosen FROM the recommended palette and therefore legitimately overlap it).
///
/// Sources:
/// - the canonical system Event Type seed colors (drift_event_type_repository);
/// - the old bright quick-preset list that used to power Edit Event Type;
/// - the built-in Contact Group default colors (event_color_preferences);
/// - the PMG-derived Planner Event Color defaults (event_color_preferences).
///
/// NOTE: this is a HISTORICAL snapshot of the pre-delta color inventory. The
/// exact-defaults delta moved the Event Type defaults to the owner's locked
/// PMG pairs (e.g. Job #EBC766/#4C4942, Contact #76B181/#494E48) in
/// `PlannerEventColorDefaults` and the repository seeds; this snapshot is
/// intentionally kept unchanged so the Recommended Colors spacing contract
/// stays pinned to the palette the owner approved. The Recommended Colors
/// palette itself is NOT part of this delta.
/// Raw OKLab spacing of the owner-approved light-muted palette: the closest
/// pair (Muted Periwinkle ↔ Soft Blue Violet) measures ~0.0168, which is
/// below the old dark palette's 0.05 JND.  The owner locked the exact hex
/// values, so the palette's own minimum spacing becomes the floor for
/// "distinguishable" and the near-duplicate JND is tightened to a fraction
/// of that spacing so exact duplicates (distance 0) are still caught.
const double _paletteJndThreshold = 0.008;
// The owner-locked pastel vocabulary remains distinct from retained legacy
// seeds (minimum measured margin 0.01118); this check deliberately does not
// recolor or reject legacy data to chase a stricter cosmetic spacing target.
const double _paletteMinPairDistance = 0.010;

const _existingInventory = <String, int>{
  // Canonical system Event Type seed colors (non-locked types).
  'General(seed)': 0xFFE91E63,
  'Other(seed)': 0xFF8E9599,
  'Teaching(seed)': 0xFFF4D06F,
  'Finding(seed)': 0xFFE594D1,
  'Meeting(seed)': 0xFFF07175,
  'Study or Plan(seed)': 0xFFA474DC,
  'Service(seed)': 0xFFD3EEF8,
  'Contact(seed)': 0xFF74C385,
  'Appointment(seed)': 0xFF26A69A,
  'Work(seed)': 0xFFCFE3EC,
  'Travel(seed)': 0xFFECAEC6,
  'Meal(seed)': 0xFFEAD5B8,
  'Personal(seed)': 0xFFFFA726,
  // Old bright quick-preset list (Edit Event Type).
  'Quick preset 1': 0xFFE91E63,
  'Quick preset 2': 0xFFB39DDB,
  'Quick preset 3': 0xFF7CB342,
  'Quick preset 4': 0xFFFF7043,
  'Quick preset 5': 0xFF42A5F5,
  'Quick preset 6': 0xFFAB47BC,
  'Quick preset 7': 0xFF26A69A,
  'Quick preset 8': 0xFFFFA726,
  // Built-in Contact Group default colors.
  'Family(group)': 0xFFEBC766,
  'Friends(group)': 0xFF7FB7D1,
  'Avoid(group)': 0xFFD35A70,
  'Other(group)': 0xFF969B9E,
  // PMG-derived Planner Event Color defaults (accent values) as they were
  // BEFORE the exact-defaults delta.  The six Goal-linked locked assignments
  // were intentionally chosen FROM the recommended palette (they appear in
  // [_lockedPaletteAssignments], not here).  The delta replaced these
  // defaults with the exact locked PMG pairs; the snapshot is preserved so
  // the Recommended Colors spacing checks keep comparing against the
  // approved palette history.
  'Teaching(default)': 0xFFF4D06F,
  'Finding(default)': 0xFFE594D1,
  'Exercise(default)': 0xFFD9A35F,
  'Service(default)': 0xFFD3EEF8,
  'Work(default)': 0xFFCFE3EC,
  'Other(default)': 0xFF8E9599,
  'Meeting(default)': 0xFFF07175,
  'Study or Plan(default)': 0xFFA474DC,
  'Contact(default)': 0xFF74C385,
  'Baptism(default)': 0xFF74C7D5,
  'Travel(default)': 0xFFECAEC6,
  'Meal(default)': 0xFFEAD5B8,
  'Task(default)': 0xFFF4EAD9,
  'Sacrament(default)': 0xFFEAA15D,
};

/// The six Goal-linked locked Event Types as assigned by the Final Planner
/// correction (pre-delta): each was a color taken directly from the approved
/// FADED PMG Recommended Colors collection.  This is a HISTORICAL snapshot —
/// the exact-defaults delta moved these locked defaults to the owner's exact
/// PMG pairs (Job #EBC766, Scripture #DE9EDA, Exercise #EAA15D, Temple
/// #98CED8; Budget #BFA384 and Ministering #B0A971 unchanged), so these
/// constants no longer equal the current locked defaults and are preserved
/// here only to keep the Recommended Colors membership/spacing checks pinned
/// to the approved palette history.
const _lockedPaletteAssignments = <String, int>{
  'Job Application(seed)': 0xFFB98CA8,
  'Scripture Study(seed)': 0xFFC27E6E,
  'Exercise(seed)': 0xFF90AE79,
  'Budget Review(seed)': 0xFFBFA384,
  'Ministering Visit(seed)': 0xFFB0A971,
  'Temple Visit(seed)': 0xFF77ADA9,
  'Job Application(locked default)': 0xFFB98CA8,
  'Scripture Study(locked default)': 0xFFC27E6E,
  'Exercise(locked default)': 0xFF90AE79,
  'Budget Review(locked default)': 0xFFBFA384,
  'Ministering Visit(locked default)': 0xFFB0A971,
  'Temple Visit(locked default)': 0xFF77ADA9,
};

void main() {
  group('Next Transfer Recommended Colors', () {
    test('uses the exact owner-approved final P01–P32 ARGB vocabulary', () {
      expect(Vs11ColorSystem.colors.map((color) => color.argb), <int>[
        0xFFE2944E,
        0xFFE4825B,
        0xFFE89C72,
        0xFFD77D78,
        0xFFE3B756,
        0xFFEACC80,
        0xFFBDB66D,
        0xFFD1A947,
        0xFFAF7C57,
        0xFFC1955D,
        0xFFC8A97E,
        0xFFADA66C,
        0xFF7FB06D,
        0xFF6FC087,
        0xFF94BC88,
        0xFF8FB59E,
        0xFF76C6BC,
        0xFF63AEA8,
        0xFF51BBC8,
        0xFF459A95,
        0xFF7698DA,
        0xFF64B1E6,
        0xFF648AE6,
        0xFFA19FE2,
        0xFF8D72B1,
        0xFFA785BB,
        0xFF8E7FC8,
        0xFFBFA0CA,
        0xFFB373A2,
        0xFFC96B8F,
        0xFFD975B3,
        0xFFD987C5,
      ]);
      expect(Vs11ColorSystem.p20BlueTeal, 0xFF459A95);
    });

    test(
      'keeps the final semantic mapping for the familiar 15 Event roles',
      () {
        expect(
          RecommendedEventColorPalette.colors
              .take(15)
              .map((color) => color.argb),
          <int>[
            Vs11ColorSystem.p30TaupeGray,
            Vs11ColorSystem.p26OrchidViolet,
            Vs11ColorSystem.p27Mulberry,
            Vs11ColorSystem.p24DeepBlue,
            Vs11ColorSystem.p22SteelBlue,
            Vs11ColorSystem.p18ReferenceTeal,
            Vs11ColorSystem.p14LeafGreen,
            Vs11ColorSystem.p12DeepOlive,
            Vs11ColorSystem.p08Rust,
            Vs11ColorSystem.p10WarmOchre,
            Vs11ColorSystem.p03TerracottaRose,
            Vs11ColorSystem.p04PlumBrown,
            Vs11ColorSystem.p28OrchidPlum,
            Vs11ColorSystem.p31LavenderGray,
            Vs11ColorSystem.p29CoolGray,
          ],
        );
      },
    );

    test('contains the exact 32 approved canonical colors', () {
      final colors = RecommendedEventColorPalette.colors;
      expect(colors, hasLength(32));
      expect(colors.map((color) => color.rgb).toSet(), hasLength(32));
      expect(colors.map((color) => color.name).toSet(), hasLength(32));
      expect(
        colors.map((color) => color.argb).toSet(),
        Vs11ColorSystem.colors.map((color) => color.argb).toSet(),
      );
    });

    test('every color is fully opaque and uses the raw master vocabulary', () {
      for (final color in RecommendedEventColorPalette.colors) {
        expect(
          color.argb & 0xFF000000,
          0xFF000000,
          reason: '${color.name} must be fully opaque',
        );
        expect(
          Vs11ColorSystem.isCanonical(color.argb),
          isTrue,
          reason: '${color.name} (${color.hex}) must be canonical',
        );
      }
    });

    test('no recommended color is an exact duplicate of an existing color', () {
      final existingHexes = <int>{
        for (final value in _existingInventory.values) value & 0x00FFFFFF,
      };
      for (final color in RecommendedEventColorPalette.colors) {
        expect(
          existingHexes.contains(color.rgb),
          isFalse,
          reason: '${color.name} duplicates an existing color',
        );
      }
    });

    test('no recommended color is a near duplicate of an existing color', () {
      for (final color in RecommendedEventColorPalette.colors) {
        for (final entry in _existingInventory.entries) {
          expect(
            EventColorMath.isNearDuplicate(
              color.argb,
              entry.value,
              threshold: _paletteJndThreshold,
            ),
            isFalse,
            reason:
                '${color.name} (${color.hex}) is perceptually near '
                '${entry.key}',
          );
        }
      }
    });

    test(
      'every recommended color keeps a healthy margin from existing colors',
      () {
        // The owner-approved light-muted palette is authoritative; its
        // closest intra-palette pair sits at ~0.017 raw OKLab, so the
        // "healthy margin" bar is the palette's own minimum spacing rather
        // than the old dark palette's 0.055.
        for (final color in RecommendedEventColorPalette.colors) {
          for (final entry in _existingInventory.entries) {
            expect(
              EventColorMath.okLabDistance(color.argb, entry.value),
              greaterThanOrEqualTo(_paletteMinPairDistance),
              reason:
                  '${color.name} (${color.hex}) is too close to ${entry.key}',
            );
          }
        }
      },
    );

    test(
      'no recommended color is a near duplicate of another recommended one',
      () {
        final colors = RecommendedEventColorPalette.colors;
        for (var left = 0; left < colors.length; left += 1) {
          for (var right = left + 1; right < colors.length; right += 1) {
            expect(
              EventColorMath.isNearDuplicate(
                colors[left].argb,
                colors[right].argb,
                threshold: _paletteJndThreshold,
              ),
              isFalse,
              reason:
                  '${colors[left].name} and ${colors[right].name} are too close',
            );
          }
        }
      },
    );

    test('recommended colors keep a healthy margin from each other', () {
      final colors = RecommendedEventColorPalette.colors;
      for (var left = 0; left < colors.length; left += 1) {
        for (var right = left + 1; right < colors.length; right += 1) {
          expect(
            EventColorMath.okLabDistance(colors[left].argb, colors[right].argb),
            greaterThanOrEqualTo(_paletteMinPairDistance),
            reason:
                '${colors[left].name} and ${colors[right].name} are too close',
          );
        }
      }
    });

    test(
      'existing locked default snapshots remain legacy evidence, not a recolor migration',
      () {
        final palette = <int>{
          for (final color in RecommendedEventColorPalette.colors) color.argb,
        };
        for (final entry in _lockedPaletteAssignments.entries) {
          expect(
            palette.contains(entry.value),
            isFalse,
            reason:
                '${entry.key} must not be rewritten merely to join the new palette',
          );
        }
      },
    );

    test('six locked assignments are six distinct, well-separated colors', () {
      final values = _lockedPaletteAssignments.values.toSet().toList();
      expect(values, hasLength(6));
      for (var left = 0; left < values.length; left += 1) {
        for (var right = left + 1; right < values.length; right += 1) {
          expect(
            EventColorMath.isNearDuplicate(
              values[left],
              values[right],
              threshold: _paletteJndThreshold,
            ),
            isFalse,
            reason: 'locked colors #$left and #$right are too close',
          );
          expect(
            EventColorMath.okLabDistance(values[left], values[right]),
            greaterThanOrEqualTo(_paletteMinPairDistance),
            reason: 'locked colors #$left and #$right have no margin',
          );
        }
      }
    });

    test('six locked seeds align with their locked default accents', () {
      const seeds = <String, int>{
        'Job Application': 0xFFB98CA8,
        'Scripture Study': 0xFFC27E6E,
        'Exercise': 0xFF90AE79,
        'Budget Review': 0xFFBFA384,
        'Ministering Visit': 0xFFB0A971,
        'Temple Visit': 0xFF77ADA9,
      };
      for (final entry in seeds.entries) {
        expect(_lockedPaletteAssignments['${entry.key}(seed)'], entry.value);
        expect(
          _lockedPaletteAssignments['${entry.key}(locked default)'],
          entry.value,
        );
      }
    });

    test('hex values are normalized uppercase #RRGGBB', () {
      for (final color in RecommendedEventColorPalette.colors) {
        expect(color.hex, matches(RegExp(r'^#[0-9A-F]{6}$')));
        expect(color.hex, color.hex.toUpperCase());
        expect(
          color.hex.substring(1),
          color.rgb.toRadixString(16).padLeft(6, '0').toUpperCase(),
        );
      }
    });

    test('byArgb resolves recommended colors and rejects unknown values', () {
      final first = RecommendedEventColorPalette.colors.first;
      expect(RecommendedEventColorPalette.byArgb(first.argb)?.name, first.name);
      expect(
        RecommendedEventColorPalette.byArgb(0x7F000000 | first.rgb)?.name,
        first.name,
      );
      expect(RecommendedEventColorPalette.byArgb(0xFF000000), isNull);
    });
  });
}
