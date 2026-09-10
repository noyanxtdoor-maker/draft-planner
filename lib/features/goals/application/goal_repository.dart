import 'package:rmplanner/features/goals/domain/assigned_event_type_draft.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/domain/goal_event_type_policy.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

abstract interface class GoalRepository {
  Stream<int> watchChanges(String profileId);

  Future<void> ensureCanonicalGoals(String profileId);

  Future<List<Goal>> readActiveGoals(String profileId);

  Future<Goal?> readGoal({required String profileId, required String goalId});

  Future<GoalCapacity> readCapacity(String profileId);

  /// The exact next available canonical slot for [role], or null when the
  /// role is full.  This is the single slot-allocation function shared by
  /// Create Goal preview, validation, and Save so a previewed assignment can
  /// never diverge from the slot that Save will occupy.
  Future<int?> nextAvailableSlot({
    required String profileId,
    required GoalRole role,
  });

  Future<Goal> createGoal({
    required String profileId,
    required GoalRole role,
    required String title,
    required GoalTargets targets,
    String? indicatorKey,
    String? iconId,
    String? operationId,
    int? expectedSlotIndex,
    AssignedEventTypeDraft? assignedEventTypeDraft,
    int startDay = DateTime.monday,
  });

  Future<Goal> saveGoal({
    required String profileId,
    required String goalId,
    required String title,
    required GoalTargets targets,
    String? iconId,
    String? operationId,
    PlannerDate? today,
    AssignedEventTypeDraft? assignedEventTypeDraft,
    int startDay = DateTime.monday,
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

  /// Permanently deletes a Goal from the user-facing active and archived
  /// experiences.  The row is tombstoned (status `deleted`) so historical
  /// Event, outcome, ledger, contribution, and activity records keep their
  /// original Goal identity.  The operation is idempotent by [operationId]
  /// and the freed slot can be reused by a replacement Goal.
  Future<void> deleteGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  });

  Future<List<Goal>> readArchivedGoals({
    required String profileId,
    String? query,
  });

  Future<List<GoalActivityHistoryItem>> readActivityHistory(
    String profileId, {
    String? goalId,
  });

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

  /// Additive read-only live slot occupancy (contract D.3): the raw-active
  /// canonical slot occupants eligible to alias their Event Type for NEW
  /// Event selections. Zero writes and zero bootstrap side effects.
  Future<Map<int, LiveGoalEventTypeBinding>> readLiveEventTypeBindings(
    String profileId,
  );

  Future<GoalPlanningSnapshot> readPlanning({
    required String profileId,
    required PlannerDate periodStart,
    PlannerDate? today,
    int startDay = DateTime.monday,
  });

  Future<GoalProgress?> readProgress({
    required String profileId,
    required String goalId,
    required PlannerDate today,
    int startDay = DateTime.monday,
  });
}
