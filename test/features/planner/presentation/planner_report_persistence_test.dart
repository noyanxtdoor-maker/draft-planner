// Post-VS-11 planner polish P-01A: report persistence.
//
// A report outcome is a STATUS on an occurrence, never an existence gate.
// Reporting "Did Not Attempt" must keep the Event occurrence rendered on the
// Planner Day timeline (same date, same time, same identity, updated status)
// and must never mutate a recurring series. Only explicit lifecycle actions
// (cancel / reschedule / delete) may remove an occurrence from the timeline.
//
// The canonical gate lives in DriftPlannerRepository._isVisibleTimelineState:
// PlannerEventState.didNotHappen must remain visible. These tests prove the
// full repository path (save -> submit report -> readDay) honors it.

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);
  const displayTimeZoneId = 'Asia/Manila';
  const eventId = '11111111-1111-4111-8111-111111111111';
  const reportId = '22222222-2222-4222-8222-222222222222';
  const operationId = '33333333-3333-4333-8333-333333333333';

  CalendarEventDraft timedDraft({
    required String id,
    required String title,
    required int startMinute,
    required int endMinute,
    CalendarRecurrenceRule recurrence = const CalendarRecurrenceRule(),
  }) {
    return CalendarEventDraft(
      id: id,
      title: title,
      timing: CalendarEventTiming.timed,
      startDate: selected,
      startMinute: startMinute,
      endMinute: endMinute,
      timeZoneId: displayTimeZoneId,
      requiresReport: true,
      activityTypeId: 'general',
      recurrence: recurrence,
    );
  }

  Future<
    (
      DriftPlannerRepository,
      DriftCalendarEventRepository,
      DriftOutcomeReportingRepository,
    )
  >
  buildRepositories(AppDatabase database) async {
    final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
    final timeZones = IanaCalendarEventTimeZones(
      displayTimeZoneId: displayTimeZoneId,
    );
    final linkRepository = DriftTaskEventLinkRepository(
      database: database,
      clock: clock,
    );
    final outcomeReportingRepository = DriftOutcomeReportingRepository(
      database: database,
      clock: clock,
    );
    final calendarRepository = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: timeZones,
      taskContextSource: linkRepository,
      linkContextTransfer: linkRepository,
      reportSource: outcomeReportingRepository,
    );
    final plannerRepository = DriftPlannerRepository(
      database: database,
      clock: clock,
      calendarSource: calendarRepository,
      taskContextSource: linkRepository,
      historicalEffectReader: outcomeReportingRepository,
    );
    return (plannerRepository, calendarRepository, outcomeReportingRepository);
  }

  Future<void> reportDidNotAttempt(
    DriftOutcomeReportingRepository reporting,
    String profileId,
  ) async {
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: selected,
    );
    await reporting.submit(
      profileId: profileId,
      draft: OutcomeReportDraft(
        id: reportId,
        source: OutcomeReportSource(
          type: OutcomeSourceType.event,
          sourceId: occurrenceId,
          label: 'Weekly Dinner',
          activityDate: selected,
          eventId: eventId,
          occurrenceId: occurrenceId,
          originalDate: selected,
        ),
        activityDate: selected,
        outcome: OutcomeKind.didNotHappen,
        privateNotes: 'Reported via P-01A fixture',
      ),
      operationId: operationId,
    );
  }

  group('P-01A report persistence', () {
    test('a Did Not Attempt report never removes a valid non-recurring '
        'occurrence from the timeline', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final (plannerRepository, calendarRepository, reporting) =
          await buildRepositories(database);

      await calendarRepository.saveEvent(
        profileId: profile.id,
        draft: timedDraft(
          id: eventId,
          title: 'Weekly Dinner',
          startMinute: 18 * 60,
          endMinute: 19 * 60,
        ),
      );

      final before = await plannerRepository.readDay(
        profileId: profile.id,
        selectedDate: selected,
        today: selected,
      );
      final beforeOccurrence = before.timedEvents.singleWhere(
        (event) => event.eventId == eventId,
      );
      expect(beforeOccurrence.state, PlannerEventState.scheduled);

      await reportDidNotAttempt(reporting, profile.id);

      final after = await plannerRepository.readDay(
        profileId: profile.id,
        selectedDate: selected,
        today: selected,
      );
      final afterOccurrences = after.timedEvents
          .where((event) => event.eventId == eventId)
          .toList();
      expect(
        afterOccurrences,
        hasLength(1),
        reason: 'Did Not Attempt must never remove the occurrence',
      );
      final afterOccurrence = afterOccurrences.single;
      expect(afterOccurrence.state, PlannerEventState.didNotHappen);
      expect(afterOccurrence.startLocal, beforeOccurrence.startLocal);
      expect(afterOccurrence.endLocal, beforeOccurrence.endLocal);
      expect(afterOccurrence.eventId, eventId);
      expect(afterOccurrence.hasOutcomeReport, isTrue);
    });

    test('a recurring series stays intact when one occurrence is reported '
        'Did Not Attempt', () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final (plannerRepository, calendarRepository, reporting) =
          await buildRepositories(database);

      await calendarRepository.saveEvent(
        profileId: profile.id,
        draft: timedDraft(
          id: eventId,
          title: 'Weekly Dinner',
          startMinute: 18 * 60,
          endMinute: 19 * 60,
          recurrence: const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.weekly,
          ),
        ),
      );

      await reportDidNotAttempt(reporting, profile.id);

      // The reported occurrence remains visible with its updated status.
      final reportedDay = await plannerRepository.readDay(
        profileId: profile.id,
        selectedDate: selected,
        today: selected,
      );
      final reportedOccurrence = reportedDay.timedEvents.singleWhere(
        (event) => event.eventId == eventId,
      );
      expect(reportedOccurrence.state, PlannerEventState.didNotHappen);

      // The next future occurrence remains scheduled normally.
      final futureDate = selected.addDays(7);
      final futureDay = await plannerRepository.readDay(
        profileId: profile.id,
        selectedDate: futureDate,
        today: futureDate,
      );
      final futureOccurrence = futureDay.timedEvents.singleWhere(
        (event) => event.eventId == eventId,
      );
      expect(futureOccurrence.state, PlannerEventState.scheduled);
      expect(futureOccurrence.hasOutcomeReport, isFalse);
    });

    test(
      'every report outcome keeps the occurrence visible (render matrix)',
      () async {
        final database = openMemoryDatabase();
        addTearDown(database.close);
        final profile = await buildTestRepository(
          database: database,
        ).completeOnboarding();

        // Feed the planner repository one item per state through the memory
        // calendar source so the visibility predicate is exercised exactly
        // as the real repository consumes the projected occurrence stream.
        final source = MemoryPlannerCalendarSource(<PlannerCalendarItem>[
          for (final state in PlannerEventState.values)
            PlannerCalendarItem(
              id: 'item-${state.name}',
              title: state.name,
              date: selected,
              timing: PlannerEventTiming.timed,
              state: state,
              requiresReport: true,
              hasOutcomeReport: false,
              startLocal: DateTime(2026, 7, 27, 9, state.index),
              endLocal: DateTime(2026, 7, 27, 10, state.index),
              eventId: 'event-${state.name}',
              originalDate: selected,
              activityTypeId: 'general',
              activityTypeLabel: 'General',
              activityTypeColorValue: 0xFFE91E63,
            ),
        ]);
        final plannerRepository = DriftPlannerRepository(
          database: database,
          clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
          calendarSource: source,
          taskContextSource: const MemoryPlannerTaskContextSource(
            <String, PlannerTaskContext>{},
          ),
          historicalEffectReader: const NoTaskHistoricalEffects(),
        );

        final day = await plannerRepository.readDay(
          profileId: profile.id,
          selectedDate: selected,
          today: selected,
        );
        final visibleStates = day.timedEvents
            .map((event) => event.state)
            .toSet();
        for (final state in PlannerEventState.values) {
          if (state == PlannerEventState.cancelled ||
              state == PlannerEventState.rescheduled) {
            expect(
              visibleStates,
              isNot(contains(state)),
              reason: 'only explicit lifecycle states may leave the timeline',
            );
          } else {
            expect(
              visibleStates,
              contains(state),
              reason:
                  '$state must remain visible: report outcomes are never '
                  'existence gates',
            );
          }
        }
      },
    );
  });
}
