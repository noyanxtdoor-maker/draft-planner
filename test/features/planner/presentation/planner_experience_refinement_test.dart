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
      tester.view.physicalSize = const Size(411, 731);
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
      for (final label in <String>['Event', 'Task']) {
        expect(find.text(label), findsOneWidget);
      }
      final eventPill = tester.getRect(
        find.byKey(const Key('create-calendar-event-action')),
      );
      final taskPill = tester.getRect(
        find.byKey(const Key('create-task-action')),
      );
      expect(eventPill.height, closeTo(56, 1));
      expect(taskPill.height, closeTo(56, 1));
      expect(eventPill.width, inInclusiveRange(108, 232));
      expect(taskPill.width, inInclusiveRange(108, 232));
      expect(eventPill.top - taskPill.bottom, closeTo(8, 1));
      expect(tester.view.physicalSize.width - eventPill.right, closeTo(16, 1));
      expect(find.text('+ Person'), findsNothing);
      expect(find.text('Contact'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Event')).dy,
        greaterThan(tester.getTopLeft(find.text('Task')).dy),
      );
      await tester.tap(find.byKey(const Key('contextual-create-barrier')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contextual-create-menu')), findsNothing);
      await tester.tap(find.byKey(const Key('planner-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('contextual-create-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contextual-create-menu')), findsNothing);

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
      final center = tester
          .getRect(zoomSurface)
          .intersect(
            tester.getRect(find.byKey(const Key('planner-day-scroll'))),
          )
          .center;
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

      // NX-07/08: no More tab — Settings lives in the drawer. The test is
      // on the Planner, so use the planner hamburger.
      await tester.tap(find.byKey(const Key('planner-hamburger')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-account-settings')));
      await tester.pumpAndSettle();
      // VS16-M1 added the Notifications row, shifting lower Settings rows
      // below the fold at this fixed viewport; scroll to the row first.
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-planner-calendar')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('settings-planner-calendar')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-privacy-data')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
