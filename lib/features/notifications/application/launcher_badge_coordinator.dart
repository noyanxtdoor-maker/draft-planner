import 'package:rmplanner/core/notifications/launcher_badge_gateway.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';

final class LauncherBadgeCoordinator {
  const LauncherBadgeCoordinator({
    required this.calendarSource,
    required this.taskSource,
    required this.gateway,
  });

  static const int horizonDays = 42;

  final CalendarEventRangeSource calendarSource;
  final PlannerBadgeTaskSource taskSource;
  final LauncherBadgeGateway gateway;

  Future<int> refresh({
    required String profileId,
    required PlannerDate today,
    required DateTime nowUtc,
  }) async {
    final endDate = today.addDays(horizonDays);
    final results = await Future.wait<Object>(<Future<Object>>[
      calendarSource.readRange(
        profileId: profileId,
        startDate: today,
        endDate: endDate,
      ),
      taskSource.readActionableBadgeTasks(
        profileId: profileId,
        startDate: today,
        endDate: endDate,
      ),
    ]);
    final events = results[0] as List<PlannerCalendarItem>;
    final tasks = results[1] as List<String>;
    final eventIds = <String>{
      for (final event in events)
        if (_isActionableEvent(event, nowUtc)) event.id,
    };
    final count = eventIds.length + tasks.toSet().length;
    await gateway.setCount(count);
    return count;
  }

  static bool _isActionableEvent(PlannerCalendarItem event, DateTime nowUtc) {
    if (event.state != PlannerEventState.scheduled || event.hasOutcomeReport) {
      return false;
    }
    if (event.timing == PlannerEventTiming.allDay) return true;
    final end = event.endUtc;
    if (end == null) return false;
    return end.isAfter(nowUtc) || event.requiresReport;
  }
}
