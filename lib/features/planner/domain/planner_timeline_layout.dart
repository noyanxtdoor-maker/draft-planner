import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';

final class PlannerTimelinePlacement {
  const PlannerTimelinePlacement({
    required this.event,
    required this.column,
    required this.columnCount,
  });

  final PlannerCalendarItem event;
  final int column;
  final int columnCount;
}

abstract final class PlannerTimelineLayout {
  static List<PlannerTimelinePlacement> arrange(
    List<PlannerCalendarItem> events,
  ) {
    final timed =
        events
            .where(
              (event) => event.startLocal != null && event.endLocal != null,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final start = left.startLocal!.compareTo(right.startLocal!);
            return start != 0
                ? start
                : right.endLocal!.compareTo(left.endLocal!);
          });
    final result = <PlannerTimelinePlacement>[];
    for (final group in _overlapGroups(timed)) {
      final active = <_ActiveColumn>[];
      final assigned = <PlannerCalendarItem, int>{};
      var columnCount = 1;
      for (final event in group) {
        active.removeWhere((entry) => !entry.end.isAfter(event.startLocal!));
        var column = 0;
        final occupied = active.map((entry) => entry.column).toSet();
        while (occupied.contains(column)) {
          column += 1;
        }
        assigned[event] = column;
        active.add(_ActiveColumn(column: column, end: event.endLocal!));
        if (column + 1 > columnCount) {
          columnCount = column + 1;
        }
      }
      for (final event in group) {
        result.add(
          PlannerTimelinePlacement(
            event: event,
            column: assigned[event]!,
            columnCount: columnCount,
          ),
        );
      }
    }
    return result;
  }

  static List<List<PlannerCalendarItem>> _overlapGroups(
    List<PlannerCalendarItem> events,
  ) {
    final groups = <List<PlannerCalendarItem>>[];
    var current = <PlannerCalendarItem>[];
    DateTime? furthestEnd;
    for (final event in events) {
      if (current.isNotEmpty &&
          furthestEnd != null &&
          !event.startLocal!.isBefore(furthestEnd)) {
        groups.add(current);
        current = <PlannerCalendarItem>[];
        furthestEnd = null;
      }
      current.add(event);
      if (furthestEnd == null || event.endLocal!.isAfter(furthestEnd)) {
        furthestEnd = event.endLocal;
      }
    }
    if (current.isNotEmpty) {
      groups.add(current);
    }
    return groups;
  }
}

final class _ActiveColumn {
  const _ActiveColumn({required this.column, required this.end});

  final int column;
  final DateTime end;
}

int snapPlannerMinute(int minute, int snapMinutes) {
  final snapped = (minute / snapMinutes).round() * snapMinutes;
  return snapped.clamp(0, 1439);
}

int plannerInitialScrollMinute({
  required PlannerSettings settings,
  required PlannerDate selectedDate,
  required DateTime now,
  int? firstRelevantEventMinute,
}) {
  final visibleStart = settings.visibleStartHour * 60;
  final visibleEnd = settings.visibleEndHour * 60;
  final requested = switch (settings.initialScrollBehavior) {
    PlannerInitialScrollBehavior.currentTime
        when selectedDate == PlannerDate.fromDateTime(now) =>
      now.hour * 60 + now.minute,
    PlannerInitialScrollBehavior.currentTime =>
      firstRelevantEventMinute ?? visibleStart,
    PlannerInitialScrollBehavior.visibleStart ||
    PlannerInitialScrollBehavior.dayStart => visibleStart,
  };
  return requested.clamp(visibleStart, visibleEnd - 15);
}
