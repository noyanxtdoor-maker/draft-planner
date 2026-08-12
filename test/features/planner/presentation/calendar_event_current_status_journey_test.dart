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

  testWidgets('Delta 2: generic non-Contact Current Status is exactly '
      'Unreported/Missed/Completed, uses draft mode - tapping a status never '
      'writes, Save commits exactly once, and close/Back cancels the draft '
      'first', (tester) async {
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

    // Normal preview mode: the compact status row sits below the app bar,
    // the pencil and overflow remain visible, and there is no Save action.
    // No reporting write occurs merely by opening the preview.
    expect(find.byKey(const Key('event-status-control')), findsOneWidget);
    expect(find.byKey(const Key('event-status-current-label')), findsOneWidget);
    expect(find.text('Unreported'), findsOneWidget);
    // Delta 2: a generic non-Contact Event offers exactly three statuses.
    for (final key in <String>[
      'event-status-option-scheduled',
      'event-status-option-partiallyCompleted',
      'event-status-option-completedHappened',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      find.byKey(const Key('event-status-option-didNotHappen')),
      findsNothing,
      reason: 'Did Not Attempt is no longer offered to non-Contact Events',
    );
    expect(find.byKey(const Key('event-status-save')), findsNothing);
    expect(
      find.byKey(const Key('event-detail-sheet-edit-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('event-detail-sheet-overflow-icon')),
      findsOneWidget,
    );
    expect(find.text('Did Not Attend'), findsNothing);
    expect(find.text('Schedule Next Appointment'), findsNothing);
    expect(find.text('Reschedule'), findsNothing);

    // Tapping a different status enters draft mode: the label updates
    // immediately, pencil and overflow are replaced by Save, and NOTHING is
    // written to the reporting tables yet.
    await tester.tap(
      find.byKey(const Key('event-status-option-completedHappened')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const Key('event-status-save')), findsOneWidget);
    // Draft mode commits through a top-right check icon, never a text Save
    // action (Final Correction Pack): the action is an IconButton with a
    // check glyph and no 'Save' label anywhere.
    expect(find.text('Save'), findsNothing);
    final saveAction = tester.widget<IconButton>(
      find.byKey(const Key('event-status-save')),
    );
    expect((saveAction.icon as Icon).icon, Icons.check);
    expect(find.byKey(const Key('event-detail-sheet-edit-icon')), findsNothing);
    expect(
      find.byKey(const Key('event-detail-sheet-overflow-icon')),
      findsNothing,
    );
    expect(await database.select(database.outcomeReports).get(), isEmpty);
    expect(
      await database.select(database.activityLedgerEntries).get(),
      isEmpty,
    );

    // Save performs exactly one canonical reporting transaction and returns
    // the preview to normal mode (Save disappears, pencil/overflow return).
    await tester.tap(find.byKey(const Key('event-status-save')));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const Key('event-status-save')), findsNothing);
    expect(
      find.byKey(const Key('event-detail-sheet-edit-icon')),
      findsOneWidget,
    );
    var reports = await database.select(database.outcomeReports).get();
    expect(reports, hasLength(1));
    expect(reports.single.outcome, OutcomeKind.completedHappened.name);
    var ledger = await database.select(database.activityLedgerEntries).get();
    expect(ledger, hasLength(1));

    // Re-selecting the current status is a no-op: no draft, no write.
    await tester.tap(
      find.byKey(const Key('event-status-option-completedHappened')),
    );
    await tester.pumpAndSettle();
    reports = await database.select(database.outcomeReports).get();
    ledger = await database.select(database.activityLedgerEntries).get();
    expect(reports, hasLength(1));
    expect(ledger, hasLength(1));

    // A correction stages a new draft; closing (x) cancels the draft first
    // without any persistence.
    await tester.tap(
      find.byKey(const Key('event-status-option-partiallyCompleted')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Missed'), findsOneWidget);
    expect(find.byKey(const Key('event-status-save')), findsOneWidget);
    reports = await database.select(database.outcomeReports).get();
    expect(reports, hasLength(1));
    await tester.tap(find.byKey(const Key('event-detail-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const Key('event-status-save')), findsNothing);
    reports = await database.select(database.outcomeReports).get();
    ledger = await database.select(database.activityLedgerEntries).get();
    expect(reports, hasLength(1));
    expect(ledger, hasLength(1));

    // Android Back also cancels the draft first (persisted status is
    // unchanged), and a second Back exits the preview.
    await tester.tap(
      find.byKey(const Key('event-status-option-partiallyCompleted')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Missed'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.byKey(const Key('event-status-save')), findsNothing);
    reports = await database.select(database.outcomeReports).get();
    expect(reports, hasLength(1));

    // The committed draft used the canonical partial outcome without
    // opening a factual-value form.
    await tester.tap(
      find.byKey(const Key('event-status-option-partiallyCompleted')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('event-status-save')));
    await tester.pumpAndSettle();
    expect(find.text('Missed'), findsOneWidget);
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
  });

  testWidgets('Delta 2: Contact Events keep the four-state Current Status set '
      '(including Did Not Attempt) with Contact labels', (tester) async {
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
        title: 'Contact follow-up',
        timing: CalendarEventTiming.timed,
        startDate: selected,
        startMinute: 9 * 60,
        endMinute: 10 * 60,
        timeZoneId: 'Asia/Manila',
        requiresReport: true,
        // The real form always persists an activityTypeId; the snapshot
        // pair rides along so the occurrence resolves as a Contact Event.
        activityTypeId: 'contact-type-id',
        activityTypeStableKeySnapshot: 'contact',
        activityTypeLabelSnapshot: 'Contact',
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

    // Contact keeps the full four-state set.
    for (final key in <String>[
      'event-status-option-scheduled',
      'event-status-option-didNotHappen',
      'event-status-option-partiallyCompleted',
      'event-status-option-completedHappened',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }

    // Contact labels: Did Not Attempt stays selectable and persists.
    await tester.tap(find.byKey(const Key('event-status-option-didNotHappen')));
    await tester.pumpAndSettle();
    expect(find.text('Did Not Attempt'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-status-save')));
    await tester.pumpAndSettle();
    final reports = await database.select(database.outcomeReports).get();
    expect(reports, hasLength(1));
    expect(reports.single.outcome, OutcomeKind.didNotHappen.name);

    // Contact reads 'Missed — Attempted' (never the generic 'Missed').
    await tester.tap(
      find.byKey(const Key('event-status-option-partiallyCompleted')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Missed — Attempted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-status-save')));
    await tester.pumpAndSettle();
    expect(find.text('Missed — Attempted'), findsOneWidget);

    // Delta 2 final matrix: Completed reads 'Completed' for Contact Events
    // too (no separate 'Contacted' status).
    await tester.tap(
      find.byKey(const Key('event-status-option-completedHappened')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
  });
}
