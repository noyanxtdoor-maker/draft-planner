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

/// Pixel geometry shared by the centered timeline and the pager previews.
///
/// Keeping the minute-to-pixel conversion in one production helper prevents
/// a visual minimum-height rule from silently changing the duration that an
/// Event represents. A 15-minute Event therefore always occupies exactly
/// one quarter of the active hour height.
abstract final class PlannerTimelineGeometry {
  static const int minutesPerHour = 60;
  static const int quarterHourMinutes = 15;

  static double pixelsPerMinute(double hourHeight) {
    return hourHeight / minutesPerHour;
  }

  static double yForMinute({
    required int minute,
    required int visibleStartMinute,
    required double hourHeight,
  }) {
    return (minute - visibleStartMinute) * pixelsPerMinute(hourHeight);
  }

  static double heightForDuration({
    required int durationMinutes,
    required double hourHeight,
  }) {
    return durationMinutes * pixelsPerMinute(hourHeight);
  }

  static double quarterHourHeight(double hourHeight) {
    return heightForDuration(
      durationMinutes: quarterHourMinutes,
      hourHeight: hourHeight,
    );
  }

  /// Resolve a visible Event rectangle without applying a minimum visual
  /// height. Clipping keeps the rectangle inside the configured timeline;
  /// the returned height still represents the clipped minute duration.
  static PlannerTimelineEventGeometry event({
    required int startMinute,
    required int endMinute,
    required int visibleStartMinute,
    required int visibleEndMinute,
    required double hourHeight,
  }) {
    final clippedStart = startMinute
        .clamp(visibleStartMinute, visibleEndMinute - quarterHourMinutes)
        .toInt();
    final minimumEnd = (clippedStart + quarterHourMinutes).clamp(
      visibleStartMinute,
      visibleEndMinute,
    );
    final clippedEnd = endMinute.clamp(minimumEnd, visibleEndMinute).toInt();
    final top = yForMinute(
      minute: clippedStart,
      visibleStartMinute: visibleStartMinute,
      hourHeight: hourHeight,
    );
    return PlannerTimelineEventGeometry(
      clippedStartMinute: clippedStart,
      clippedEndMinute: clippedEnd,
      top: top,
      height: heightForDuration(
        durationMinutes: clippedEnd - clippedStart,
        hourHeight: hourHeight,
      ),
    );
  }
}

final class PlannerTimelineEventGeometry {
  const PlannerTimelineEventGeometry({
    required this.clippedStartMinute,
    required this.clippedEndMinute,
    required this.top,
    required this.height,
  });

  final int clippedStartMinute;
  final int clippedEndMinute;
  final double top;
  final double height;

  double get bottom => top + height;
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
