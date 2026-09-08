import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';
import 'package:rmplanner/features/planner/presentation/event_type_form_screen.dart';
import 'package:rmplanner/features/planner/presentation/widgets/event_color_picker_components.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_preview.dart';

import '../../../support/test_dependencies.dart';

const _customTypeId = 'custom-edit-color-test';
const _customTypeLabel = 'Custom Color Test';
const _customStableKey = 'custom:$_customTypeId';

const _seedAccent = 0xFF77ADA9; // Muted Teal (Recommended palette member).
// A realistic saved pair: the surface equals the canonical derivation
// (lightMutedSurfaceArgb of the accent), so the repository's read-side
// light-muted surface repair keeps it verbatim.
final int _seedSurface = EventColorMath.lightMutedSurfaceArgb(_seedAccent);

// A deliberately non-derived "curated" surface used to prove the PANEL keeps
// an unchanged accent's surface untouched (the repository heals custom-type
// curated surfaces on read, so this case is exercised directly on the panel).
const _curatedSurface = 0xFF112233;

PlannerEventColorPreview _preview(WidgetTester tester) {
  return tester.widget<PlannerEventColorPreview>(
    find.byType(PlannerEventColorPreview),
  );
}

/// Pumps the panel in isolation with a StatefulBuilder so tap-to-draft
/// behavior is observable without the full app.
Future<void> _pumpPanel(
  WidgetTester tester, {
  required EventColorPreference currentPreference,
  required Color initialColor,
}) async {
  var draft = initialColor;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => EventTypeColorPanel(
            eventTypeLabel: 'Sample',
            currentPreference: currentPreference,
            initialColor: draft,
            onColorChanged: (color) => setState(() => draft = color),
          ),
        ),
      ),
    ),
  );
}

Future<(AppDatabase, String)> _bootstrap(
  WidgetTester tester, {
  Future<void> Function(AppDatabase database, String profileId)? seed,
}) async {
  tester.view.physicalSize = const Size(393, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final database = openMemoryDatabase();
  addTearDown(database.close);
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  final profile = await startup.completeOnboarding();
  if (seed != null) {
    // Seed BEFORE pumping so the Event Type controller loads the custom
    // Event Type and its saved color preference into its initial state.
    await seed(database, profile.id);
  }
  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
    ),
  );
  await tester.pumpAndSettle();
  return (database, profile.id);
}

Future<void> _seedCustomTypeWithColor(
  AppDatabase database,
  String profileId,
) async {
  final repo = DriftEventTypeRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 8, 13, 12)),
  );
  await repo.saveCustomType(
    profileId: profileId,
    draft: const EventTypeDraft(
      id: _customTypeId,
      label: _customTypeLabel,
      icon: EventTypeIcon.calendar,
      colorValue: _seedAccent,
      reportRequiredDefault: false,
      defaultDurationMinutes: 60,
      indicatorKeys: <String>{},
    ),
  );
  await repo.saveEventColorPreference(
    profileId: profileId,
    eventTypeStableKey: _customStableKey,
    preference: EventColorPreference(
      accentArgb: _seedAccent,
      surfaceArgb: _seedSurface,
    ),
  );
}

