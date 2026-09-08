import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

void main() {
  test(
    'E2 derives threshold-three patterns from distinct canonical Timeline '
    'History occurrences only',
    () {
      ContactTimelineEntry occurrence({
        required String eventId,
        required String occurrenceId,
        required PlannerDate date,
        required String title,
        CalendarEventStatus status = CalendarEventStatus.completedHappened,
        int? startMinute = 9 * 60,
        bool upcoming = false,
        bool structurallyCancelled = false,
        bool submitted = true,
      }) => ContactTimelineEntry(
        kind: ContactTimelineKind.eventOccurrence,
        date: date,
        chronology: DateTime(
          date.year,
          date.month,
          date.day,
          (startMinute ?? 0) ~/ 60,
          (startMinute ?? 0) % 60,
        ),
        title: title,
        status: status,
        eventId: eventId,
        originalDate: date,
        occurrenceId: occurrenceId,
        effectiveStartMinute: startMinute,
        isUpcoming: upcoming,
        isStructurallyCancelled: structurallyCancelled,
        hasSubmittedOutcome: submitted,
      );

      final canonical = <ContactTimelineEntry>[
        occurrence(
          eventId: 'event-a',
          occurrenceId: 'a-1',
          date: const PlannerDate(year: 2026, month: 8, day: 3),
          title: 'Same title',
        ),
        occurrence(
          eventId: 'event-a',
          occurrenceId: 'a-2',
          date: const PlannerDate(year: 2026, month: 8, day: 10),
          title: 'Same title',
        ),
        occurrence(
          eventId: 'event-a',
          occurrenceId: 'a-3',
          date: const PlannerDate(year: 2026, month: 8, day: 17),
          title: 'Same title',
          structurallyCancelled: true,
        ),
      ];
      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          occurrence(
            eventId: 'future-series',
            occurrenceId: 'future-1',
            date: const PlannerDate(year: 2026, month: 9, day: 7),
            title: 'Future scheduled',
            status: CalendarEventStatus.scheduled,
            upcoming: true,
            submitted: false,
          ),
        ],
        history: <ContactTimelineEntry>[
          ...canonical,
          canonical.first,
          occurrence(
            eventId: 'event-a',
            occurrenceId: 'a-different-weekday',
            date: const PlannerDate(year: 2026, month: 8, day: 18),
            title: 'Same title',
          ),
          occurrence(
            eventId: 'event-b',
            occurrenceId: 'b-1',
            date: const PlannerDate(year: 2026, month: 8, day: 3),
            title: 'Same title',
          ),
          occurrence(
            eventId: 'event-b',
            occurrenceId: 'b-2',
            date: const PlannerDate(year: 2026, month: 8, day: 10),
            title: 'Same title',
          ),
          occurrence(
            eventId: 'cancelled-no-report',
            occurrenceId: 'cancelled-1',
            date: const PlannerDate(year: 2026, month: 8, day: 3),
            title: 'Cancelled only',
            status: CalendarEventStatus.cancelled,
            structurallyCancelled: true,
            submitted: false,
          ),
        ],
      );

      final patterns = commonEventPatternsFromTimeline(timeline);

      expect(patterns, hasLength(1));
      expect(patterns.single.eventId, 'event-a');
      expect(patterns.single.count, 3);
      expect(patterns.single.weekdayLabel, 'Mon');
      expect(patterns.single.startMinuteLabel, '9:00 AM');
      expect(patterns.single.title, 'Same title');
    },
  );
}
