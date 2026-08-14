import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

abstract interface class WeeklyPlanningRepository {
  Future<PlannerDate> todayForProfile(String profileId);

  Future<WeeklyPlan> openOrCreate({
    required String profileId,
    required PlannerDate date,
    int startDay = DateTime.monday,
  });

  /// Read-only existence/identity lookup for the exact resolved period.
  /// Never creates a row; used by Home to determine whether the current
  /// period is established without side effects.
  Future<WeeklyPlan?> readPlanForPeriod({
    required String profileId,
    required PlannerDate periodStart,
  });

  /// Lightweight read-only existence check for the exact resolved period.
  /// Never creates a row and never materializes the rich projection
  /// (`WeeklyPlan.indicators` / `IndicatorRepository.readHome`); used by
  /// Home's established signal and the current-period establishment gate.
  Future<bool> periodExists({
    required String profileId,
    required PlannerDate periodStart,
  });

  /// Lightweight idempotent establishment of the exact resolved period row.
  /// Same canonical profile + period row semantics as [openOrCreate] but
  /// never calls `_mapPlan` / `IndicatorRepository.readHome`.  Historical
  /// periods must never call this.
  Future<void> ensurePeriod({
    required String profileId,
    required PlannerDate periodStart,
    int startDay = DateTime.monday,
  });

  Future<WeeklyPlan?> readPlan({
    required String profileId,
    required String planId,
  });

  Future<List<WeeklyPlan>> readHistory(String profileId);
}
