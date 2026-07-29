import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'VS-08: one timeline tap selects a type before a prefilled form',
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

      final plannerScroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      plannerScroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      final surface = find.byKey(const Key('planner-timeline-create-surface'));
      final surfaceTopLeft = tester.getTopLeft(surface);
      final surfaceSize = tester.getSize(surface);
      await tester.tapAt(surfaceTopLeft + Offset(surfaceSize.width / 2, 210));
      await tester.pumpAndSettle();

      expect(find.text('Select Event Type'), findsOneWidget);
      expect(find.text('New Calendar Event'), findsNothing);
      expect(await database.select(database.calendarEvents).get(), isEmpty);

      await tester.tap(find.byKey(const Key('event-type-option-temple_visit')));
      await tester.pumpAndSettle();

      expect(find.text('New Calendar Event'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('event-type-field')),
          matching: find.text('Temple Visit'),
        ),
        findsOneWidget,
      );
      expect(find.text(selected.iso8601), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('event-start-time')),
          matching: find.text('9:30 AM'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('event-end-time')),
          matching: find.text('11:30 AM'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('saving never creates Actual'),
        findsOneWidget,
      );
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(
        await database.select(database.activityLedgerEntries).get(),
        isEmpty,
      );
    },
  );

  testWidgets(
    'VS-08: Life Indicator recommends its exact type and cancel writes nothing',
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
      await tester.tap(
        find.byKey(const Key('home-indicator-job_applications')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('indicator-schedule-activity')));
      await tester.pumpAndSettle();

      expect(find.text('Select Event Type'), findsOneWidget);
      expect(
        find.byKey(const Key('event-type-recommended-job_application')),
        findsOneWidget,
      );
      final recommendedTop = tester.getTopLeft(
        find.byKey(const Key('event-type-option-job_application')),
      );
      final generalTop = tester.getTopLeft(
        find.byKey(const Key('event-type-option-general')),
      );
      expect(recommendedTop.dy, lessThan(generalTop.dy));

      await tester.tap(find.byKey(const Key('event-type-picker-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Indicator Detail'), findsOneWidget);
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      expect(
        await database.select(database.calendarEventOperations).get(),
        isEmpty,
      );
      expect(await database.select(database.outcomeReports).get(), isEmpty);
      expect(
        await database.select(database.activityLedgerEntries).get(),
        isEmpty,
      );
    },
  );

  testWidgets('VS-08: Weekly Planning opens the picker before the form', (
    tester,
  ) async {
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-targets-button')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-indicator-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('weekly-targets-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-plan-create-event')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('weekly-plan-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('weekly-plan-list')),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weekly-plan-create-event')));
    await tester.pumpAndSettle();

    expect(find.text('Select Event Type'), findsOneWidget);
    expect(find.text('New Calendar Event'), findsNothing);
    await tester.tap(find.byKey(const Key('event-type-picker-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Planning'), findsOneWidget);
    expect(await database.select(database.calendarEvents).get(), isEmpty);
  });

  testWidgets('VS-08: Task scheduling opens the picker before the form', (
    tester,
  ) async {
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
    final profile = await startup.completeOnboarding();
    const taskId = '20000000-0000-4000-8000-000000000008';
    await DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    ).saveTask(
      profileId: profile.id,
      draft: const PlannerTaskDraft(
        id: taskId,
        title: 'Prepare a follow-up',
        dueDate: selected,
        requiresReport: false,
      ),
    );

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
    final taskTile = find.byKey(const Key('planner-task-$taskId'));
    await tester.scrollUntilVisible(
      taskTile,
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('planner-day-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(taskTile);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('create-event-from-task')),
      200,
    );
    await tester.tap(find.byKey(const Key('create-event-from-task')));
    await tester.pumpAndSettle();

    expect(find.text('Select Event Type'), findsOneWidget);
    expect(find.text('New Calendar Event'), findsNothing);
    await tester.tap(find.byKey(const Key('event-type-picker-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Task'), findsOneWidget);
    expect(await database.select(database.calendarEvents).get(), isEmpty);
  });

  testWidgets('VS-08: direct create route is guarded by the picker', (
    tester,
  ) async {
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
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(
      router.push<void>(
        '${RoutePaths.calendarEventCreate}?date=${selected.iso8601}',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Select Event Type'), findsOneWidget);
    expect(find.text('New Calendar Event'), findsNothing);
    await tester.tap(find.byKey(const Key('event-type-picker-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
    expect(await database.select(database.calendarEvents).get(), isEmpty);
  });
}
