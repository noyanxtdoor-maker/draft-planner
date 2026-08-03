import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);
  const eventId = '88888888-8888-4888-8888-888888888888';
  const contributionRule = 'life-indicator:exercise:1:0:count';

  testWidgets(
    'VS08 owner override: Current Status saves once, corrects directly, and '
    'Activity History stays read-only',
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
      final linkRepository = DriftTaskEventLinkRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      final reportingRepository = DriftOutcomeReportingRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      final calendarRepository = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
        taskContextSource: linkRepository,
        linkContextTransfer: linkRepository,
        reportSource: reportingRepository,
      );
      final plannerRepository = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        calendarSource: calendarRepository,
        taskContextSource: linkRepository,
        historicalEffectReader: reportingRepository,
      );
      await calendarRepository.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Current Status fixture',
          timing: CalendarEventTiming.timed,
          startDate: selected,
          startMinute: 9 * 60,
          endMinute: 11 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: true,
          contributionRuleKey: contributionRule,
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
          calendarEventRepository: calendarRepository,
          plannerDateSource: const FixedPlannerDateSource(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: selected,
      );
      await tester.tap(find.byKey(Key('planner-timed-event-$occurrenceId')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('event-status-control')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-control')),
          matching: find.text('Unreported'),
        ),
        findsOneWidget,
      );
      expect(find.byType(Chip), findsNothing);
      expect(find.byKey(const Key('outcome-report-form')), findsNothing);
      await tester.tap(find.byKey(const Key('event-status-control')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-option-scheduled')),
          matching: find.text('Unreported'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-option-completedHappened')),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-option-partiallyCompleted')),
          matching: find.text('Missed - Attempted'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-option-didNotHappen')),
          matching: find.text('Did Not Attempt'),
        ),
        findsOneWidget,
      );
      expect(find.text('Did Not Attend'), findsNothing);
      await tester.tap(
        find.byKey(const Key('event-status-option-completedHappened')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-control')),
          matching: find.text('Completed'),
        ),
        findsOneWidget,
      );
      var reports = await database.select(database.outcomeReports).get();
      expect(reports, hasLength(1));
      expect(reports.single.outcome, OutcomeKind.completedHappened.name);
      var ledger = await database.select(database.activityLedgerEntries).get();
      expect(ledger, hasLength(1));

      // Re-selecting the current outcome is a no-op: it cannot consume a
      // second report, ledger contribution, or history entry.
      await tester.tap(find.byKey(const Key('event-status-control')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('event-status-option-completedHappened')),
      );
      await tester.pumpAndSettle();
      reports = await database.select(database.outcomeReports).get();
      ledger = await database.select(database.activityLedgerEntries).get();
      expect(reports, hasLength(1));
      expect(ledger, hasLength(1));

      // A correction uses the same popup and accepts the direct partial
      // outcome without opening a factual-value form.
      await tester.tap(find.byKey(const Key('event-status-control')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('event-status-option-partiallyCompleted')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('event-status-control')),
          matching: find.text('Missed - Attempted'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('outcome-report-form')), findsNothing);
      reports = await database.select(database.outcomeReports).get();
      expect(reports, hasLength(2));
      ledger = await database.select(database.activityLedgerEntries).get();
      expect(ledger, hasLength(3));

      final activityHistory = find.byKey(
        const Key('event-activity-history-button'),
      );
      await tester.ensureVisible(activityHistory);
      await tester.pumpAndSettle();
      await tester.tap(activityHistory);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('activity-history-list')), findsOneWidget);
      expect(find.text('Correct Report'), findsNothing);
      expect(find.byKey(const Key('correct-report-unknown')), findsNothing);
    },
  );
}
