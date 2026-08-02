import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_preview.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets('Planner Event Colors route edits, persists, and restores', (
    tester,
  ) async {
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
    await startup.completeOnboarding();

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
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-colors')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('colors-planner-event-colors')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('colors-planner-event-colors')));
    await tester.pumpAndSettle();

    expect(find.text('Planner Event Colors'), findsWidgets);
    expect(find.byType(PlannerEventColorPreview), findsWidgets);
    expect(find.text('Person Status'), findsNothing);

    await tester.tap(find.byKey(const Key('event-color-swatch-Other-accent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-event-color-picker')), findsOneWidget);
    expect(find.text('Choose Color'), findsOneWidget);
    await tester.tap(find.byKey(const Key('planner-event-color-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-event-color-picker')), findsNothing);
    expect(await database.select(database.plannerPreferences).get(), isEmpty);

    await tester.tap(find.byKey(const Key('event-color-swatch-Other-accent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-event-color-save')));
    await tester.pumpAndSettle();
    final savedAccent =
        (await database.select(database.plannerPreferences).getSingle())
            .eventColorPreferencesJson;
    expect(savedAccent, contains('other'));

    await tester.tap(
      find.byKey(const Key('event-color-swatch-Other-Event background')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-event-color-save')));
    await tester.pumpAndSettle();
    final savedPair =
        (await database.select(database.plannerPreferences).getSingle())
            .eventColorPreferencesJson;
    expect(savedPair, contains('accent'));
    expect(savedPair, contains('surface'));

    await tester.drag(
      find.byKey(const Key('planner-event-colors-list')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('planner-event-colors-restore-defaults')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('planner-event-colors-restore-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('planner-event-colors-restore-cancel')),
    );
    await tester.pumpAndSettle();
    expect(
      (await database.select(database.plannerPreferences).getSingle())
          .eventColorPreferencesJson,
      contains('other'),
    );

    await tester.tap(
      find.byKey(const Key('planner-event-colors-restore-defaults')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('planner-event-colors-restore-confirm')),
    );
    await tester.pumpAndSettle();
    expect(
      (await database.select(database.plannerPreferences).getSingle())
          .eventColorPreferencesJson,
      '{}',
    );

    tester.view.physicalSize = const Size(360, 844);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(411, 844);
    await tester.pumpAndSettle();
  });
}
