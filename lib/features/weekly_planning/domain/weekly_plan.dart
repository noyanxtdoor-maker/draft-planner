import 'package:rmplanner/core/time/week_period.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum WeeklyPlanState { draft, active, reviewDue, reviewed, historical }

final class WeeklyPeriod {
  WeeklyPeriod({required this.start, required this.end}) {
    // A Weekly Plan is exactly 7 consecutive local-calendar days.  The first
    // day follows the configured start-of-week preference (Monday by
    // default), so no specific weekday is required here.
    if (end != start.addDays(6)) {
      throw const WeeklyPlanningValidationException(
        'A Weekly Plan must cover exactly 7 consecutive days.',
      );
    }
  }

  factory WeeklyPeriod.containing(
    PlannerDate date, {
    int startDay = DateTime.monday,
  }) {
    final week = resolveWeek(date: date, startDay: startDay);
    return WeeklyPeriod(start: week.start, end: week.end);
  }

  final PlannerDate start;
  final PlannerDate end;

  IndicatorPeriod get indicatorPeriod =>
      IndicatorPeriod(start: start, end: end);

  bool contains(PlannerDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;
}

final class WeeklyIndicatorReview {
  const WeeklyIndicatorReview({
    required this.indicatorKey,
    required this.label,
    required this.actual,
    required this.target,
    required this.scheduled,
  });

  final String indicatorKey;
  final String label;
  final IndicatorAmount actual;
  final IndicatorTarget target;
  final IndicatorAmount scheduled;
}

final class WeeklyPlan {
  const WeeklyPlan({
    required this.id,
    required this.profileId,
    required this.period,
    required this.timeZoneId,
    required this.storedState,
    required this.indicators,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.reviewCompletedAtUtc,
  });

  final String id;
  final String profileId;
  final WeeklyPeriod period;
  final String timeZoneId;
  final WeeklyPlanState storedState;
  final List<WeeklyIndicatorReview> indicators;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? reviewCompletedAtUtc;

  WeeklyPlanState effectiveState(PlannerDate today) {
    if ((storedState == WeeklyPlanState.draft ||
            storedState == WeeklyPlanState.active) &&
        today.compareTo(period.end) > 0) {
      return WeeklyPlanState.reviewDue;
    }
    return storedState;
  }

  bool get isReadOnly =>
      storedState == WeeklyPlanState.reviewed ||
      storedState == WeeklyPlanState.historical;
}

final class WeeklyPlanningValidationException implements Exception {
  const WeeklyPlanningValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
