import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

abstract interface class GoalRepository {
  Stream<void> watchChanges(String profileId);

  Future<void> ensureCanonicalGoals(String profileId);

  Future<List<Goal>> readActiveGoals(String profileId);

  Future<Goal?> readGoal({required String profileId, required String goalId});

  Future<GoalCapacity> readCapacity(String profileId);

  Future<Goal> createGoal({
    required String profileId,
    required GoalRole role,
    required String title,
    required GoalTargets targets,
    String? indicatorKey,
    String? operationId,
  });

  Future<Goal> saveGoal({
    required String profileId,
    required String goalId,
    required String title,
    required GoalTargets targets,
    String? operationId,
  });

  Future<void> archiveGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  });

  Future<Goal> restoreGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  });

  Future<List<Goal>> readArchivedGoals({
    required String profileId,
    String? query,
  });

  Future<List<GoalActivityHistoryItem>> readActivityHistory(String profileId);

  /// Exports only canonical Goal lifecycle data.  The map is JSON-compatible
  /// so the existing backup/sync layer can carry it without a second model.
  Future<Map<String, Object?>> exportGoalBackup(String profileId);

  /// Merges a previously exported canonical Goal backup transactionally.
  /// Invalid capacity or slot conflicts are rejected before any row is saved.
  Future<void> importGoalBackup({
    required String profileId,
    required Map<String, Object?> backup,
  });

  Future<Map<String, Object?>> exportBackup(String profileId);

  Future<void> importBackup({
    required String profileId,
    required Map<String, Object?> backup,
  });

  Future<GoalPlanningSnapshot> readPlanning({
    required String profileId,
    required PlannerDate periodStart,
  });

  Future<GoalProgress?> readProgress({
    required String profileId,
    required String goalId,
    required PlannerDate today,
  });
}
