import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
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
  }) async {
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
      final outcome = TaskStatusPolicy.evaluate(
        task: current,
        target: target,
        hasReportOrLedgerEffect: hasEffects,
      );
      if (outcome != TaskStatusChangeOutcome.changed) {
        return outcome;
      }

      final changedAt = clock.nowUtc();
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
                requiresReport: Value<bool>(normalized.requiresReport),
                contributionRuleKey: Value<String?>(
                  normalized.contributionRuleKey,
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
                requiresReport: Value<bool>(normalized.requiresReport),
                contributionRuleKey: Value<String?>(
                  normalized.contributionRuleKey,
                ),
                updatedAtUtc: Value<DateTime>(now),
              ),
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
      status: PlannerTaskStatus.values.byName(row.status),
      requiresReport: row.requiresReport,
      contributionRuleKey: row.contributionRuleKey,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
      linkedEventIds: context.linkedEventIds,
      pathwayContextLabels: context.pathwayContextLabels,
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String _taskStatusLabel(PlannerTaskStatus status) {
    return switch (status) {
      PlannerTaskStatus.incomplete => 'Incomplete',
      PlannerTaskStatus.completed => 'Completed',
      PlannerTaskStatus.skipped => 'Skipped',
      PlannerTaskStatus.cancelled => 'Cancelled',
    };
  }

  /// Normal Planner Day timeline keeps events that are still meaningful
  /// at their scheduled date: scheduled, completed-happened, and
  /// partially-completed occurrences. Cancelled, rescheduled, and
  /// did-not-happen occurrences are surfaced only through the changes
  /// list and awaiting-report surfaces.
  static bool _isVisibleTimelineState(PlannerCalendarItem item) {
    return switch (item.state) {
      PlannerEventState.scheduled ||
      PlannerEventState.completedHappened ||
      PlannerEventState.partiallyCompleted => true,
      PlannerEventState.cancelled ||
      PlannerEventState.rescheduled ||
      PlannerEventState.didNotHappen => false,
    };
  }
}
