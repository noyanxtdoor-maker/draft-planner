import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'AC-C-001..020 and AC-D-001..020: Planner and Task journey remains '
    'offline, distinct, factual, and non-destructive',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      final profile = await startupRepository.completeOnboarding();
      final calendarSource = MemoryPlannerCalendarSource(<PlannerCalendarItem>[
        PlannerCalendarItem(
          id: 'event-all-day',
          title: 'All-day fixture',
          date: selected,
          timing: PlannerEventTiming.allDay,
          state: PlannerEventState.scheduled,
          requiresReport: false,
          hasOutcomeReport: false,
          locationText: 'Stored location fixture',
        ),
        PlannerCalendarItem(
          id: 'event-timed',
          title: 'Timed fixture',
          date: selected,
          timing: PlannerEventTiming.timed,
          state: PlannerEventState.scheduled,
          requiresReport: false,
          hasOutcomeReport: false,
          startLocal: DateTime(2026, 7, 27, 14),
          endLocal: DateTime(2026, 7, 27, 15),
          isRecurring: true,
          linkedTaskIds: const <String>['linked-task'],
        ),
        PlannerCalendarItem(
          id: 'event-awaiting',
          title: 'Awaiting fixture',
          date: selected,
          timing: PlannerEventTiming.timed,
          state: PlannerEventState.scheduled,
          requiresReport: true,
          hasOutcomeReport: false,
          startLocal: DateTime(2020, 1, 1, 8),
          endLocal: DateTime(2020, 1, 1, 9),
        ),
        PlannerCalendarItem(
          id: 'event-cancelled',
          title: 'Cancelled fixture',
          date: selected,
          timing: PlannerEventTiming.allDay,
          state: PlannerEventState.cancelled,
          requiresReport: false,
          hasOutcomeReport: false,
        ),
      ]);
      final plannerRepository = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        calendarSource: calendarSource,
        taskContextSource: const MemoryPlannerTaskContextSource(
          <String, PlannerTaskContext>{
            'task-ui': PlannerTaskContext(
              linkedEventIds: <String>['event-timed'],
              pathwayContextLabels: <String>[
                'Employment pathway · Application milestone',
              ],
            ),
          },
        ),
      );
      await plannerRepository.saveTask(
        profileId: profile.id,
        draft: const PlannerTaskDraft(
          id: 'report-task',
          title: 'Report-required fixture',
          dueDate: selected,
          requiresReport: true,
        ),
      );

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startupRepository,
          plannerRepository: plannerRepository,
          plannerDateSource: const FixedPlannerDateSource(selected),
          plannerIdentifierSource: SequenceIdentifierSource(<String>[
            'task-ui',
            'operation-complete',
            'operation-required',
          ]),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-selected-date')), findsOneWidget);
      expect(find.byKey(const Key('planner-day-2026-07-27')), findsOneWidget);
      expect(find.byKey(const Key('all-day-section')), findsOneWidget);
      expect(find.text('All-day fixture'), findsOneWidget);
      expect(find.text('Timed fixture'), findsOneWidget);
      expect(find.byTooltip('1 linked Task(s)'), findsOneWidget);
      expect(find.byKey(const Key('planner-time-grid')), findsOneWidget);
      final timedEvent = tester.widget<Positioned>(
        find.byKey(const Key('planner-timed-event-event-timed')),
      );
      expect(timedEvent.top, 480);
      expect(timedEvent.height, 60);

      await tester.tap(find.byKey(const Key('planner-create-button')));
      await tester.pumpAndSettle();
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Calendar Event'), findsOneWidget);
      await tester.tap(find.byKey(const Key('create-task-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-title-field')),
        'Offline Task',
      );
      await tester.enterText(
        find.byKey(const Key('task-notes-field')),
        'Input survives until an atomic save.',
      );
      await tester.tap(find.byKey(const Key('save-task-button')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Offline Task'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.text('Offline Task'));
      await tester.pumpAndSettle();
      expect(find.text('Offline Task'), findsOneWidget);
      expect(find.byKey(const Key('planner-day-2026-07-27')), findsOneWidget);
      await tester.tap(find.text('Offline Task'));
      await tester.pumpAndSettle();
      expect(find.text('Task'), findsWidgets);
      expect(find.text('Incomplete'), findsOneWidget);
      expect(find.text('1 linked Calendar Event(s)'), findsOneWidget);
      expect(
        find.text('Employment pathway · Application milestone'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('complete-task-button')));
      await tester.pumpAndSettle();
      expect(find.text('Completed'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-day-2026-07-27')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Offline Task'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Offline Task'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Report-required fixture'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.drag(
        find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report-required fixture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complete-task-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('outcome-report-form')), findsOneWidget);
      expect(find.text('Report-required fixture'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Incomplete'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Awaiting fixture'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Awaiting fixture'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Cancelled fixture'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Cancelled fixture'), findsOneWidget);

      final taskRows = await database.select(database.plannerTasks).get();
      expect(taskRows, hasLength(2));
      expect(
        taskRows.singleWhere((row) => row.id == 'report-task').status,
        PlannerTaskStatus.incomplete.name,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AC-C-019 and AC-D-016: recoverable save failure retains input', (
    tester,
  ) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startupRepository = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    await startupRepository.completeOnboarding();
    final failingRepository = DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      writeGuard: const FailingTaskWriteGuard(),
    );

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startupRepository,
        plannerRepository: failingRepository,
        plannerDateSource: const FixedPlannerDateSource(selected),
        plannerIdentifierSource: SequenceIdentifierSource(<String>[
          'failed-task',
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planner-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-task-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-title-field')),
      'Retained Task Input',
    );
    await tester.tap(find.byKey(const Key('save-task-button')));
    await tester.pumpAndSettle();

    expect(find.text('Retained Task Input'), findsOneWidget);
    expect(find.textContaining('input remains'), findsOneWidget);
    expect(await database.select(database.plannerTasks).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Q4 / AC-C-001,002 and AC-D-001,004: Planner is usable at '
      '200% text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startupRepository = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    await startupRepository.completeOnboarding();

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startupRepository,
        plannerDateSource: const FixedPlannerDateSource(selected),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('planner-day-scroll')), findsOneWidget);
    expect(find.byKey(const Key('planner-create-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
