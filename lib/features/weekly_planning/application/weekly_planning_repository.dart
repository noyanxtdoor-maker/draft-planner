import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

abstract interface class WeeklyPlanningRepository {
  Future<PlannerDate> todayForProfile(String profileId);

  Future<WeeklyPlan> openOrCreate({
    required String profileId,
    required PlannerDate date,
  });

  Future<WeeklyPlan?> readPlan({
    required String profileId,
    required String planId,
  });

  Future<List<WeeklyPlan>> readHistory(String profileId);
}
