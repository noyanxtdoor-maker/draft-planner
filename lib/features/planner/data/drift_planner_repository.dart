import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/data/task_goal_contribution_engine.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

abstract interface class TaskWriteGuard {
  Future<void> beforeCommit();
}

final class AllowTaskWrites implements TaskWriteGuard {
  const AllowTaskWrites();

  @override
  Future<void> beforeCommit() async {}
}

final class DriftPlannerRepository implements PlannerRepository {
  const DriftPlannerRepository({
    required this.database,
    required this.clock,
    this.calendarSource = const EmptyPlannerCalendarSource(),
    this.taskContextSource = const EmptyPlannerTaskContextSource(),
    this.historicalEffectReader = const NoTaskHistoricalEffects(),
    this.writeGuard = const AllowTaskWrites(),
  });

  final AppDatabase database;
  final AppClock clock;
  final PlannerCalendarSource calendarSource;
  final PlannerTaskContextSource taskContextSource;
  final TaskHistoricalEffectReader historicalEffectReader;
  final TaskWriteGuard writeGuard;

  @override
  Future<TaskStatusChangeOutcome> changeTaskStatus({
    required String profileId,
    required String taskId,
    required PlannerTaskStatus target,
    required String operationId,
    String? reason,
    bool confirmLinkedTypeTransfer = false,
  }) async {
    // Status changes never silently move a completed Task's contribution to a
    // different Event Type.  The explicit transfer flag is accepted here for
    // repository symmetry with saveTask; relinking is performed by saveTask
    // so a status transition remains a single, idempotent operation.
    // The flag is intentionally unused here; relinking is handled by the
    // atomic saveTask path, while status changes only change completion state.
    final hasEffects = await historicalEffectReader.hasReportOrLedgerEffect(
      taskId,
    );

    return database.transaction(() async {
      final existingOperation =
          await (database.select(database.taskStatusChanges)
                ..where((table) => table.operationId.equals(operationId))
                ..limit(1))
              .getSingleOrNull();
      if (existingOperation != null) {
        return TaskStatusChangeOutcome.unchanged;
      }

      final current = await readTask(profileId: profileId, taskId: taskId);
      if (current == null) {
        throw StateError('Task not found');
      }
      final activeContribution = await _readActiveContribution(taskId);
      final outcome = TaskStatusPolicy.evaluate(
        task: current,
        target: target,
        hasReportOrLedgerEffect: hasEffects,
        hasReversibleGoalContribution: activeContribution != null,
      );
      if (outcome != TaskStatusChangeOutcome.changed) {
        return outcome;
      }

      final changedAt = clock.nowUtc();
      final linkedType = await _resolveStoredTaskLink(
        profileId: profileId,
        task: current,
      );
      await database
          .into(database.taskStatusChanges)
          .insert(
            TaskStatusChangesCompanion.insert(
              id: operationId,
              profileId: profileId,
              taskId: taskId,
              operationId: operationId,
              fromStatus: current.status.name,
              toStatus: target.name,
              reason: Value<String?>(_normalizeOptional(reason)),
              activityTypeId: Value<String?>(linkedType?.id),
              activityTypeStableKeySnapshot: Value<String?>(
                linkedType?.stableKey,
              ),
              activityTypeLabelSnapshot: Value<String?>(linkedType?.label),
              changedAtUtc: changedAt,
            ),
          );
      await (database.update(database.plannerTasks)..where(
            (table) =>
                table.id.equals(taskId) & table.profileId.equals(profileId),
          ))
          .write(
            PlannerTasksCompanion(
              status: Value<String>(target.name),
              updatedAtUtc: Value<DateTime>(changedAt),
            ),
          );
      switch (target) {
        case PlannerTaskStatus.completed:
          await _reconcileContribution(
            profileId: profileId,
            task: current,
            linkedType: linkedType,
            changedAt: changedAt,
          );
        case PlannerTaskStatus.incomplete:
          await _reverseContribution(activeContribution, changedAt);
        case PlannerTaskStatus.skipped:
        case PlannerTaskStatus.cancelled:
          // These states do not create or remove a Goal contribution.  A
          // completed -> cancelled correction is rejected by policy unless a
          // caller first returns the task to incomplete.
          break;
      }
      await writeGuard.beforeCommit();
      return TaskStatusChangeOutcome.changed;
    });
  }

