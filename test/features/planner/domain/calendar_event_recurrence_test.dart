import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:uuid/uuid.dart';

void main() {
  const januaryMonthEnd = PlannerDate(year: 2025, month: 1, day: 31);

  test(
    'AC-E-007,008 / OPD-1-016: monthly recurrence clamps each month end',
    () {
      const rule = CalendarRecurrenceRule(
        frequency: CalendarRecurrenceFrequency.monthly,
      );

      expect(
        rule.occurrenceAt(startDate: januaryMonthEnd, index: 1),
        const PlannerDate(year: 2025, month: 2, day: 28),
      );
      expect(
        rule.occurrenceAt(startDate: januaryMonthEnd, index: 2),
        const PlannerDate(year: 2025, month: 3, day: 31),
      );
      expect(
        rule.occurrenceIndexOn(
          startDate: januaryMonthEnd,
          targetDate: const PlannerDate(year: 2025, month: 2, day: 27),
        ),
        isNull,
      );
    },
  );

  test(
    'AC-E-007,008 / OPD-1-017: Feb 29 recurs on Feb 28 in non-leap years',
    () {
      const rule = CalendarRecurrenceRule(
        frequency: CalendarRecurrenceFrequency.yearly,
      );
      const leapDay = PlannerDate(year: 2024, month: 2, day: 29);

      expect(
        rule.occurrenceAt(startDate: leapDay, index: 1),
        const PlannerDate(year: 2025, month: 2, day: 28),
      );
      expect(
        rule.occurrenceAt(startDate: leapDay, index: 4),
        const PlannerDate(year: 2028, month: 2, day: 29),
      );
    },
  );

  test('AC-E-009,010: date and count end rules are deterministic', () {
    const byDate = CalendarRecurrenceRule(
      frequency: CalendarRecurrenceFrequency.daily,
      endMode: CalendarRecurrenceEndMode.onDate,
      endDate: PlannerDate(year: 2025, month: 2, day: 2),
    );
    const byCount = CalendarRecurrenceRule(
      frequency: CalendarRecurrenceFrequency.weekly,
      endMode: CalendarRecurrenceEndMode.afterCount,
      occurrenceCount: 2,
    );

    expect(
      byDate.occurrenceIndexOn(
        startDate: januaryMonthEnd,
        targetDate: const PlannerDate(year: 2025, month: 2, day: 2),
      ),
      2,
    );
    expect(
      byDate.occurrenceIndexOn(
        startDate: januaryMonthEnd,
        targetDate: const PlannerDate(year: 2025, month: 2, day: 3),
      ),
      isNull,
    );
    expect(
      byCount.occurrenceIndexOn(
        startDate: januaryMonthEnd,
        targetDate: const PlannerDate(year: 2025, month: 2, day: 14),
      ),
      isNull,
    );
  });

  test(
    'AC-E-014,019,024: occurrence and exception identities are stable UUIDs',
    () {
      const eventId = '11111111-1111-4111-8111-111111111111';
      const operationId = '22222222-2222-4222-8222-222222222222';
      final first = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: januaryMonthEnd,
      );
      final retry = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: januaryMonthEnd,
      );
      final exception = CalendarEventExceptionIdentity.forOperation(
        operationId: operationId,
        occurrenceId: first,
      );

      expect(first, retry);
      expect(Uuid.isValidUUID(fromString: first), isTrue);
      expect(Uuid.isValidUUID(fromString: exception), isTrue);
    },
  );

  test('AC-E-005,006,021: elapsed time does not infer a factual outcome', () {
    const occurrence = CalendarEventOccurrence(
      id: 'occurrence',
      eventId: 'event',
      profileId: 'profile',
      title: 'Report-required event',
      timing: CalendarEventTiming.timed,
      originalDate: januaryMonthEnd,
      displayDate: januaryMonthEnd,
      status: CalendarEventStatus.scheduled,
      requiresReport: true,
      recurrence: CalendarRecurrenceRule(),
      endUtc: null,
    );

    expect(occurrence.status, CalendarEventStatus.scheduled);
    expect(
      occurrence.isAwaitingReport(
        nowUtc: DateTime.utc(2030),
        displayToday: const PlannerDate(year: 2030, month: 1, day: 1),
      ),
      isFalse,
    );
  });
}
