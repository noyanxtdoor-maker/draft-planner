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
      find.byKey(const Key('planner-event-colors-events-section')),
      findsOneWidget,
    );
    expect(find.text('Colors'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.byType(PlannerEventColorPreview), findsWidgets);
    expect(find.text('Person Status'), findsNothing);

    final jobAccent = find.byKey(
      const Key('event-color-swatch-Job Application-accent'),
    );
    await tester.tap(jobAccent);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-event-color-picker')), findsOneWidget);
    expect(find.text('Choose Color'), findsOneWidget);
    await tester.tap(find.byKey(const Key('planner-event-color-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-event-color-picker')), findsNothing);
    expect(await database.select(database.plannerPreferences).get(), isEmpty);

    await tester.tap(jobAccent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-event-color-save')));
    await tester.pumpAndSettle();
    final savedAccent =
        (await database.select(database.plannerPreferences).getSingle())
            .eventColorPreferencesJson;
    expect(savedAccent, contains('job_application'));

    final jobSurface = find.byKey(
      const Key('event-color-swatch-Job Application-Event background'),
    );
    await tester.tap(jobSurface);
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
    expect(find.text('Groups'), findsOneWidget);
    await tester.tap(find.byKey(const Key('group-color-swatch-family')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-event-color-save')));
    await tester.pumpAndSettle();
    final savedWithGroup =
        (await database.select(database.plannerPreferences).getSingle())
            .eventColorPreferencesJson;
    expect(savedWithGroup, contains('groups'));
    expect(savedWithGroup, contains('family'));

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
      contains('job_application'),
    );

    await tester.tap(
      find.byKey(const Key('planner-event-colors-restore-defaults')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('planner-event-colors-restore-confirm')),
    );
    await tester.pumpAndSettle();
    final afterEventRestore =
        (await database.select(database.plannerPreferences).getSingle())
            .eventColorPreferencesJson;
    expect(afterEventRestore, isNot(contains('job_application')));
    expect(afterEventRestore, contains('family'));

    await tester.tap(
      find.byKey(const Key('planner-group-colors-restore-defaults')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('planner-group-colors-restore-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('planner-group-colors-restore-confirm')),
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
