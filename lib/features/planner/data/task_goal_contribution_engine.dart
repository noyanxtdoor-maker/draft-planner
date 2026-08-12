import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

/// The canonical, repository-independent identity used when a Task is linked
/// to one of the six fixed Goal Event Types.
///
/// The current label is deliberately carried alongside the stable key. A
/// Task and its status history therefore retain the label that was selected
/// when the link was made, while the stable key remains the identity used for
/// Goal progress.
final class TaskGoalContributionLink {
  const TaskGoalContributionLink({
    required this.id,
    required this.stableKey,
    required this.label,
    required this.indicatorKey,
  });

  final String id;
  final String stableKey;
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

  Future<TaskGoalContributionLink?> resolve({
    required String profileId,
    String? activityTypeId,
    String? stableKey,
    String? labelSnapshot,
    bool allowArchived = false,
  }) async {
    final requestedId = _normalizeOptional(activityTypeId);
    final requestedKey = _normalizeOptional(stableKey);
    if (requestedId == null && requestedKey == null) {
      return null;
    }

    final type =
        await (database.select(database.activityTypes)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    (requestedId == null
                        ? table.stableKey.equals(requestedKey!)
                        : table.id.equals(requestedId)),
              )
              ..limit(1))
            .getSingleOrNull();
    if (type == null) {
      throw const PlannerTaskValidationException(
        'The linked Event Type could not be found.',
      );
    }
    if (requestedKey != null && type.stableKey != requestedKey) {
      throw const PlannerTaskValidationException(
        'The linked Event Type identity does not match the selected type.',
      );
    }
    final slot = CanonicalGoalSlot.tryByEventTypeKey(type.stableKey);
    if (slot == null) {
      throw const PlannerTaskValidationException(
        'Tasks can link only to one of the six canonical Goal Event Types.',
      );
    }
    if (type.isArchived && !allowArchived) {
      throw const PlannerTaskValidationException(
        'The linked Event Type is archived and cannot be used.',
      );
    }
    return TaskGoalContributionLink(
      id: type.id,
      stableKey: type.stableKey,
      label: _normalizeOptional(labelSnapshot) ?? type.label,
      indicatorKey: slot.indicatorKey,
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
    final goal =
        await (database.select(database.goals)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.assignedEventTypeStableKey.equals(
                      linkedType.stableKey,
                    ) &
                    table.status.equals(GoalStatus.active.name),
              )
              ..limit(1))
            .getSingleOrNull();
    if (goal == null) return;

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
              activityTypeId: Value<String?>(linkedType.id),
              activityTypeStableKeySnapshot: Value<String?>(
                linkedType.stableKey,
              ),
              activityTypeLabelSnapshot: Value<String?>(linkedType.label),
              indicatorKey: linkedType.indicatorKey,
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
          activityTypeId: Value<String?>(linkedType.id),
          activityTypeStableKeySnapshot: Value<String?>(linkedType.stableKey),
          activityTypeLabelSnapshot: Value<String?>(linkedType.label),
          indicatorKey: Value<String>(linkedType.indicatorKey),
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
