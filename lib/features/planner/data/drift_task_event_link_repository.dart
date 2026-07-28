import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';
import 'package:uuid/uuid.dart';

abstract interface class TaskEventLinkWriteGuard {
  Future<void> beforeCommit();
}

final class AllowTaskEventLinkWrites implements TaskEventLinkWriteGuard {
  const AllowTaskEventLinkWrites();

  @override
  Future<void> beforeCommit() async {}
}

final class DriftTaskEventLinkRepository implements TaskEventLinkRepository {
  const DriftTaskEventLinkRepository({
    required this.database,
    required this.clock,
    this.writeGuard = const AllowTaskEventLinkWrites(),
  });

  final AppDatabase database;
  final AppClock clock;
  final TaskEventLinkWriteGuard writeGuard;

  @override
  Future<PlannerTaskContext> readContext(String taskId) async {
    final rows =
        await (database.select(database.taskEventLinks)..where(
              (table) =>
                  table.taskId.equals(taskId) &
                  table.status.equals(TaskEventLinkStatus.active.name),
            ))
            .get();
    return PlannerTaskContext(
      linkedEventIds: rows.map((row) => row.eventId).toSet().toList()..sort(),
    );
  }

  @override
  Future<List<String>> readLinkedTaskIds({
    required String eventId,
    required String occurrenceId,
  }) async {
    final rows =
        await (database.select(database.taskEventLinks)..where(
              (table) =>
                  table.eventId.equals(eventId) &
                  (table.status.equals(TaskEventLinkStatus.active.name) |
                      table.status.equals(TaskEventLinkStatus.removed.name)),
            ))
            .get();
    final effective = <String>{
      for (final row in rows)
        if (row.scope == TaskEventLinkScope.series.name &&
            row.status == TaskEventLinkStatus.active.name)
          row.taskId,
    };
    for (final row in rows.where(
      (row) =>
          row.scope == TaskEventLinkScope.occurrence.name &&
          row.occurrenceId == occurrenceId,
    )) {
      if (row.status == TaskEventLinkStatus.active.name) {
        effective.add(row.taskId);
      } else {
        effective.remove(row.taskId);
      }
    }
    final existing = await (database.select(
      database.plannerTasks,
    )..where((table) => table.id.isIn(effective))).get();
    return existing.map((row) => row.id).toList()..sort();
  }

