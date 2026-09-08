import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const contactId = 'c6000000-0000-4000-8000-000000000001';
  const today = PlannerDate(year: 2026, month: 8, day: 25);

  Future<
    ({
      AppDatabase database,
      DriftContactRepository contacts,
      DriftCalendarEventRepository calendar,
      String profileId,
    })
  >
  arrange({DateTime? now}) async {
    final timestamp = now ?? DateTime.utc(2026, 8, 25, 2);
    final database = openMemoryDatabase();
    final startup = buildTestRepository(database: database);
    final profile = await startup.completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(timestamp),
      identifiers: UuidIdentifierSource(),
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(timestamp),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    );
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: contactId,
        firstName: 'C6',
        lastName: 'Timeline',
        displayName: 'C6 Timeline',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
      ),
    );
    return (
      database: database,
      contacts: contacts,
      calendar: calendar,
      profileId: profile.id,
    );
  }

  Future<void> addEvent({
    required DriftCalendarEventRepository calendar,
    required DriftContactRepository contacts,
    required String profileId,
    required String id,
    required String title,
    required PlannerDate date,
    required int startMinute,
    CalendarEventStatus status = CalendarEventStatus.scheduled,
    String timeZoneId = 'Asia/Manila',
    bool requiresReport = false,
  }) async {
    await calendar.saveEvent(
      profileId: profileId,
      draft: CalendarEventDraft(
        id: id,
        title: title,
        timing: CalendarEventTiming.timed,
        startDate: date,
        startMinute: startMinute,
        endMinute: startMinute + 30,
        timeZoneId: timeZoneId,
        requiresReport: requiresReport,
        status: status,
      ),
    );
    await contacts.setEventPeople(
      profileId: profileId,
      eventId: id,
      occurrenceId: DriftContactRepository.seriesOccurrenceId,
      contactIds: const <String>[contactId],
    );
  }

  test(
    'C6: one factual future set supplies Profile ASC and Timeline DESC',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25));
      addTearDown(harness.database.close);
      const ids = <String>[
        'c6000000-0000-4000-8000-000000000101',
        'c6000000-0000-4000-8000-000000000102',
        'c6000000-0000-4000-8000-000000000103',
        'c6000000-0000-4000-8000-000000000104',
      ];
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: ids[2],
        title: 'Dinner',
        date: today,
        startMinute: 18 * 60,
      );
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: ids[0],
        title: 'Shopping',
        date: today,
        startMinute: 13 * 60 + 30,
      );
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: ids[3],
        title: 'Late call',
        date: today,
        startMinute: 20 * 60,
      );
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: ids[1],
        title: 'Service',
        date: today,
        startMinute: 15 * 60,
      );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(timeline.profileUpcoming.map((entry) => entry.title), <String>[
        'Shopping',
        'Service',
        'Dinner',
        'Late call',
      ]);
      expect(timeline.timelineFuture.map((entry) => entry.title), <String>[
        'Late call',
        'Dinner',
        'Service',
        'Shopping',
      ]);
      expect(
        timeline.timelineFuture.map((entry) => entry.statusLabel),
        everyElement('Scheduled'),
        reason:
            'The Timeline Future projection carries the factual lifecycle '
            'label; Profile Upcoming deliberately does not render it.',
      );
      expect(
        timeline.profileUpcoming.map((entry) => entry.eventId),
        ids,
        reason: 'Each projection retains the exact canonical Event identity.',
      );
      expect(
        timeline.profileUpcoming.map((entry) => entry.originalDate),
        everyElement(today),
      );
    },
  );

  test(
    'C6 correction: timed occurrences cross into factual History at end time',
    () async {
      // 4:30 PM Asia/Manila.  The first Event has ended, the second remains
      // in progress, and the third is still future.
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 8, 30));
      addTearDown(harness.database.close);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: 'c6000000-0000-4000-8000-000000000107',
        title: 'Ended',
        date: today,
        startMinute: 13 * 60 + 30,
      );
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: 'c6000000-0000-4000-8000-000000000108',
        title: 'In progress',
        date: today,
        startMinute: 16 * 60 + 15,
      );
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: 'c6000000-0000-4000-8000-000000000109',
        title: 'Later',
        date: today,
        startMinute: 17 * 60,
      );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(timeline.profileUpcoming.map((entry) => entry.title), <String>[
        'In progress',
        'Later',
      ]);
      expect(timeline.timelineFuture.map((entry) => entry.title), <String>[
        'Later',
        'In progress',
      ]);
      final ended = timeline.history.singleWhere(
        (entry) => entry.title == 'Ended',
      );
      expect(ended.subtitle, isNull);
      expect(ended.statusLabel, isNull);
    },
  );

  test(
    'C6 correction: passed report-required occurrences use effective Planner outcomes',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 8, 30));
      addTearDown(harness.database.close);
      const completedId = 'c6000000-0000-4000-8000-000000000110';
      const unreportedId = 'c6000000-0000-4000-8000-000000000111';
      for (final event in <(String, String, CalendarEventStatus)>[
        (completedId, 'Reported', CalendarEventStatus.scheduled),
        (unreportedId, 'Awaiting report', CalendarEventStatus.scheduled),
        (
          'c6000000-0000-4000-8000-000000000113',
          'Missed report',
          CalendarEventStatus.partiallyCompleted,
        ),
        (
          'c6000000-0000-4000-8000-000000000114',
          'Did not attempt report',
          CalendarEventStatus.didNotHappen,
        ),
      ]) {
        await harness.calendar.saveEvent(
          profileId: harness.profileId,
          draft: CalendarEventDraft(
            id: event.$1,
            title: event.$2,
            timing: CalendarEventTiming.timed,
            startDate: today,
            startMinute: 13 * 60,
            endMinute: 13 * 60 + 30,
            timeZoneId: 'Asia/Manila',
            requiresReport: true,
            status: event.$3,
          ),
        );
        await harness.contacts.setEventPeople(
          profileId: harness.profileId,
          eventId: event.$1,
          occurrenceId: DriftContactRepository.seriesOccurrenceId,
          contactIds: const <String>[contactId],
        );
      }
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: completedId,
        originalDate: today,
      );
      await harness.database
          .into(harness.database.outcomeReports)
          .insert(
            OutcomeReportsCompanion.insert(
              id: 'c6000000-0000-4000-8000-000000000112',
              profileId: harness.profileId,
              sourceType: OutcomeSourceType.event.name,
              sourceId: completedId,
              sourceLabel: 'Reported',
              sourceSlotKey: 'event:$completedId:$occurrenceId',
              eventId: const Value<String?>(completedId),
              occurrenceId: Value<String?>(occurrenceId),
              originalDate: Value<String?>(today.iso8601),
              effectiveSlotKey: const Value<String?>('effective:reported'),
              status: OutcomeReportStatus.submitted.name,
              outcome: Value<String?>(
                CalendarEventStatus.completedHappened.name,
              ),
              activityDate: today.iso8601,
              createdAtUtc: DateTime.utc(2026, 8, 25, 8),
              updatedAtUtc: DateTime.utc(2026, 8, 25, 8),
            ),
          );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      final byTitle = {
        for (final entry in timeline.history) entry.title: entry,
      };
      expect(byTitle['Reported']!.statusLabel, 'Completed');
      expect(byTitle['Awaiting report']!.statusLabel, 'Unreported');
      expect(byTitle['Missed report']!.statusLabel, 'Missed');
      expect(byTitle['Did not attempt report']!.statusLabel, 'Did Not Attempt');
      expect(
        timeline.history.where((entry) => entry.statusLabel == 'Scheduled'),
        isEmpty,
      );
    },
  );

  test(
    'C6: History uses factual time and Record Created is not pinned',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 26, 2));
      addTearDown(harness.database.close);
      const historyToday = PlannerDate(year: 2026, month: 8, day: 26);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: 'c6000000-0000-4000-8000-000000000105',
        title: 'Later same-day event',
        date: today,
        startMinute: 16 * 60,
      );
      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: historyToday,
      );
      final eventIndex = timeline.history.indexWhere(
        (entry) => entry.title == 'Later same-day event',
      );
      final createdIndex = timeline.history.indexWhere(
        (entry) => entry.title == 'Record Created',
      );
      expect(eventIndex, greaterThanOrEqualTo(0));
      expect(createdIndex, greaterThanOrEqualTo(0));
      expect(
        timeline.history[eventIndex].chronology.isBefore(
          timeline.history[createdIndex].chronology,
        ),
        isTrue,
        reason: 'Record Created is factual chronology, not a pinned footer.',
      );
    },
  );

  test(
    'Contact Timeline: a future participant snapshot stays in Future exactly once',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 2));
      addTearDown(harness.database.close);
      const eventId = 'c6000000-0000-4000-8000-000000000110';
      const futureDate = PlannerDate(year: 2026, month: 8, day: 28);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: eventId,
        title: 'Future snapshot visit',
        date: futureDate,
        startMinute: 10 * 60,
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: futureDate,
      );
      await harness.database.into(harness.database.eventOccurrenceParticipants).insert(
        EventOccurrenceParticipantsCompanion.insert(
          id: 'c6-future-snapshot',
          profileId: harness.profileId,
          eventId: eventId,
          occurrenceId: occurrenceId,
          originalDate: futureDate.toString(),
          contactId: contactId,
          displayNameSnapshot: 'C6 Timeline',
          createdAtUtc: DateTime.utc(2026, 8, 25, 2),
        ),
      );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(
        timeline.timelineFuture.where((entry) => entry.occurrenceId == occurrenceId),
        hasLength(1),
      );
      expect(
        timeline.history.where((entry) => entry.occurrenceId == occurrenceId),
        isEmpty,
      );
    },
  );

  test(
    'Sample Example shape: 98 inherited participant duplicates project once without rewriting owner rows',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 2));
      addTearDown(harness.database.close);
      const eventId = 'c6000000-0000-4000-8000-000000000112';
      const pastDate = PlannerDate(year: 2026, month: 8, day: 20);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: eventId,
        title: 'Inherited duplicate snapshot visit',
        date: pastDate,
        startMinute: 10 * 60,
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: pastDate,
      );

      // Model the upgraded owner database shape from before the generated
      // unique index existed.  This test only changes its in-memory fixture;
      // production readTimeline must never rewrite the inherited duplicates.
      await harness.database.customStatement(
        'DROP INDEX IF EXISTS event_occurrence_participant_unique',
      );
      for (var index = 0; index < 98; index++) {
        await harness.database.into(harness.database.eventOccurrenceParticipants).insert(
          EventOccurrenceParticipantsCompanion.insert(
            id: 'c6-duplicate-$index',
            profileId: harness.profileId,
            eventId: eventId,
            occurrenceId: occurrenceId,
            originalDate: pastDate.iso8601,
            contactId: contactId,
            displayNameSnapshot: 'C6 Timeline',
            createdAtUtc: DateTime.utc(2026, 8, 25, 2),
          ),
        );
      }

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(
        timeline.history.where((entry) => entry.occurrenceId == occurrenceId),
        hasLength(1),
      );
      expect(
        timeline.timelineFuture.where(
          (entry) => entry.occurrenceId == occurrenceId,
        ),
        isEmpty,
      );
      expect(
        await (harness.database.select(harness.database.eventOccurrenceParticipants)
              ..where(
                (table) =>
                    table.eventId.equals(eventId) &
                    table.occurrenceId.equals(occurrenceId) &
                    table.contactId.equals(contactId),
              ))
            .get(),
        hasLength(98),
        reason: 'Inherited owner rows are evidence, not Timeline cleanup.',
      );
    },
  );

  test(
    'Contact Timeline: a future structurally-cancelled occurrence is omitted until historical',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 2));
      addTearDown(harness.database.close);
      const eventId = 'c6000000-0000-4000-8000-000000000111';
      const futureDate = PlannerDate(year: 2026, month: 8, day: 28);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: eventId,
        title: 'Future cancelled visit',
        date: futureDate,
        startMinute: 10 * 60,
      );
      await harness.calendar.cancelEvent(
        profileId: harness.profileId,
        eventId: eventId,
        originalDate: futureDate,
        scope: CalendarEventEditScope.occurrence,
        operationId: 'c6000000-0000-4000-8000-000000000211',
      );
      await (harness.database.update(harness.database.calendarEvents)
            ..where((table) => table.id.equals(eventId)))
          .write(const CalendarEventsCompanion(
            timeZoneId: Value<String?>('Legacy/Unknown'),
          ));

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(
        timeline.timelineFuture.where((entry) => entry.eventId == eventId),
        isEmpty,
      );
      expect(
        timeline.history.where((entry) => entry.eventId == eventId),
        isEmpty,
      );
    },
  );

  test(
    'Contact Timeline: historical cancellation preserves its reported outcome',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 2));
      addTearDown(harness.database.close);
      const eventId = 'c6000000-0000-4000-8000-000000000216';
      const pastDate = PlannerDate(year: 2026, month: 8, day: 20);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: eventId,
        title: 'Reported then cancelled',
        date: pastDate,
        startMinute: 10 * 60,
        requiresReport: true,
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: pastDate,
      );
      await harness.database.into(harness.database.outcomeReports).insert(
            OutcomeReportsCompanion.insert(
              id: 'c6000000-0000-4000-8000-000000000217',
              profileId: harness.profileId,
              sourceType: OutcomeSourceType.event.name,
              sourceId: eventId,
              sourceLabel: 'Reported then cancelled',
              sourceSlotKey: 'event:$eventId:$occurrenceId',
              eventId: const Value<String?>(eventId),
              occurrenceId: Value<String?>(occurrenceId),
              originalDate: Value<String?>(pastDate.iso8601),
              effectiveSlotKey: const Value<String?>('effective:reported'),
              status: OutcomeReportStatus.submitted.name,
              outcome: Value<String?>(
                CalendarEventStatus.completedHappened.name,
              ),
              activityDate: pastDate.iso8601,
              createdAtUtc: DateTime.utc(2026, 8, 20, 3),
              updatedAtUtc: DateTime.utc(2026, 8, 20, 3),
            ),
          );
      await harness.calendar.cancelEvent(
        profileId: harness.profileId,
        eventId: eventId,
        originalDate: pastDate,
        scope: CalendarEventEditScope.occurrence,
        operationId: 'c6000000-0000-4000-8000-000000000218',
      );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      final entry = timeline.history.singleWhere(
        (entry) => entry.occurrenceId == occurrenceId,
      );
      expect(entry.status, CalendarEventStatus.completedHappened);
      expect(entry.statusLabel, 'Completed');
    },
  );

  test(
    'Contact Timeline: snapshot-only future cancellation follows the omission law',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 2));
      addTearDown(harness.database.close);
      const eventId = 'c6000000-0000-4000-8000-000000000219';
      const futureDate = PlannerDate(year: 2026, month: 8, day: 29);
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: eventId,
        title: 'Snapshot cancellation',
        date: futureDate,
        startMinute: 10 * 60,
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: futureDate,
      );
      await harness.database
          .into(harness.database.eventOccurrenceParticipants)
          .insert(
            EventOccurrenceParticipantsCompanion.insert(
              id: 'c6000000-0000-4000-8000-000000000220',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: futureDate.iso8601,
              contactId: contactId,
              displayNameSnapshot: 'C6 Timeline',
              createdAtUtc: DateTime.utc(2026, 8, 25, 2),
            ),
          );
      await (harness.database.delete(harness.database.eventContactLinks)
            ..where((table) => table.eventId.equals(eventId)))
          .go();
      await harness.calendar.cancelEvent(
        profileId: harness.profileId,
        eventId: eventId,
        originalDate: futureDate,
        scope: CalendarEventEditScope.occurrence,
        operationId: 'c6000000-0000-4000-8000-000000000221',
      );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(
        timeline.timelineFuture.where(
          (entry) => entry.occurrenceId == occurrenceId,
        ),
        isEmpty,
      );
      expect(
        timeline.history.where((entry) => entry.occurrenceId == occurrenceId),
        isEmpty,
      );
      expect(
        await (harness.database.select(
          harness.database.eventOccurrenceParticipants,
        )..where((table) => table.occurrenceId.equals(occurrenceId))).get(),
        hasLength(1),
      );
    },
  );

  test(
    'Contact Timeline: Event tables emit only on the Timeline-specific stream',
    () async {
      final harness = await arrange(now: DateTime.utc(2026, 8, 25, 2));
      addTearDown(harness.database.close);
      const eventId = 'c6000000-0000-4000-8000-000000000222';
      await addEvent(
        calendar: harness.calendar,
        contacts: harness.contacts,
        profileId: harness.profileId,
        id: eventId,
        title: 'Timeline stream event',
        date: const PlannerDate(year: 2026, month: 8, day: 29),
        startMinute: 10 * 60,
      );
      await Future<void>.delayed(Duration.zero);
      var broadEmissions = 0;
      final broadSubscription = harness.contacts
          .watchChanges(harness.profileId)
          .listen((_) => broadEmissions++);
      addTearDown(broadSubscription.cancel);
      final timelineChange = harness.contacts
          .watchTimelineEventChanges(harness.profileId)
          .first;

      await (harness.database.update(harness.database.calendarEvents)
            ..where((table) => table.id.equals(eventId)))
          .write(const CalendarEventsCompanion(
            status: Value<String>('cancelled'),
          ));

      expect(await timelineChange, 1);
      await Future<void>.delayed(Duration.zero);
      expect(
        broadEmissions,
        0,
        reason:
            'Event writes must not fan out through the broad Contacts stream.',
      );
    },
  );

  test('C6: Common Events stays hidden until three factual matches', () async {
    final harness = await arrange();
    addTearDown(harness.database.close);
    const eventId = 'c6000000-0000-4000-8000-000000000106';
    await addEvent(
      calendar: harness.calendar,
      contacts: harness.contacts,
      profileId: harness.profileId,
      id: eventId,
      title: 'Weekly visit',
      date: const PlannerDate(year: 2026, month: 8, day: 3),
      startMinute: 10 * 60,
      status: CalendarEventStatus.completedHappened,
    );
    final dates = <PlannerDate>[
      const PlannerDate(year: 2026, month: 8, day: 3),
      const PlannerDate(year: 2026, month: 8, day: 10),
      const PlannerDate(year: 2026, month: 8, day: 17),
    ];
    for (var index = 0; index < dates.length; index++) {
      final date = dates[index];
      await harness.database
          .into(harness.database.eventOccurrenceParticipants)
          .insert(
            EventOccurrenceParticipantsCompanion.insert(
              id: 'c6-snapshot-$index',
              profileId: harness.profileId,
              eventId: eventId,
              occurrenceId: CalendarEventOccurrenceIdentity.forDate(
                eventId: eventId,
                originalDate: date,
              ),
              originalDate: date.toString(),
              contactId: contactId,
              displayNameSnapshot: 'C6 Timeline',
              createdAtUtc: DateTime.utc(2026, 8, 25),
            ),
          );
      final patterns = await harness.contacts.readCommonEventPatterns(
        profileId: harness.profileId,
        contactId: contactId,
      );
      if (index < 2) {
        expect(
          patterns,
          isEmpty,
          reason: '${index + 1} occurrences are insufficient',
        );
      } else {
        expect(patterns, hasLength(1));
        expect(patterns.single.count, 3);
      }
    }
  });

  test(
    'Contacts final delta: Timeline projects only linked incomplete dated Tasks once',
    () async {
      final harness = await arrange();
      addTearDown(harness.database.close);
      const futureTaskId = 'c6000000-0000-4000-8000-000000000301';
      const recurringTaskId = 'c6000000-0000-4000-8000-000000000302';
      const overdueTaskId = 'c6000000-0000-4000-8000-000000000303';
      const undatedTaskId = 'c6000000-0000-4000-8000-000000000304';
      const completedTaskId = 'c6000000-0000-4000-8000-000000000305';
      const skippedTaskId = 'c6000000-0000-4000-8000-000000000306';
      const cancelledTaskId = 'c6000000-0000-4000-8000-000000000307';
      final createdAt = DateTime.utc(2026, 8, 25, 2);

      Future<void> seedTask({
        required String id,
        required String title,
        String? dueDate,
        int? dueMinute,
        PlannerTaskStatus status = PlannerTaskStatus.incomplete,
        String? recurrenceFrequency,
      }) async {
        await harness.database
            .into(harness.database.plannerTasks)
            .insert(
              PlannerTasksCompanion.insert(
                id: id,
                profileId: harness.profileId,
                title: title,
                dueDate: dueDate == null
                    ? const Value<String>.absent()
                    : Value<String>(dueDate),
                dueMinute: Value<int?>(dueMinute),
                recurrenceFrequency: recurrenceFrequency == null
                    ? const Value<String>.absent()
                    : Value<String>(recurrenceFrequency),
                status: Value<String>(status.name),
                createdAtUtc: createdAt,
                updatedAtUtc: createdAt,
              ),
            );
        await harness.database
            .into(harness.database.taskContactLinks)
            .insert(
              TaskContactLinksCompanion.insert(
                id: 'link-$id',
                profileId: harness.profileId,
                taskId: id,
                contactId: contactId,
                createdAtUtc: createdAt,
              ),
            );
      }

      await seedTask(
        id: futureTaskId,
        title: 'Future contact task',
        dueDate: '2026-08-27',
        dueMinute: 18 * 60,
      );
      await seedTask(
        id: recurringTaskId,
        title: 'Recurring contact task',
        dueDate: '2026-08-26',
        recurrenceFrequency: 'weekly',
      );
      await seedTask(
        id: overdueTaskId,
        title: 'Overdue contact task',
        dueDate: '2026-08-24',
      );
      await seedTask(id: undatedTaskId, title: 'Undated contact task');
      await seedTask(
        id: completedTaskId,
        title: 'Completed contact task',
        dueDate: '2026-08-27',
        status: PlannerTaskStatus.completed,
      );
      await seedTask(
        id: skippedTaskId,
        title: 'Skipped contact task',
        dueDate: '2026-08-27',
        status: PlannerTaskStatus.skipped,
      );
      await seedTask(
        id: cancelledTaskId,
        title: 'Cancelled contact task',
        dueDate: '2026-08-27',
        status: PlannerTaskStatus.cancelled,
      );

      final timeline = await harness.contacts.readTimeline(
        profileId: harness.profileId,
        contactId: contactId,
        today: today,
      );
      expect(timeline.profileUpcoming.map((entry) => entry.taskId), <String>[
        recurringTaskId,
        futureTaskId,
      ]);
      expect(timeline.futureTasks.map((entry) => entry.taskId), <String>[
        recurringTaskId,
        futureTaskId,
      ]);
      expect(timeline.futureTasks.map((entry) => entry.title), <String>[
        'Recurring contact task',
        'Future contact task',
      ]);
      expect(
        timeline.futureTasks.map((entry) => entry.statusLabel),
        everyElement('Incomplete'),
      );
      expect(timeline.futureTasks.first.subtitle, 'Due Aug 26, 2026');
      expect(timeline.futureTasks.last.subtitle, 'Due Aug 27, 2026 · 6:00 PM');
      expect(timeline.timelineFuture.map((entry) => entry.title), <String>[
        'Future contact task',
        'Recurring contact task',
      ]);
      expect(
        timeline.history.map((entry) => entry.title),
        contains('Record Created'),
      );
      expect(
        timeline.history.where(
          (entry) => entry.kind == ContactTimelineKind.plannerTask,
        ),
        isEmpty,
        reason:
            'Completed, skipped, cancelled, overdue, and undated Tasks are '
            'not factual Contact Timeline history entries.',
      );
    },
  );
}