  @override
  Future<PlannerDay> readDay({
    required String profileId,
    required PlannerDate selectedDate,
    required PlannerDate today,
  }) async {
    final taskRows =
        await (database.select(database.plannerTasks)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(PlannerTasks)>[
                (table) => OrderingTerm.asc(table.dueDate),
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    final allTasks = await Future.wait(taskRows.map(_mapTask));
    final calendarItems = await calendarSource.readDay(
      profileId: profileId,
      date: selectedDate,
    );
    final nowLocal = clock.nowUtc().toLocal();
    final awaiting = calendarItems
        .where((item) => item.isAwaitingReport(nowLocal))
        .toList(growable: false);

    final tasks = allTasks
        .where((task) {
          if (task.status != PlannerTaskStatus.incomplete) {
            return false;
          }
          final dueDate = task.dueDate;
          return dueDate == selectedDate ||
              (dueDate == null && selectedDate == today);
        })
        .toList(growable: false);
    final overdueTasks = allTasks
        .where((task) => task.isOverdueOn(selectedDate))
        .toList(growable: false);
    final completedTasks = allTasks
        .where(
          (task) =>
              task.status == PlannerTaskStatus.completed &&
              (task.dueDate == selectedDate ||
                  (task.dueDate == null && selectedDate == today)),
        )
        .toList(growable: false);

    final changes = <PlannerChangeItem>[
      for (final task in allTasks)
        if (task.isHistorical &&
            (task.dueDate == selectedDate ||
                (task.dueDate == null && selectedDate == today)))
          PlannerChangeItem(
            id: task.id,
            title: task.title,
            label: _taskStatusLabel(task.status),
            isTask: true,
          ),
      for (final event in calendarItems)
        if (event.isChange)
          PlannerChangeItem(
            id: event.id,
            title: event.title,
            label: event.state == PlannerEventState.cancelled
                ? 'Cancelled event'
                : 'Rescheduled event',
            isTask: false,
            eventId: event.eventId,
            originalDate: event.originalDate,
          ),
    ];

    return PlannerDay(
      selectedDate: selectedDate,
      allDayEvents: calendarItems
          .where(_isVisibleTimelineState)
          .where((item) => item.timing == PlannerEventTiming.allDay)
          .toList(growable: false),
      timedEvents: calendarItems
          .where(_isVisibleTimelineState)
          .where((item) => item.timing == PlannerEventTiming.timed)
          .toList(growable: false),
      tasks: tasks,
      overdueTasks: overdueTasks,
      completedTasks: completedTasks,
      awaitingReportEvents: awaiting,
      changes: changes,
    );
  }

  @override
  Future<PlannerTask?> readTask({
    required String profileId,
    required String taskId,
  }) async {
    final row =
        await (database.select(database.plannerTasks)
              ..where(
                (table) =>
                    table.id.equals(taskId) & table.profileId.equals(profileId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : await _mapTask(row);
  }

  @override
  Future<PlannerTask> saveTask({
    required String profileId,
    required PlannerTaskDraft draft,
    bool confirmLinkedTypeTransfer = false,
  }) async {
    final normalized = draft.normalized();
    await database.transaction(() async {
      final existing =
          await (database.select(database.plannerTasks)
                ..where(
                  (table) =>
                      table.id.equals(normalized.id) &
                      table.profileId.equals(profileId),
                )
                ..limit(1))
              .getSingleOrNull();
      final now = clock.nowUtc();
      final linkedType = await _resolveTaskLink(
        profileId: profileId,
        draft: normalized,
      );
      final oldStableKey = _normalizeOptional(
        existing?.linkedActivityTypeStableKey,
      );
      final newStableKey = linkedType?.stableKey;
      final linkChanged = oldStableKey != newStableKey;
      if (existing != null &&
          existing.status == PlannerTaskStatus.completed.name &&
          linkChanged &&
          !confirmLinkedTypeTransfer) {
        throw const PlannerTaskValidationException(
          'This completed Task already contributed progress. Confirm the Event Type change to move that contribution.',
        );
      }
      final oldContribution = existing == null
          ? null
          : await _readActiveContribution(existing.id);
      if (existing != null &&
          existing.status == PlannerTaskStatus.completed.name &&
          linkChanged) {
        await _reverseContribution(oldContribution, now);
      }
      if (existing == null) {
        await database
            .into(database.plannerTasks)
            .insert(
              PlannerTasksCompanion.insert(
                id: normalized.id,
                profileId: profileId,
                title: normalized.title,
                notes: Value<String?>(normalized.notes),
                dueDate: Value<String?>(normalized.dueDate?.iso8601),
                dueMinute: Value<int?>(normalized.dueMinute),
                recurrenceFrequency: Value<String>(normalized.recurrence.name),
                peopleJson: Value<String>(jsonEncode(normalized.people)),
                requiresReport: Value<bool>(normalized.requiresReport),
                contributionRuleKey: Value<String?>(
                  normalized.contributionRuleKey,
                ),
                linkedActivityTypeId: Value<String?>(linkedType?.id),
                linkedActivityTypeStableKey: Value<String?>(
                  linkedType?.stableKey,
                ),
                linkedActivityTypeLabelSnapshot: Value<String?>(
                  linkedType?.label,
                ),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      } else {
        await (database.update(database.plannerTasks)..where(
              (table) =>
                  table.id.equals(normalized.id) &
                  table.profileId.equals(profileId),
            ))
            .write(
              PlannerTasksCompanion(
                title: Value<String>(normalized.title),
                notes: Value<String?>(normalized.notes),
                dueDate: Value<String?>(normalized.dueDate?.iso8601),
                dueMinute: Value<int?>(normalized.dueMinute),
                recurrenceFrequency: Value<String>(normalized.recurrence.name),
                peopleJson: Value<String>(jsonEncode(normalized.people)),
                requiresReport: Value<bool>(normalized.requiresReport),
                contributionRuleKey: Value<String?>(
                  normalized.contributionRuleKey,
                ),
                linkedActivityTypeId: Value<String?>(linkedType?.id),
                linkedActivityTypeStableKey: Value<String?>(
                  linkedType?.stableKey,
                ),
                linkedActivityTypeLabelSnapshot: Value<String?>(
                  linkedType?.label,
                ),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
      }
      if (existing != null &&
          existing.status == PlannerTaskStatus.completed.name) {
        final savedTask = PlannerTask(
          id: normalized.id,
          profileId: profileId,
          title: normalized.title,
          notes: normalized.notes,
          dueDate: normalized.dueDate,
          dueMinute: normalized.dueMinute,
          recurrence: normalized.recurrence,
          people: normalized.people,
          status: PlannerTaskStatus.completed,
          requiresReport: normalized.requiresReport,
          contributionRuleKey: normalized.contributionRuleKey,
          createdAtUtc: existing.createdAtUtc,
          updatedAtUtc: now,
          linkedActivityTypeId: linkedType?.id,
          linkedActivityTypeStableKey: linkedType?.stableKey,
          linkedActivityTypeLabelSnapshot: linkedType?.label,
        );
        await _reconcileContribution(
          profileId: profileId,
          task: savedTask,
          linkedType: linkedType,
          changedAt: now,
        );
      }
      await writeGuard.beforeCommit();
    });

    final saved = await readTask(profileId: profileId, taskId: normalized.id);
    if (saved == null) {
      throw StateError('Task save did not produce a readable record');
    }
    return saved;
  }

  Future<PlannerTask> _mapTask(PlannerTaskRow row) async {
    final context = await taskContextSource.readContext(row.id);
    return PlannerTask(
      id: row.id,
      profileId: row.profileId,
      title: row.title,
      notes: row.notes,
      dueDate: row.dueDate == null ? null : PlannerDate.parse(row.dueDate!),
      dueMinute: row.dueMinute,
      recurrence: PlannerTaskRecurrence.values.byName(row.recurrenceFrequency),
      people: _decodePeople(row.peopleJson),
      status: PlannerTaskStatus.values.byName(row.status),
      requiresReport: row.requiresReport,
      contributionRuleKey: row.contributionRuleKey,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
      linkedEventIds: context.linkedEventIds,
      pathwayContextLabels: context.pathwayContextLabels,
      linkedActivityTypeId: row.linkedActivityTypeId,
      linkedActivityTypeStableKey: row.linkedActivityTypeStableKey,
      linkedActivityTypeLabelSnapshot: row.linkedActivityTypeLabelSnapshot,
    );
  }

  Future<TaskGoalContributionLink?> _resolveTaskLink({
    required String profileId,
    required PlannerTaskDraft draft,
  }) async {
    return _contributionEngine.resolve(
      profileId: profileId,
      activityTypeId: draft.linkedActivityTypeId,
      stableKey: draft.linkedActivityTypeStableKey,
      labelSnapshot: draft.linkedActivityTypeLabelSnapshot,
    );
  }

  Future<TaskGoalContributionLink?> _resolveStoredTaskLink({
    required String profileId,
    required PlannerTask task,
  }) {
    return _contributionEngine.resolve(
      profileId: profileId,
      activityTypeId: task.linkedActivityTypeId,
      stableKey: task.linkedActivityTypeStableKey,
      labelSnapshot: task.linkedActivityTypeLabelSnapshot,
      allowArchived: true,
    );
  }

  Future<TaskGoalContributionRow?> _readActiveContribution(String taskId) {
    return _contributionEngine.readActive(taskId);
  }

  Future<void> _reverseContribution(
    TaskGoalContributionRow? contribution,
    DateTime changedAt,
  ) async {
    await _contributionEngine.reverse(contribution, changedAt);
  }

  Future<void> _reconcileContribution({
    required String profileId,
    required PlannerTask task,
    required TaskGoalContributionLink? linkedType,
    required DateTime changedAt,
  }) async {
    await _contributionEngine.reconcile(
      profileId: profileId,
      taskId: task.id,
      dueDate: task.dueDate,
      linkedType: linkedType,
      changedAt: changedAt,
    );
  }

  TaskGoalContributionEngine get _contributionEngine =>
      TaskGoalContributionEngine(database: database);

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static List<String> _decodePeople(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<Object?>) {
        return List<String>.unmodifiable(
          decoded
              .whereType<String>()
              .map((person) => person.trim())
              .where((person) => person.isNotEmpty),
        );
      }
    } on FormatException {
      // Older or manually edited local rows remain readable without people.
    }
    return const <String>[];
  }

  static String _taskStatusLabel(PlannerTaskStatus status) {
    return switch (status) {
      PlannerTaskStatus.incomplete => 'Incomplete',
      PlannerTaskStatus.completed => 'Completed',
      PlannerTaskStatus.skipped => 'Skipped',
      PlannerTaskStatus.cancelled => 'Cancelled',
    };
  }

  /// Normal Planner Day timeline keeps every valid occurrence on the day
  /// regardless of its report outcome. A report outcome (completed,
  /// partially-completed, or did-not-attempt) is a status on the
  /// occurrence, never an existence gate (Post-VS-11 planner polish
  /// P-01A): reporting "Did Not Attempt" must never hide, delete, or
  /// reschedule a valid Event. Only explicit lifecycle actions (cancelled,
  /// rescheduled) remove a row from the timeline, and those surface through
  /// the changes list and awaiting-report surfaces.
  static bool _isVisibleTimelineState(PlannerCalendarItem item) {
    return switch (item.state) {
      PlannerEventState.scheduled ||
      PlannerEventState.completedHappened ||
      PlannerEventState.partiallyCompleted ||
      PlannerEventState.didNotHappen => true,
      PlannerEventState.cancelled || PlannerEventState.rescheduled => false,
    };
  }
}