  @override
  Future<List<TaskEventLinkView>> readForTask({
    required String profileId,
    required String taskId,
  }) async {
    final rows =
        await (database.select(database.taskEventLinks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.taskId.equals(taskId) &
                    table.status.isNotValue(TaskEventLinkStatus.removed.name) &
                    table.status.isNotValue(
                      TaskEventLinkStatus.historical.name,
                    ),
              )
              ..orderBy(<OrderingTerm Function(TaskEventLinks)>[
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    return Future.wait(rows.map(_view));
  }

  @override
  Future<List<TaskEventLinkView>> readForEvent({
    required String profileId,
    required String eventId,
    required String occurrenceId,
  }) async {
    final rows =
        await (database.select(database.taskEventLinks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.eventId.equals(eventId) &
                    table.status.isNotValue(
                      TaskEventLinkStatus.historical.name,
                    ) &
                    ((table.scope.equals(TaskEventLinkScope.series.name) &
                            table.status.equals(
                              TaskEventLinkStatus.active.name,
                            )) |
                        (table.scope.equals(
                              TaskEventLinkScope.occurrence.name,
                            ) &
                            table.occurrenceId.equals(occurrenceId))),
              )
              ..orderBy(<OrderingTerm Function(TaskEventLinks)>[
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    final byTask = <String, TaskEventLinkRow>{};
    for (final row in rows) {
      if (row.scope == TaskEventLinkScope.series.name) {
        byTask[row.taskId] = row;
      }
    }
    for (final row in rows.where(
      (row) => row.scope == TaskEventLinkScope.occurrence.name,
    )) {
      if (row.status == TaskEventLinkStatus.removed.name) {
        byTask.remove(row.taskId);
      } else {
        byTask[row.taskId] = row;
      }
    }
    return Future.wait(byTask.values.map(_view));
  }

  @override
  Future<List<TaskEventTaskCandidate>> readTaskCandidates({
    required String profileId,
  }) async {
    final rows =
        await (database.select(database.plannerTasks)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(PlannerTasks)>[
                (table) => OrderingTerm.asc(table.title),
              ]))
            .get();
    return rows
        .map(
          (row) => TaskEventTaskCandidate(
            id: row.id,
            title: row.title,
            statusLabel: _taskStatusLabel(
              PlannerTaskStatus.values.byName(row.status),
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TaskEventEventCandidate>> readEventCandidates({
    required String profileId,
  }) async {
    final rows =
        await (database.select(database.calendarEvents)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(CalendarEvents)>[
                (table) => OrderingTerm.asc(table.startDate),
                (table) => OrderingTerm.asc(table.title),
              ]))
            .get();
    return rows
        .map(
          (row) => TaskEventEventCandidate(
            id: row.id,
            title: row.title,
            startDate: PlannerDate.parse(row.startDate),
            isRecurring:
                row.recurrenceFrequency !=
                CalendarRecurrenceFrequency.none.name,
            statusLabel: calendarEventStatusLabel(
              CalendarEventStatus.values.byName(row.status),
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<TaskEventLinkMutationOutcome> createLink({
    required String profileId,
    required TaskEventLinkDraft draft,
    required String operationId,
  }) {
    _validateIdentifiers(draft: draft, operationId: operationId);
    return database.transaction(() async {
      if (await _operationExists(operationId)) {
        return TaskEventLinkMutationOutcome.unchanged;
      }
      await _requireTask(profileId, draft.taskId);
      await _requireEvent(profileId, draft.eventId);
      final existing = await _equivalent(profileId, draft);
      if (existing?.status == TaskEventLinkStatus.active.name) {
        return TaskEventLinkMutationOutcome.unchanged;
      }
      final now = clock.nowUtc();
      final linkId = existing?.id ?? draft.id;
      if (existing == null) {
        await database
            .into(database.taskEventLinks)
            .insert(
              TaskEventLinksCompanion.insert(
                id: linkId,
                profileId: profileId,
                taskId: draft.taskId,
                eventId: draft.eventId,
                scope: draft.scope.name,
                targetKey: draft.targetKey,
                occurrenceId: Value<String?>(draft.occurrenceId),
                originalDate: Value<String?>(draft.originalDate?.iso8601),
                canonicalSource: draft.canonicalSource.name,
                transferredFromLinkId: Value<String?>(
                  draft.transferredFromLinkId,
                ),
                createdAtUtc: now,
                updatedAtUtc: now,
              ),
            );
      } else {
        await (database.update(
          database.taskEventLinks,
        )..where((table) => table.id.equals(existing.id))).write(
          TaskEventLinksCompanion(
            status: Value<String>(TaskEventLinkStatus.active.name),
            canonicalSource: Value<String>(draft.canonicalSource.name),
            occurrenceId: Value<String?>(draft.occurrenceId),
            originalDate: Value<String?>(draft.originalDate?.iso8601),
            updatedAtUtc: Value<DateTime>(now),
          ),
        );
      }
      await _history(
        profileId: profileId,
        linkId: linkId,
        operationId: operationId,
        action: TaskEventLinkAction.created,
        fromStatus: existing?.status,
        toStatus: TaskEventLinkStatus.active,
      );
      await writeGuard.beforeCommit();
      return TaskEventLinkMutationOutcome.changed;
    });
  }

  @override
  Future<TaskEventLinkMutationOutcome> removeLink({
    required String profileId,
    required String linkId,
    required String operationId,
    String? occurrenceOverrideId,
    PlannerDate? occurrenceOverrideDate,
  }) {
    _validateUuid(operationId, 'Link operations');
    return database.transaction(() async {
      if (await _operationExists(operationId)) {
        return TaskEventLinkMutationOutcome.unchanged;
      }
      final row = await _requireLink(profileId, linkId);
      if (row.scope == TaskEventLinkScope.series.name &&
          occurrenceOverrideId != null) {
        if (occurrenceOverrideDate == null) {
          throw const TaskEventLinkValidationException(
            'An occurrence date is required for this override.',
          );
        }
        final overrideDraft = TaskEventLinkDraft(
          id: const Uuid().v5(
            Namespace.url.value,
            'com.nexttransfer.rmplanner:link-override:$linkId:'
            '$occurrenceOverrideId',
          ),
          taskId: row.taskId,
          eventId: row.eventId,
          scope: TaskEventLinkScope.occurrence,
          occurrenceId: occurrenceOverrideId,
          originalDate: occurrenceOverrideDate,
          canonicalSource: TaskEventCanonicalSource.values.byName(
            row.canonicalSource,
          ),
        );
        final existing = await _equivalent(profileId, overrideDraft);
        final now = clock.nowUtc();
        final overrideId = existing?.id ?? overrideDraft.id;
        if (existing == null) {
          await database
              .into(database.taskEventLinks)
              .insert(
                TaskEventLinksCompanion.insert(
                  id: overrideId,
                  profileId: profileId,
                  taskId: row.taskId,
                  eventId: row.eventId,
                  scope: TaskEventLinkScope.occurrence.name,
                  targetKey: overrideDraft.targetKey,
                  occurrenceId: Value<String>(occurrenceOverrideId),
                  originalDate: Value<String>(occurrenceOverrideDate.iso8601),
                  status: Value<String>(TaskEventLinkStatus.removed.name),
                  canonicalSource: row.canonicalSource,
                  createdAtUtc: now,
                  updatedAtUtc: now,
                ),
              );
        } else {
          await (database.update(
            database.taskEventLinks,
          )..where((table) => table.id.equals(existing.id))).write(
            TaskEventLinksCompanion(
              status: Value<String>(TaskEventLinkStatus.removed.name),
              updatedAtUtc: Value<DateTime>(now),
            ),
          );
        }
        await _history(
          profileId: profileId,
          linkId: overrideId,
          operationId: operationId,
          action: TaskEventLinkAction.removed,
          fromStatus: existing?.status,
          toStatus: TaskEventLinkStatus.removed,
          relatedLinkId: linkId,
        );
      } else {
        if (row.status == TaskEventLinkStatus.removed.name) {
          return TaskEventLinkMutationOutcome.unchanged;
        }
        await _setStatus(row.id, TaskEventLinkStatus.removed);
        await _history(
          profileId: profileId,
          linkId: row.id,
          operationId: operationId,
          action: TaskEventLinkAction.removed,
          fromStatus: row.status,
          toStatus: TaskEventLinkStatus.removed,
        );
      }
      await writeGuard.beforeCommit();
      return TaskEventLinkMutationOutcome.changed;
    });
  }

  @override
  Future<TaskEventLinkMutationOutcome> repairLink({
    required String profileId,
    required String linkId,
    required String taskId,
    required String eventId,
    required String operationId,
  }) {
    _validateUuid(operationId, 'Link operations');
    return database.transaction(() async {
      if (await _operationExists(operationId)) {
        return TaskEventLinkMutationOutcome.unchanged;
      }
      final row = await _requireLink(profileId, linkId);
      await _requireTask(profileId, taskId);
      await _requireEvent(profileId, eventId);
      final now = clock.nowUtc();
      final repairedOriginalDate = row.originalDate == null
          ? null
          : PlannerDate.parse(row.originalDate!);
      final repairedOccurrenceId =
          row.scope == TaskEventLinkScope.occurrence.name &&
              repairedOriginalDate != null
          ? CalendarEventOccurrenceIdentity.forDate(
              eventId: eventId,
              originalDate: repairedOriginalDate,
            )
          : row.occurrenceId;
      await (database.update(
        database.taskEventLinks,
      )..where((table) => table.id.equals(linkId))).write(
        TaskEventLinksCompanion(
          taskId: Value<String>(taskId),
          eventId: Value<String>(eventId),
          targetKey: Value<String>(
            row.scope == TaskEventLinkScope.occurrence.name
                ? 'occurrence:$repairedOccurrenceId'
                : 'series',
          ),
          occurrenceId: Value<String?>(repairedOccurrenceId),
          status: Value<String>(TaskEventLinkStatus.active.name),
          updatedAtUtc: Value<DateTime>(now),
        ),
      );
      await _history(
        profileId: profileId,
        linkId: linkId,
        operationId: operationId,
        action: TaskEventLinkAction.repaired,
        fromStatus: row.status,
        toStatus: TaskEventLinkStatus.active,
      );
      await writeGuard.beforeCommit();
      return TaskEventLinkMutationOutcome.changed;
    });
  }

  @override
  Future<void> transferOnReschedule({
    required String profileId,
    required String sourceEventId,
    required String sourceOccurrenceId,
    required PlannerDate sourceOriginalDate,
    required CalendarEventEditScope scope,
    required String replacementEventId,
    required PlannerDate replacementOriginalDate,
    required String operationId,
  }) async {
    final activeSourceRows =
        await (database.select(database.taskEventLinks)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.eventId.equals(sourceEventId) &
                  table.status.equals(TaskEventLinkStatus.active.name),
            ))
            .get();
    final taskIds = <String>{
      ...await readLinkedTaskIds(
        eventId: sourceEventId,
        occurrenceId: sourceOccurrenceId,
      ),
      if (scope == CalendarEventEditScope.series)
        for (final row in activeSourceRows)
          if (row.scope == TaskEventLinkScope.series.name) row.taskId,
    };
    final transferredByTask = <String, String>{};
    final replacementOccurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: replacementEventId,
      originalDate: replacementOriginalDate,
    );
    for (final taskId in taskIds) {
      final sourceRows =
          await (database.select(database.taskEventLinks)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.taskId.equals(taskId) &
                    table.eventId.equals(sourceEventId) &
                    table.status.equals(TaskEventLinkStatus.active.name),
              ))
              .get();
      final source = sourceRows.firstWhere(
        (row) => row.occurrenceId == sourceOccurrenceId,
        orElse: () => sourceRows.first,
      );
      final transferredScope = scope == CalendarEventEditScope.occurrence
          ? TaskEventLinkScope.occurrence
          : TaskEventLinkScope.series;
      final transferred = TaskEventLinkDraft(
        id: const Uuid().v5(
          Namespace.url.value,
          'com.nexttransfer.rmplanner:transferred-link:${source.id}:'
          '$replacementEventId:${transferredScope.name}',
        ),
        taskId: taskId,
        eventId: replacementEventId,
        scope: transferredScope,
        occurrenceId: transferredScope == TaskEventLinkScope.occurrence
            ? replacementOccurrenceId
            : null,
        originalDate: transferredScope == TaskEventLinkScope.occurrence
            ? replacementOriginalDate
            : null,
        canonicalSource: TaskEventCanonicalSource.values.byName(
          source.canonicalSource,
        ),
        transferredFromLinkId: source.id,
      );
      transferredByTask[taskId] = transferred.id;
      await createLink(
        profileId: profileId,
        draft: transferred,
        operationId: const Uuid().v5(
          Namespace.url.value,
          'com.nexttransfer.rmplanner:transfer-op:$operationId:${source.id}',
        ),
      );
    }
    for (final source in activeSourceRows) {
      final sourceDate = source.originalDate == null
          ? null
          : PlannerDate.parse(source.originalDate!);
      final becomesHistorical = switch (scope) {
        CalendarEventEditScope.occurrence =>
          source.scope == TaskEventLinkScope.occurrence.name &&
              source.occurrenceId == sourceOccurrenceId,
        CalendarEventEditScope.thisAndFuture =>
          source.scope == TaskEventLinkScope.occurrence.name &&
              sourceDate != null &&
              sourceDate.compareTo(sourceOriginalDate) >= 0,
        CalendarEventEditScope.series => true,
      };
      final targetStatus = becomesHistorical
          ? TaskEventLinkStatus.historical
          : TaskEventLinkStatus.active;
      if (becomesHistorical) {
        await _setStatus(source.id, targetStatus);
      }
      await _history(
        profileId: profileId,
        linkId: source.id,
        operationId: const Uuid().v5(
          Namespace.url.value,
          'com.nexttransfer.rmplanner:transfer-history:'
          '$operationId:${source.id}',
        ),
        action: TaskEventLinkAction.transferred,
        fromStatus: source.status,
        toStatus: targetStatus,
        relatedLinkId: transferredByTask[source.taskId],
      );
    }
  }

  Future<TaskEventLinkView> _view(TaskEventLinkRow row) async {
    final task =
        await (database.select(database.plannerTasks)
              ..where((table) => table.id.equals(row.taskId))
              ..limit(1))
            .getSingleOrNull();
    final event =
        await (database.select(database.calendarEvents)
              ..where((table) => table.id.equals(row.eventId))
              ..limit(1))
            .getSingleOrNull();
    return TaskEventLinkView(
      link: _map(
        row,
        overrideStatus: task == null || event == null
            ? TaskEventLinkStatus.brokenReference
            : null,
      ),
      taskTitle: task?.title ?? 'Missing Task',
      eventTitle: event?.title ?? 'Missing Calendar Event',
      taskExists: task != null,
      eventExists: event != null,
      eventStartDate: event == null ? null : PlannerDate.parse(event.startDate),
    );
  }

  TaskEventLink _map(
    TaskEventLinkRow row, {
    TaskEventLinkStatus? overrideStatus,
  }) {
    return TaskEventLink(
      id: row.id,
      profileId: row.profileId,
      taskId: row.taskId,
      eventId: row.eventId,
      scope: TaskEventLinkScope.values.byName(row.scope),
      occurrenceId: row.occurrenceId,
      originalDate: row.originalDate == null
          ? null
          : PlannerDate.parse(row.originalDate!),
      status: overrideStatus ?? TaskEventLinkStatus.values.byName(row.status),
      canonicalSource: TaskEventCanonicalSource.values.byName(
        row.canonicalSource,
      ),
      transferredFromLinkId: row.transferredFromLinkId,
      createdAtUtc: row.createdAtUtc,
      updatedAtUtc: row.updatedAtUtc,
    );
  }

  Future<TaskEventLinkRow?> _equivalent(
    String profileId,
    TaskEventLinkDraft draft,
  ) {
    return (database.select(database.taskEventLinks)
          ..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.taskId.equals(draft.taskId) &
                table.eventId.equals(draft.eventId) &
                table.targetKey.equals(draft.targetKey),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<TaskEventLinkRow> _requireLink(String profileId, String linkId) async {
    final row =
        await (database.select(database.taskEventLinks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.equals(linkId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      throw const TaskEventLinkValidationException('Link not found.');
    }
    return row;
  }

  Future<void> _requireTask(String profileId, String taskId) async {
    final row =
        await (database.select(database.plannerTasks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.equals(taskId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      throw const TaskEventLinkValidationException('Task not found.');
    }
  }

  Future<void> _requireEvent(String profileId, String eventId) async {
    final row =
        await (database.select(database.calendarEvents)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(eventId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) {
      throw const TaskEventLinkValidationException('Calendar Event not found.');
    }
  }

  Future<bool> _operationExists(String operationId) async {
    return (await (database.select(database.taskEventLinkHistory)
              ..where((table) => table.operationId.equals(operationId))
              ..limit(1))
            .getSingleOrNull()) !=
        null;
  }

  Future<void> _setStatus(String id, TaskEventLinkStatus status) {
    return (database.update(
      database.taskEventLinks,
    )..where((table) => table.id.equals(id))).write(
      TaskEventLinksCompanion(
        status: Value<String>(status.name),
        updatedAtUtc: Value<DateTime>(clock.nowUtc()),
      ),
    );
  }

  Future<void> _history({
    required String profileId,
    required String linkId,
    required String operationId,
    required TaskEventLinkAction action,
    required String? fromStatus,
    required TaskEventLinkStatus toStatus,
    String? relatedLinkId,
  }) {
    return database
        .into(database.taskEventLinkHistory)
        .insert(
          TaskEventLinkHistoryCompanion.insert(
            id: const Uuid().v5(
              Namespace.url.value,
              'com.nexttransfer.rmplanner:link-history:$operationId:$linkId',
            ),
            profileId: profileId,
            linkId: linkId,
            operationId: operationId,
            action: action.name,
            fromStatus: Value<String?>(fromStatus),
            toStatus: toStatus.name,
            relatedLinkId: Value<String?>(relatedLinkId),
            createdAtUtc: clock.nowUtc(),
          ),
        );
  }

  void _validateIdentifiers({
    required TaskEventLinkDraft draft,
    required String operationId,
  }) {
    _validateUuid(draft.id, 'Links');
    _validateUuid(operationId, 'Link operations');
    if (draft.scope == TaskEventLinkScope.occurrence &&
        (draft.occurrenceId == null || draft.originalDate == null)) {
      throw const TaskEventLinkValidationException(
        'Occurrence links require an occurrence identity and original date.',
      );
    }
    if (draft.scope == TaskEventLinkScope.series &&
        (draft.occurrenceId != null || draft.originalDate != null)) {
      throw const TaskEventLinkValidationException(
        'Series links cannot contain an occurrence override.',
      );
    }
  }

  void _validateUuid(String value, String subject) {
    if (!Uuid.isValidUUID(fromString: value)) {
      throw TaskEventLinkValidationException(
        '$subject require stable UUID identifiers.',
      );
    }
  }

  static String _taskStatusLabel(PlannerTaskStatus status) {
    return switch (status) {
      PlannerTaskStatus.incomplete => 'Incomplete',
      PlannerTaskStatus.completed => 'Completed',
      PlannerTaskStatus.skipped => 'Skipped',
      PlannerTaskStatus.cancelled => 'Cancelled',
    };
  }
}

final class DriftTaskEventLinkCoordinator implements TaskEventLinkCoordinator {
  const DriftTaskEventLinkCoordinator({
    required this.database,
    required this.calendarEvents,
    required this.links,
  });

  final AppDatabase database;
  final CalendarEventRepository calendarEvents;
  final TaskEventLinkRepository links;

  @override
  Future<TaskEventLinkMutationOutcome> createEventFromTask({
    required String profileId,
    required String taskId,
    required CalendarEventDraft event,
    required String linkId,
    required String operationId,
    required TaskEventCanonicalSource canonicalSource,
  }) {
    return database.transaction(() async {
      await calendarEvents.saveEvent(profileId: profileId, draft: event);
      return links.createLink(
        profileId: profileId,
        draft: TaskEventLinkDraft(
          id: linkId,
          taskId: taskId,
          eventId: event.id,
          scope: TaskEventLinkScope.series,
          canonicalSource: canonicalSource,
        ),
        operationId: operationId,
      );
    });
  }
}
