import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/time/week_period.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

void main() {
  group('resolveWeek', () {
    test('Monday default resolves the ISO week', () {
      // 2026-08-13 is a Thursday.
      final week = resolveWeek(
        date: const PlannerDate(year: 2026, month: 8, day: 13),
        startDay: DateTime.monday,
      );
      expect(week.start, const PlannerDate(year: 2026, month: 8, day: 10));
      expect(week.end, const PlannerDate(year: 2026, month: 8, day: 16));
    });

    test('all 7 start days resolve a window starting on the configured day', () {
      const date = PlannerDate(year: 2026, month: 8, day: 13); // Thursday
      for (var startDay = DateTime.monday; startDay <= DateTime.sunday; startDay++) {
        final week = resolveWeek(date: date, startDay: startDay);
        expect(week.start.weekday, startDay);
        expect(week.end, week.start.addDays(6));
        expect(week.contains(date), isTrue);
        // The window is exactly 7 consecutive days.
        expect(week.end.addDays(1), week.start.addDays(7));
      }
    });

    test('dates before/at/after the boundary belong to the right window', () {
      // Tuesday start: week = 2026-08-11 .. 2026-08-17.
      const tueStart = PlannerDate(year: 2026, month: 8, day: 11);
      const monBefore = PlannerDate(year: 2026, month: 8, day: 10);
      const sunAfter = PlannerDate(year: 2026, month: 8, day: 17);
      expect(resolveWeek(date: monBefore, startDay: DateTime.tuesday).start,
          const PlannerDate(year: 2026, month: 8, day: 4));
      expect(resolveWeek(date: tueStart, startDay: DateTime.tuesday).start, tueStart);
      expect(resolveWeek(date: sunAfter, startDay: DateTime.tuesday).start, tueStart);
    });

    test('month rollover stays local-calendar correct', () {
      // Sunday start: 2026-08-30 (Sunday) .. 2026-09-05.
      final week = resolveWeek(
        date: const PlannerDate(year: 2026, month: 8, day: 31),
        startDay: DateTime.sunday,
      );
      expect(week.start, const PlannerDate(year: 2026, month: 8, day: 30));
      expect(week.end, const PlannerDate(year: 2026, month: 9, day: 5));
    });

    test('December/January rollover stays local-calendar correct', () {
      // Sunday start: 2026-12-27 .. 2027-01-02, containing 2026-12-31.
      final week = resolveWeek(
        date: const PlannerDate(year: 2026, month: 12, day: 31),
        startDay: DateTime.sunday,
      );
      expect(week.start, const PlannerDate(year: 2026, month: 12, day: 27));
      expect(week.end, const PlannerDate(year: 2027, month: 1, day: 2));
      expect(week.contains(const PlannerDate(year: 2027, month: 1, day: 1)),
          isTrue);
    });

    test('leap year February boundary stays correct', () {
      // Monday start around 2028-02-29 (leap day is a Tuesday).
      final week = resolveWeek(
        date: const PlannerDate(year: 2028, month: 2, day: 29),
        startDay: DateTime.monday,
      );
      expect(week.start, const PlannerDate(year: 2028, month: 2, day: 28));
      expect(week.end, const PlannerDate(year: 2028, month: 3, day: 5));
    });

    test('local-calendar semantics: no UTC conversion shifts identity', () {
      // The same wall-clock date always resolves the same window regardless of
      // time zone, because identity is built from PlannerDate fields only.
      final weekA = resolveWeek(
        date: const PlannerDate(year: 2026, month: 8, day: 13),
        startDay: DateTime.wednesday,
      );
      final weekB = resolveWeek(
        date: const PlannerDate(year: 2026, month: 8, day: 13),
        startDay: DateTime.wednesday,
      );
      expect(weekA.start, weekB.start);
      expect(weekA.key, '2026-08-12');
    });

    test('shifting moves by exactly +/-7 days with the same start day', () {
      final week = resolveWeek(
        date: const PlannerDate(year: 2026, month: 8, day: 13),
        startDay: DateTime.tuesday,
      );
      final previous = week.shifted(-1);
      final next = week.shifted(1);
      expect(previous.start, week.start.addDays(-7));
      expect(previous.start.weekday, DateTime.tuesday);
      expect(next.start, week.start.addDays(7));
      expect(next.start.weekday, DateTime.tuesday);
    });

    test('rejects invalid start days', () {
      expect(
        () => resolveWeek(
          date: const PlannerDate(year: 2026, month: 8, day: 13),
          startDay: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => resolveWeek(
          date: const PlannerDate(year: 2026, month: 8, day: 13),
          startDay: 8,
        ),
        throwsArgumentError,
      );
    });
  });
}
