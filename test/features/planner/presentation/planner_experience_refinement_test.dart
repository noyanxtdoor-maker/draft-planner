import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'VS08-OWNER: top controls, filters, selection, zoom, and Settings remain local',
    (tester) async {
      tester.view.physicalSize = const Size(431, 912);
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
          plannerDateSource: const FixedPlannerDateSource(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-date-label')), findsOneWidget);
      expect(find.byKey(const Key('planner-calendar-button')), findsOneWidget);
      expect(find.byKey(const Key('planner-filter-button')), findsOneWidget);
      expect(find.byKey(const Key('planner-selection-button')), findsOneWidget);
      expect(find.byKey(const Key('planner-overflow-button')), findsOneWidget);
      expect(find.text('Overdue'), findsNothing);
      expect(find.text('Changes'), findsNothing);

      await tester.tap(find.byKey(const Key('planner-overflow-button')));
      await tester.pumpAndSettle();
      for (final label in <String>[
        'Search',
        'Schedule',
        'Day',
        'Week',
        'Tasks',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('planner-create-button')));
      await tester.pumpAndSettle();
      for (final label in <String>['Event', 'Task', '+ Person', 'Contact']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('Event')).dy,
        lessThan(tester.getTopLeft(find.text('Task')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Task')).dy,
        lessThan(tester.getTopLeft(find.text('+ Person')).dy),
      );
      expect(
        tester.getTopLeft(find.text('+ Person')).dy,
        lessThan(tester.getTopLeft(find.text('Contact')).dy),
      );
      await tester.tap(find.byKey(const Key('create-person-action')));
      await tester.pumpAndSettle();
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(await database.select(database.plannerTasks).get(), isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('planner-filter-button')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('planner-filter-events')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('planner-filter-backup-events')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('planner-filter-tasks')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('planner-filter-completed-tasks')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('planner-filter-completed-tasks')));
      await tester.tap(find.byKey(const Key('planner-filter-apply')));
      await tester.pumpAndSettle();
      expect(
        (await database.select(database.plannerPreferences).get())
            .single
            .showCompletedTasks,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('planner-selection-button')));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('planner-selection-delete')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const Key('planner-selection-cancel')));
      await tester.pumpAndSettle();

      final zoomSurface = find.byKey(const Key('planner-zoom-surface'));
      final center = tester.getCenter(zoomSurface);
      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);
      await first.down(center - const Offset(20, 0));
      await tester.pump();
      await second.down(center + const Offset(20, 0));
      await tester.pump();
      await first.moveTo(center - const Offset(60, 0));
      await tester.pump();
      await second.moveTo(center + const Offset(60, 0));
      await tester.pump();
      await first.moveTo(center - const Offset(90, 0));
      await second.moveTo(center + const Offset(90, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(
        (await database.select(database.plannerPreferences).get())
            .single
            .timelineHourHeight,
        greaterThan(60),
      );

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('more-settings')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-planner-calendar')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-privacy-data')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
