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

  Future<List<WeeklyPlanCommitment>> readTaskCandidates({
    required String profileId,
    required String planId,
  });

  Future<List<WeeklyPlanCommitment>> readEventCandidates({
    required String profileId,
    required String planId,
  });

  Future<WeeklyPlan> addCommitment({
    required String profileId,
    required String planId,
    required WeeklyCommitmentType type,
    required String sourceId,
    String? occurrenceId,
  });

  Future<WeeklyPlan> completeReview({
    required String profileId,
    required String planId,
    required String reviewId,
    required String operationId,
    required bool unresolvedReportsAcknowledged,
    String? privateReflection,
  });

  Future<WeeklyPlan> startNextWeek({
    required String profileId,
    required String fromPlanId,
    required String nextPlanId,
    required Map<String, TaskCarryoverDecision> taskDecisions,
  });
}
