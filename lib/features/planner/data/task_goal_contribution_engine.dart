import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// The canonical, repository-independent identity of the Goal a Task directly
/// contributes to (B3.2 owner lock D2).
///
/// The link is derived from the Task's explicit direct `goalId` only.  The
/// label is the Goal title carried alongside the Goal id; the indicator key
/// is the Goal's own key so the existing indicator-keyed progress computation
/// includes the contribution.  The Event Type stable key is retained as
/// metadata only and is never used to select a Goal.
final class TaskGoalContributionLink {
  const TaskGoalContributionLink({
    required this.id,
    required this.stableKey,
    required this.label,
    required this.indicatorKey,
  });

  final String id;
  final String? stableKey;
  final String label;
  final String indicatorKey;
}

/// Owns the single contribution lifecycle shared by direct Task status
/// changes and structured outcome-report completion.
///
/// Keeping this against the canonical Drift tables prevents the two completion
/// entry points from creating different kinds of progress records or from
/// counting the same Task twice.
final class TaskGoalContributionEngine {
  const TaskGoalContributionEngine({required this.database});

  final AppDatabase database;

  /// Resolves the Task's explicit direct Goal link (D2).
  ///
  /// Fail-closed by design: `goalId == null`, a missing Goal, a deleted Goal,
  /// or an archived Goal all resolve to `null`, which the repository treats as
  /// "no Goal contribution" — the Task data itself always remains intact and
  /// there is NEVER an Event-Type fallback.  `allowArchived` is used only when
  /// reading stored history snapshots, never for new linking.
  Future<TaskGoalContributionLink?> resolve({
    required String profileId,
    String? goalId,
    bool allowArchived = false,
  }) async {
    final requestedId = _normalizeOptional(goalId);
    if (requestedId == null) {
      return null;
    }

    final goal =
        await (database.select(database.goals)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(requestedId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (goal == null || goal.deletedAtUtc != null) {
      return null;
    }
    if (goal.status != GoalStatus.active.name && !allowArchived) {
      return null;
    }
    return TaskGoalContributionLink(
      id: goal.id,
      stableKey: goal.assignedEventTypeStableKey,
      label: goal.title,
      indicatorKey: goal.indicatorKey ?? '',
    );
  }

  Future<TaskGoalContributionRow?> readActive(String taskId) {
    return (database.select(database.taskGoalContributions)
          ..where(
            (table) =>
                table.taskId.equals(taskId) & table.state.equals('active'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> reverse(
    TaskGoalContributionRow? contribution,
    DateTime changedAt,
  ) async {
    if (contribution == null) return;
    await (database.update(
      database.taskGoalContributions,
    )..where((table) => table.id.equals(contribution.id))).write(
      TaskGoalContributionsCompanion(
        state: const Value<String>('reversed'),
        updatedAtUtc: Value<DateTime>(changedAt),
      ),
    );
  }

  Future<void> reconcile({
    required String profileId,
    required String taskId,
    required PlannerDate? dueDate,
    required TaskGoalContributionLink? linkedType,
    required DateTime changedAt,
  }) async {
    if (linkedType == null) return;
    // Fail-closed re-verification: the Goal must still exist, be active, and
    // not be deleted.  A direct Goal that became invalid mid-flight yields no
    // contribution (and never an Event-Type fallback).
    final goal =
        await (database.select(database.goals)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(linkedType.id),
              )
              ..limit(1))
            .getSingleOrNull();
    if (goal == null ||
        goal.deletedAtUtc != null ||
        goal.status != GoalStatus.active.name) {
      return;
    }

    final activityDate =
        dueDate?.iso8601 ??
        PlannerDate.fromDateTime(changedAt.toLocal()).iso8601;
    final existing =
        await (database.select(database.taskGoalContributions)
              ..where((table) => table.taskId.equals(taskId))
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      await database
          .into(database.taskGoalContributions)
          .insert(
            TaskGoalContributionsCompanion.insert(
              id: '$taskId:goal-contribution',
              profileId: profileId,
              taskId: taskId,
              // The Event-Type snapshot columns are NOT populated for direct
              // Goal contributions: the identity lives in goal_id (B3.2).
              activityTypeId: const Value<String?>(null),
              activityTypeStableKeySnapshot: const Value<String?>(null),
              activityTypeLabelSnapshot: const Value<String?>(null),
              indicatorKey: linkedType.indicatorKey,
              goalId: Value<String?>(linkedType.id),
              valueScaled: const Value<int>(1),
              valueScale: const Value<int>(0),
              unit: const Value<String>('count'),
              activityDate: activityDate,
              state: const Value<String>('active'),
              createdAtUtc: changedAt,
              updatedAtUtc: changedAt,
            ),
          );
    } else {
      await (database.update(
        database.taskGoalContributions,
      )..where((table) => table.id.equals(existing.id))).write(
        TaskGoalContributionsCompanion(
          activityTypeId: const Value<String?>(null),
          activityTypeStableKeySnapshot: const Value<String?>(null),
          activityTypeLabelSnapshot: const Value<String?>(null),
          indicatorKey: Value<String>(linkedType.indicatorKey),
          goalId: Value<String?>(linkedType.id),
          valueScaled: const Value<int>(1),
          valueScale: const Value<int>(0),
          unit: const Value<String>('count'),
          activityDate: Value<String>(activityDate),
          state: const Value<String>('active'),
          updatedAtUtc: Value<DateTime>(changedAt),
        ),
      );
    }
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
