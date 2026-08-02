import 'package:drift/drift.dart' hide isNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/data/drift_weekly_planning_repository.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'AC-I-001..010,019,020: Home opens the offline plan and selects factual '
    'Task and Event commitments',
    (tester) async {
      tester.view.physicalSize = const Size(941, 1672);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      await _seedCommitments(database, profile.id);
      final privacy = TestPrivacyDependencies(database: database);

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(monday),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Weekly Planning'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Planning'), findsOneWidget);
      expect(find.textContaining('Jul 27'), findsOneWidget);
      expect(find.textContaining('Jul 27'), findsOneWidget);
      expect(find.textContaining('Asia/Manila'), findsNothing);
      expect(find.byKey(const Key('weekly-plan-identity')), findsNothing);
      expect(find.textContaining('Actual is factual'), findsNothing);
      expect(
        find.byKey(const Key('weekly-plan-indicator-job_applications')),
        findsOneWidget,
      );
      expect(find.text('Set Goal'), findsNWidgets(6));

      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-add-commitment')),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-plan-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('weekly-plan-add-commitment')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select existing Task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prepare applications'));
      await tester.pumpAndSettle();
      expect(find.text('Prepare applications'), findsOneWidget);
      expect(find.text('Outcome report outstanding'), findsOneWidget);

      await tester.tap(find.byKey(const Key('weekly-plan-add-commitment')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select weekly Event'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Application session'));
      await tester.pumpAndSettle();
      expect(find.text('Application session'), findsOneWidget);
      expect(find.text('Outcome report outstanding'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('weekly-plan-history-button')));
      await tester.pumpAndSettle();
      expect(find.text('Prior Weeks'), findsOneWidget);
      expect(find.byKey(const Key('weekly-plan-history-list')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'Q4 / AC-I-002,004,008,019: Weekly Planning remains usable at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 2.5;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      await startup.completeOnboarding();
      final privacy = TestPrivacyDependencies(database: database);

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(monday),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Weekly Planning'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Planning'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-indicator-meaningful_connections')),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-plan-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.byKey(const Key('weekly-plan-indicator-meaningful_connections')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'AC-I-010..016,020: due review stores a private reflection and reopens '
    'as factual read-only evidence',
    (tester) async {
      tester.view.physicalSize = const Size(941, 1672);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      await startup.completeOnboarding();
      final reviewClock = FixedClock(DateTime.utc(2026, 8, 3, 12));
      final timeZones = IanaCalendarEventTimeZones(
        displayTimeZoneId: 'Asia/Manila',
      );
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: reviewClock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: reviewClock,
        timeZones: timeZones,
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: reviewClock,
        calendarEvents: calendar,
      );
      final weekly = DriftWeeklyPlanningRepository(
        database: database,
        clock: reviewClock,
        identifiers: const UuidIdentifierSource(),
        timeZones: timeZones,
        indicators: indicators,
        calendarEvents: calendar,
      );
      final privacy = TestPrivacyDependencies(database: database);

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(monday),
          weeklyPlanningRepository: weekly,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Weekly Planning'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-review-button')),
        300,
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
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekly-plan-review-button')));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Review'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-review-reflection')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-review-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Outstanding reports (0)'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('weekly-review-reflection')),
        'Private review fixture',
      );
      await tester.tap(find.byKey(const Key('weekly-review-complete')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-reviewed-summary')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-plan-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.byKey(const Key('weekly-plan-reviewed-summary')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-start-next-button')),
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-plan-list')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        find.byKey(const Key('weekly-plan-start-next-button')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}

Future<void> _seedCommitments(AppDatabase database, String profileId) async {
  final now = DateTime.utc(2026, 7, 27, 12);
  await database
      .into(database.plannerTasks)
      .insert(
        PlannerTasksCompanion.insert(
          id: '82000000-0000-4000-8000-000000000001',
          profileId: profileId,
          title: 'Prepare applications',
          dueDate: const Value<String?>('2026-07-29'),
          requiresReport: const Value<bool>(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: '82000000-0000-4000-8000-000000000002',
          profileId: profileId,
          title: 'Application session',
          timing: 'allDay',
          startDate: '2026-07-28',
          requiresReport: const Value<bool>(true),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}