Future<void> _openCustomTypeEdit(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(
    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            const EventTypeFormScreen.edit(eventTypeId: _customTypeId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Edit Event Type'), findsOneWidget);
}

/// The Edit Event Type form is a lazy ListView: only visible children are
/// built, so every interaction scrolls the target into view first.
Future<void> _scrollFormTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tapRecommendedSwatch(WidgetTester tester, int index) async {
  final color = RecommendedEventColorPalette.colors[index];
  final finder = find.byKey(Key('recommended-event-color-${color.name}'));
  await _scrollFormTo(
    tester,
    find.byKey(const Key('recommended-colors-inline')),
  );
  await _scrollFormTo(tester, finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await _scrollFormTo(tester, find.byKey(const Key('save-custom-event-type')));
  await tester.tap(find.byKey(const Key('save-custom-event-type')));
  await tester.pumpAndSettle();
}

void main() {
  group('EventTypeColorPanel (direct)', () {
    testWidgets('shows Event Block Color, the inline 32-color Recommended Colors '
        'group, and no recommended-modal trigger', (tester) async {
      await _pumpPanel(
        tester,
        currentPreference: EventColorPreference(
          accentArgb: _seedAccent,
          surfaceArgb: _seedSurface,
        ),
        initialColor: const Color(_seedAccent),
      );

      expect(find.text('Event Block Color'), findsOneWidget);
      expect(find.text('Recommended Colors'), findsOneWidget);
      expect(
        find.byKey(const Key('recommended-colors-inline')),
        findsOneWidget,
      );
      for (final color in RecommendedEventColorPalette.colors) {
        expect(
          find.byKey(Key('recommended-event-color-${color.name}')),
          findsOneWidget,
          reason: '${color.name} must be an inline swatch',
        );
      }
      // The old modal-trigger row is retired from this screen.
      expect(find.byKey(const Key('event-type-color-row')), findsNothing);
      expect(
        find.byKey(const Key('recommended-event-colors-dialog')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recommended-colors-inline')),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(RecommendedEventColorPalette.colors.length + 1),
        reason:
            'the legacy custom draft stays visible beside all 32 canonical choices',
      );
      // No separate main-block/surface picker exists on this screen.
      expect(find.text('Event background'), findsNothing);
    });

    testWidgets(
      'preserves the current curated surface while the accent is unchanged',
      (tester) async {
        await _pumpPanel(
          tester,
          currentPreference: const EventColorPreference(
            accentArgb: _seedAccent,
            surfaceArgb: _curatedSurface,
          ),
          initialColor: const Color(_seedAccent),
        );

        final preview = _preview(tester);
        expect(preview.preference.accentArgb, _seedAccent);
        expect(
          preview.preference.surfaceArgb,
          _curatedSurface,
          reason: 'an unchanged accent must keep its curated surface exactly',
        );
      },
    );

    testWidgets(
      'derives the surface through the existing policy when the accent '
      'changes',
      (tester) async {
        final target = RecommendedEventColorPalette.colors.first;
        await _pumpPanel(
          tester,
          currentPreference: const EventColorPreference(
            accentArgb: _seedAccent,
            surfaceArgb: _curatedSurface,
          ),
          initialColor: Color(target.argb),
        );

        final preview = _preview(tester);
        final expectedSurface =
            PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
              accentArgb: target.argb,
              currentAccentArgb: _seedAccent,
              currentSurfaceArgb: _curatedSurface,
            );
        expect(preview.preference.accentArgb, target.argb);
        expect(preview.preference.surfaceArgb, expectedSurface);
        expect(
          expectedSurface,
          isNot(_curatedSurface),
          reason: 'a changed accent must derive a new surface',
        );
      },
    );
    testWidgets(
      'tapping an inline swatch immediately updates the draft accent and the '
      'preview',
      (tester) async {
        await _pumpPanel(
          tester,
          currentPreference: EventColorPreference(
            accentArgb: _seedAccent,
            surfaceArgb: _seedSurface,
          ),
          initialColor: const Color(_seedAccent),
        );

        await tester.tap(
          find.byKey(const Key('recommended-event-color-Dusty Rose')),
        );
        await tester.pump();

        final preview = _preview(tester);
        expect(preview.preference.accentArgb, 0xFFC96B8F);
        final expectedSurface =
            PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
              accentArgb: 0xFFC96B8F,
              currentAccentArgb: _seedAccent,
              currentSurfaceArgb: _seedSurface,
            );
        expect(preview.preference.surfaceArgb, expectedSurface);
      },
    );
  });

  group('Edit Event Type (full app)', () {
    testWidgets(
      'Save persists the selected accent + resolved surface and the form '
      'round-trips',
      (tester) async {
        final (database, profileId) = await _bootstrap(
          tester,
          seed: _seedCustomTypeWithColor,
        );
        await _openCustomTypeEdit(tester);

        final target = RecommendedEventColorPalette.colors.first;
        await _tapRecommendedSwatch(tester, 0);
        final expectedSurface =
            PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
              accentArgb: target.argb,
              currentAccentArgb: _seedAccent,
              currentSurfaceArgb: _seedSurface,
            );

        await _save(tester);

        final row = await database
            .select(database.plannerPreferences)
            .getSingleOrNull();
        final saved = EventColorPreferenceCodec.decode(
          row?.eventColorPreferencesJson,
        )[_customStableKey];
        expect(saved?.accentArgb, target.argb);
        expect(saved?.surfaceArgb, expectedSurface);
      },
    );

    testWidgets(
      'Custom Hex Apply updates the draft and preview; Save round-trips',
      (tester) async {
        final (database, profileId) = await _bootstrap(
          tester,
          seed: _seedCustomTypeWithColor,
        );
        await _openCustomTypeEdit(tester);

        await _scrollFormTo(
          tester,
          find.byKey(const Key('event-color-custom-hex-action')),
        );
        await tester.tap(
          find.byKey(const Key('event-color-custom-hex-action')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('custom-hex-color-dialog')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('custom-hex-input')),
          'A1B2C3',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('custom-hex-apply')));
        await tester.pumpAndSettle();

        final preview = _preview(tester);
        expect(preview.preference.accentArgb, 0xFFA1B2C3);
        final expectedSurface =
            PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
              accentArgb: 0xFFA1B2C3,
              currentAccentArgb: _seedAccent,
              currentSurfaceArgb: _seedSurface,
            );
        expect(preview.preference.surfaceArgb, expectedSurface);

        await _save(tester);

        final row = await database
            .select(database.plannerPreferences)
            .getSingleOrNull();
        final saved = EventColorPreferenceCodec.decode(
          row?.eventColorPreferencesJson,
        )[_customStableKey];
        expect(saved?.accentArgb, 0xFFA1B2C3);
        expect(saved?.surfaceArgb, expectedSurface);
      },
    );

    testWidgets('Custom Hex Cancel keeps the draft unchanged', (tester) async {
      await _bootstrap(tester, seed: _seedCustomTypeWithColor);
      await _openCustomTypeEdit(tester);

      await _scrollFormTo(
        tester,
        find.byKey(const Key('event-color-custom-hex-action')),
      );
      await tester.tap(find.byKey(const Key('event-color-custom-hex-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom-hex-input')),
        'FF00FF',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('custom-hex-cancel')));
      await tester.pumpAndSettle();

      expect(
        _preview(tester).preference.accentArgb,
        _seedAccent,
        reason: 'Cancel must not mutate the draft accent',
      );
    });

    testWidgets(
      'HSV Color Palette remains available and its Cancel is non-mutating',
      (tester) async {
        await _bootstrap(tester, seed: _seedCustomTypeWithColor);
        await _openCustomTypeEdit(tester);

        await _scrollFormTo(
          tester,
          find.byKey(const Key('event-color-palette-action')),
        );
        await tester.tap(find.byKey(const Key('event-color-palette-action')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('planner-event-color-picker')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('planner-event-color-cancel')));
        await tester.pumpAndSettle();
        expect(_preview(tester).preference.accentArgb, _seedAccent);
      },
    );

    testWidgets(
      'fixed Goal-linked Event Type keeps the fixed assignment and saves the '
      'chosen combined style',
      (tester) async {
        final (database, profileId) = await _bootstrap(tester);

        final context = tester.element(find.byType(Scaffold).first);
        unawaited(
          Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => const EventTypeFormScreen.edit(
                eventTypeId: SystemEventTypeIds.templeVisit,
                fixedAssignmentLabel: 'Temple Visit Goal',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Event Type'), findsOneWidget);
        expect(find.text('Fixed Goal Assignment'), findsOneWidget);
        expect(find.text('This assignment cannot be changed.'), findsOneWidget);
        expect(find.text('Assigned Goal: Temple Visit Goal'), findsOneWidget);
        await _scrollFormTo(
          tester,
          find.byKey(const Key('recommended-colors-inline')),
        );
        expect(find.text('Event Block Color'), findsOneWidget);
        expect(find.text('Recommended Colors'), findsOneWidget);
        expect(
          find.byKey(const Key('recommended-colors-inline')),
          findsOneWidget,
        );

        // Unchanged accent previews the locked curated default pair exactly.
        final preview = _preview(tester);
        expect(
          preview.preference.accentArgb,
          PlannerEventColorDefaults.lockedTempleVisit.accentArgb,
        );
        expect(
          preview.preference.surfaceArgb,
          PlannerEventColorDefaults.lockedTempleVisit.surfaceArgb,
        );

        final target = RecommendedEventColorPalette.colors[1]; // Faded Mauve.
        await _tapRecommendedSwatch(tester, 1);
        final expectedSurface =
            PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
              accentArgb: target.argb,
              currentAccentArgb:
                  PlannerEventColorDefaults.lockedTempleVisit.accentArgb,
              currentSurfaceArgb:
                  PlannerEventColorDefaults.lockedTempleVisit.surfaceArgb,
            );

        await _save(tester);

        final row = await database
            .select(database.plannerPreferences)
            .getSingleOrNull();
        final saved = EventColorPreferenceCodec.decode(
          row?.eventColorPreferencesJson,
        )[SystemEventTypeKeys.templeVisit];
        expect(saved?.accentArgb, target.argb);
        expect(saved?.surfaceArgb, expectedSurface);
        // The form popped back after saving; the fixed block is gone.
        expect(find.text('Fixed Goal Assignment'), findsNothing);
      },
    );
  });
}
