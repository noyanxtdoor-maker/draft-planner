import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

void main() {
  group('WeeklyPeriod', () {
    test('accepts a non-Monday start and stays exactly 7 days', () {
      final period = WeeklyPeriod(
        start: const PlannerDate(year: 2026, month: 8, day: 11),
        end: const PlannerDate(year: 2026, month: 8, day: 17),
      );
      expect(period.start.weekday, DateTime.tuesday);
      expect(period.contains(const PlannerDate(year: 2026, month: 8, day: 11)),
          isTrue);
      expect(period.contains(const PlannerDate(year: 2026, month: 8, day: 17)),
          isTrue);
      expect(period.contains(const PlannerDate(year: 2026, month: 8, day: 18)),
          isFalse);
    });

    test('containing uses the configured start day', () {
      final period = WeeklyPeriod.containing(
        const PlannerDate(year: 2026, month: 8, day: 13),
        startDay: DateTime.sunday,
      );
      expect(period.start, const PlannerDate(year: 2026, month: 8, day: 9));
      expect(period.end, const PlannerDate(year: 2026, month: 8, day: 15));
    });

    test('containing defaults to Monday', () {
      final period = WeeklyPeriod.containing(
        const PlannerDate(year: 2026, month: 8, day: 13),
      );
      expect(period.start, const PlannerDate(year: 2026, month: 8, day: 10));
      expect(period.end, const PlannerDate(year: 2026, month: 8, day: 16));
    });

    test('rejects a window that is not exactly 7 days', () {
      expect(
        () => WeeklyPeriod(
          start: const PlannerDate(year: 2026, month: 8, day: 10),
          end: const PlannerDate(year: 2026, month: 8, day: 15),
        ),
        throwsA(isA<WeeklyPlanningValidationException>()),
      );
      expect(
        () => WeeklyPeriod(
          start: const PlannerDate(year: 2026, month: 8, day: 10),
          end: const PlannerDate(year: 2026, month: 8, day: 17),
        ),
        throwsA(isA<WeeklyPlanningValidationException>()),
      );
    });

    test('shifted periods stay anchored on the same start day', () {
      final period = WeeklyPeriod.containing(
        const PlannerDate(year: 2026, month: 8, day: 13),
        startDay: DateTime.friday,
      );
      final next = period.containingOf(period.start.addDays(7));
      expect(next.start, period.start.addDays(7));
      expect(next.start.weekday, DateTime.friday);
    });
  });
}

extension on WeeklyPeriod {
  WeeklyPeriod containingOf(PlannerDate date) => WeeklyPeriod.containing(
    date,
    startDay: start.weekday,
  );
}
