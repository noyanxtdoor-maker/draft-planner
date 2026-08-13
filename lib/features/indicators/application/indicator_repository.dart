import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

abstract interface class IndicatorRepository {
  Stream<void> watchChanges(String profileId);

  Future<PlannerDate?> readNextTempleVisit({
    required String profileId,
    required PlannerDate today,
  });

  Future<HomeIndicatorSnapshot> readHome({
    required String profileId,
    required IndicatorPeriod period,
    required PlannerDate today,
  });

  Future<IndicatorDetail?> readDetail({
    required String profileId,
    required String indicatorKey,
    required IndicatorPeriod period,
    required PlannerDate today,
  });

  Future<void> saveTarget({
    required String profileId,
    required IndicatorTargetRevisionDraft draft,
    int startDay = DateTime.monday,
  });

  Future<void> saveGoal({
    required String profileId,
    required IndicatorGoalRevisionDraft draft,
    int startDay = DateTime.monday,
  });

  Future<IndicatorGoalSnapshot> readGoal({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriod period,
    required PlannerDate today,
  });

  Future<List<IndicatorGoalSnapshot>> readGoalHistory({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriodType periodType,
    required PlannerDate anchor,
    required PlannerDate today,
    int startDay = DateTime.monday,
  });

  Future<void> renameIndicator({
    required String profileId,
    required String indicatorKey,
    required String label,
  });

  Future<List<IndicatorTargetRevision>> readTargetHistory({
    required String profileId,
    required String indicatorKey,
    required PlannerDate periodStart,
  });
}
