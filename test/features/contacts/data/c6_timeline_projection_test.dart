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
        timeZoneId: 'Asia/Manila',
        requiresReport: false,
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
}
