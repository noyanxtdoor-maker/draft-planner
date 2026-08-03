import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';

void main() {
  const date = PlannerDate(year: 2026, month: 7, day: 29);

  PlannerCalendarItem event(String id, int startMinute, int endMinute) {
    return PlannerCalendarItem(
      id: id,
      title: id,
      date: date,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: DateTime(2026, 7, 29, startMinute ~/ 60, startMinute % 60),
      endLocal: DateTime(2026, 7, 29, endMinute ~/ 60, endMinute % 60),
    );
  }

  test(
    'overlapping events receive readable columns while touching events do not',
    () {
      final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
        event('a', 9 * 60, 10 * 60),
        event('b', 9 * 60 + 30, 10 * 60 + 30),
        event('c', 10 * 60 + 30, 11 * 60),
      ]);

      final a = placements.singleWhere((item) => item.event.id == 'a');
      final b = placements.singleWhere((item) => item.event.id == 'b');
      final c = placements.singleWhere((item) => item.event.id == 'c');
      expect(a.columnCount, 2);
      expect(b.columnCount, 2);
      expect(a.column, isNot(b.column));
      expect(c.columnCount, 1);
    },
  );

  test('low-zoom readable height reserves a lane for a touching neighbor', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('short', 9 * 60, 9 * 60 + 15),
      event('next', 9 * 60 + 15, 9 * 60 + 30),
    ], hourHeight: 60);

    final short = placements.singleWhere((item) => item.event.id == 'short');
    final next = placements.singleWhere((item) => item.event.id == 'next');
    expect(short.columnCount, 2);
    expect(next.columnCount, 2);
    expect(short.column, isNot(next.column));
  });

  test('time snapping is deterministic and clamped to the day', () {
    expect(snapPlannerMinute(9 * 60 + 7, 15), 9 * 60);
    expect(snapPlannerMinute(9 * 60 + 8, 15), 9 * 60 + 15);
    expect(snapPlannerMinute(-20, 15), 0);
    expect(snapPlannerMinute(1500, 15), 1439);
  });

  test(
    'initial scroll follows today, other-day, and visible-start settings',
    () {
      const settings = PlannerSettings.defaults();
      final now = DateTime(2026, 7, 29, 14, 37);

      expect(
        plannerInitialScrollMinute(
          settings: settings,
          selectedDate: date,
          now: now,
          firstRelevantEventMinute: 9 * 60,
        ),
        14 * 60 + 37,
      );
      expect(
        plannerInitialScrollMinute(
          settings: settings,
          selectedDate: date.addDays(1),
          now: now,
          firstRelevantEventMinute: 9 * 60 + 15,
        ),
        9 * 60 + 15,
      );
      expect(
        plannerInitialScrollMinute(
          settings: settings.copyWith(
            initialScrollBehavior: PlannerInitialScrollBehavior.visibleStart,
          ),
          selectedDate: date,
          now: now,
          firstRelevantEventMinute: 9 * 60,
        ),
        settings.visibleStartHour * 60,
      );
    },
  );
}
