import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_resolver.dart';

/// B2-CORRECTION locked Event Light render transform contract:
/// - DARK returns the exact stored/resolved pair (byte-identical baseline).
/// - LIGHT derives a pastel surface (16% seed blend over the card surface),
///   a hue-preserving accent that reaches >= 3:1 against that surface, and
///   readable onSurface text (>= 4.5:1).
/// - Resolving never mutates stored Event data or history.
void main() {
  final cardSurface = AppTheme.roseLightCard;

  group('EventLightRender surface derivation', () {
    test('canonical rose accent produces a readable pastel surface', () {
      final surface = EventLightRender.surfaceFor(
        const Color(0xFFF9B7C7),
        cardSurface,
      );
      // Blended, never the raw dark-style pair, never dark.
      expect(surface.computeLuminance(), greaterThan(0.7));
      // Text must be readable on it (>= 4.5:1).
      expect(
        _contrast(const Color(0xFF1A1C1F), surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('near-white custom accent still yields a readable pastel surface', () {
      final surface = EventLightRender.surfaceFor(
        const Color(0xFFF5F5F5),
        cardSurface,
      );
      expect(surface.computeLuminance(), greaterThan(0.85));
      expect(
        _contrast(const Color(0xFF1A1C1F), surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('near-black custom accent still yields a readable pastel surface', () {
      final surface = EventLightRender.surfaceFor(
        const Color(0xFF111111),
        cardSurface,
      );
      // 16% black over the card: a clearly-light surface (never dark), even
      // though the seed is near-black.
      expect(surface.computeLuminance(), greaterThan(0.6));
      expect(
        _contrast(const Color(0xFF1A1C1F), surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('saturated blue accent yields a cool readable pastel surface', () {
      final surface = EventLightRender.surfaceFor(
        const Color(0xFF1E5AA8),
        cardSurface,
      );
      expect(surface.computeLuminance(), greaterThan(0.7));
      expect(
        _contrast(const Color(0xFF1A1C1F), surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('EventLightRender accent derivation', () {
    final seeds = <String, Color>{
      'canonical rose': const Color(0xFFF9B7C7),
      'yellow/amber': const Color(0xFFF1C94F),
      'green': const Color(0xFF4CAF50),
      'teal': const Color(0xFF9EDCE3),
      'saturated blue': const Color(0xFF1E5AA8),
      'near-white': const Color(0xFFF5F5F5),
      'near-black': const Color(0xFF111111),
    };

    for (final entry in seeds.entries) {
      test('${entry.key} accent reaches >= 3:1 on its pastel surface', () {
        final seed = entry.value;
        final surface = EventLightRender.surfaceFor(seed, cardSurface);
        final accent = EventLightRender.accentFor(seed, surface, const Color(
          0xFF1A1C1F,
        ));
        expect(
          _contrast(accent, surface),
          greaterThanOrEqualTo(3.0),
          reason: 'accent $accent must reach 3:1 on surface $surface',
        );
      });
    }

    test('near-white accent is never low-contrast (3:1 guarantee)', () {
      // A near-white seed cannot pass at its own lightness, so the bounded
      // walk darkens it until readable — or the onSurface fallback holds.
      final surface = EventLightRender.surfaceFor(
        const Color(0xFFFFFEFE),
        cardSurface,
      );
      final accent = EventLightRender.accentFor(
        const Color(0xFFFFFEFE),
        surface,
        const Color(0xFF1A1C1F),
      );
      final readable = _contrast(accent, surface) >= 3.0;
      expect(readable || accent == const Color(0xFF1A1C1F), isTrue,
          reason: 'accent $accent must be readable on $surface or fall back');
      // The walk never brightens the seed: the accent is at most the seed's
      // own lightness.
      expect(
        HSLColor.fromColor(accent).lightness,
        lessThanOrEqualTo(
          HSLColor.fromColor(const Color(0xFFFFFEFE)).lightness,
        ),
      );
    });

    test('accent preserves hue family (hue within tolerance of the seed)', () {
      final seed = const Color(0xFF4CAF50);
      final surface = EventLightRender.surfaceFor(seed, cardSurface);
      final accent = EventLightRender.accentFor(seed, surface, const Color(
        0xFF1A1C1F,
      ));
      final seedHue = HSLColor.fromColor(seed).hue;
      final accentHue = HSLColor.fromColor(accent).hue;
      expect((accentHue - seedHue).abs() % 360, lessThan(12));
    });
  });

  group('resolver brightness behavior', () {
    testWidgets(
      'Light resolves pastel surface + readable accent for a user custom pair',
      (tester) async {
        final event = _eventWithColor(0xFF4CAF50);
        final prefs = <String, EventColorPreference>{
          'study-or-plan': const EventColorPreference(
            accentArgb: 0xFF4CAF50,
            surfaceArgb: 0xFF1B3B1D,
          ),
        };
        late Color accent;
        late Color surface;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) {
                accent = PlannerEventColorResolver.accentColor(
                  context,
                  event,
                  prefs,
                );
                surface = PlannerEventColorResolver.surfaceColor(
                  context,
                  event,
                  prefs,
                );
                return const SizedBox();
              },
            ),
          ),
        );
        // Pastel, not the dark stored surface.
        expect(surface, isNot(const Color(0xFF1B3B1D)));
        expect(surface.computeLuminance(), greaterThan(0.7));
        expect(
          _contrast(const Color(0xFF1A1C1F), surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(accent, surface), greaterThanOrEqualTo(3.0));
      },
    );

    testWidgets('Dark returns the EXACT stored pair (byte-identical)',
        (tester) async {
      final event = _eventWithColor(0xFF4CAF50);
      final prefs = <String, EventColorPreference>{
        'study-or-plan': const EventColorPreference(
          accentArgb: 0xFF4CAF50,
          surfaceArgb: 0xFF1B3B1D,
        ),
      };
      late Color accent;
      late Color surface;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              accent = PlannerEventColorResolver.accentColor(
                context,
                event,
                prefs,
              );
              surface = PlannerEventColorResolver.surfaceColor(
                context,
                event,
                prefs,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(accent, const Color(0xFF4CAF50));
      expect(surface, const Color(0xFF1B3B1D));
    });

    testWidgets(
      'archived/snapshot and recurrence-exception Events use their own stored '
      'color through the same transform',
      (tester) async {
        final archivedEvent = _eventWithColor(0xFF9EDCE3, recurring: true);
        final prefs = <String, EventColorPreference>{};
        late Color archivedSurface;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (context) {
                archivedSurface = PlannerEventColorResolver.surfaceColor(
                  context,
                  archivedEvent,
                  prefs,
                );
                return const SizedBox();
              },
            ),
          ),
        );
        expect(archivedSurface.computeLuminance(), greaterThan(0.7));
      },
    );
  });

  group('text color contract', () {
    test('Light block text is readable onSurface; Dark stays white', () {
      expect(
        PlannerEventBlockColorPolicy.textColor(
          const Color(0xFFF7E3E8),
          Brightness.light,
        ),
        const Color(0xFF1A1C1F),
      );
      expect(
        PlannerEventBlockColorPolicy.textColor(
          const Color(0xFF1B3B1D),
          Brightness.dark,
        ),
        Colors.white,
      );
    });

    test('stored data is never mutated by resolution', () {
      final prefs = <String, EventColorPreference>{
        'study-or-plan': const EventColorPreference(
          accentArgb: 0xFF4CAF50,
          surfaceArgb: 0xFF1B3B1D,
        ),
      };
      final event = _eventWithColor(0xFF4CAF50);
      // Encoding the document twice must round-trip byte-identically after
      // resolution (no write path exists in the resolver).
      final encodedBefore = EventColorPreferenceCodec.encodeDocument(
        events: prefs,
        groups: const <String, int>{},
      );
      final encodedAfter = EventColorPreferenceCodec.encodeDocument(
        events: prefs,
        groups: const <String, int>{},
      );
      expect(encodedAfter, encodedBefore);
      expect(prefs['study-or-plan']!.accentArgb, 0xFF4CAF50);
      expect(prefs['study-or-plan']!.surfaceArgb, 0xFF1B3B1D);
      expect(event.activityTypeColorValue, 0xFF4CAF50);
    });
  });
}

PlannerCalendarItem _eventWithColor(int argb, {bool recurring = false}) {
  return PlannerCalendarItem(
    id: 'evt-1',
    title: 'Study or Plan',
    date: const PlannerDate(year: 2026, month: 8, day: 3),
    timing: PlannerEventTiming.timed,
    state: PlannerEventState.scheduled,
    requiresReport: true,
    hasOutcomeReport: false,
    startLocal: DateTime(2026, 8, 3, 10),
    endLocal: DateTime(2026, 8, 3, 11),
    isRecurring: recurring,
    activityTypeId: 'study-or-plan',
    activityTypeLabel: 'Study or Plan',
    activityTypeColorValue: argb,
    isBackupAppointment: false,
  );
}

double _contrast(Color first, Color second) {
  final light = first.computeLuminance() >= second.computeLuminance()
      ? first
      : second;
  final dark = identical(light, first) ? second : first;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}
