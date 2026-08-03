import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/goals/application/goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// Deterministic migration/bootstrap for the six approved WLI-backed Goals.
/// It is deliberately independent of display labels: slot and indicator key
/// are the identity used to recover from an interrupted first launch.
final class GoalBootstrap {
  const GoalBootstrap._();

  static String stableId(String profileId, int slotIndex) {
    return '$profileId:goal:$slotIndex';
  }

  static GoalRole roleForPosition(int position) => switch (position) {
    0 => GoalRole.dailyWeekly,
    5 => GoalRole.weeklyMonthly,
    _ => GoalRole.weekly,
  };

  static Future<void> ensure(
    AppDatabase database,
    String profileId, {
    DateTime? nowUtc,
  }) async {
    final definitions =
        await (database.select(database.lifeIndicatorDefinitions)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(LifeIndicatorDefinitions)>[
                (table) => OrderingTerm.asc(table.position),
              ]))
            .get();
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    for (final definition in definitions) {
      final goalId = stableId(profileId, definition.position + 1);
      final existingById =
          await (database.select(database.goals)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.id.equals(goalId),
                )
                ..limit(1))
              .getSingleOrNull();
      final existing =
          existingById ??
          await (database.select(database.goals)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.indicatorKey.equals(definition.indicatorKey),
                )
                ..limit(1))
              .getSingleOrNull();
      final role = roleForPosition(definition.position);
      final migratedDefaultSlot4 =
          definition.position == 3 &&
          definition.label == 'Meaningful Connections';
      final migratedTitle = migratedDefaultSlot4
          ? 'Ministering Visit'
          : definition.label;
      var goal = existing;
      if (goal == null) {
        await database
            .into(database.goals)
            .insert(
              GoalsCompanion.insert(
                id: goalId,
                profileId: profileId,
                indicatorKey: Value<String?>(definition.indicatorKey),
                role: role.storageName,
                activeSlotIndex: Value<int?>(definition.position + 1),
                title: migratedTitle,
                iconId: const Value<String?>(null),
                status: GoalStatus.active.name,
                createdAtUtc: now,
                updatedAtUtc: now,
                archivedAtUtc: const Value<DateTime?>(null),
              ),
              mode: InsertMode.insertOrIgnore,
            );
        goal =
            await (database.select(database.goals)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.indicatorKey.equals(definition.indicatorKey),
                  )
                  ..limit(1))
                .getSingleOrNull();
      } else if (migratedDefaultSlot4 &&
          goal.title == 'Meaningful Connections') {
        await (database.update(database.goals)..where(
              (table) =>
                  table.profileId.equals(profileId) & table.id.equals(goal!.id),
            ))
            .write(
              GoalsCompanion(
                title: Value<String>(migratedTitle),
                updatedAtUtc: Value<DateTime>(now),
              ),
            );
        final currentGoalId = goal.id;
        goal =
            await (database.select(database.goals)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.id.equals(currentGoalId),
                  )
                  ..limit(1))
                .getSingleOrNull();
      }
      if (goal == null) {
        continue;
      }
      final title = goal.title;
      final operationId = '$goalId:created';
      final activity =
          await (database.select(database.goalActivities)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.operationId.equals(operationId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (activity == null) {
        await database
            .into(database.goalActivities)
            .insert(
              GoalActivitiesCompanion.insert(
                id: operationId,
                profileId: profileId,
                goalId: goal.id,
                operationId: operationId,
                action: GoalActivityAction.created.name,
                previousValue: const Value<String?>(null),
                newValue: Value<String?>(title),
                occurredAtUtc: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      final outbox =
          await (database.select(database.goalOutboxOperations)
                ..where((table) => table.operationId.equals(operationId))
                ..limit(1))
              .getSingleOrNull();
      if (outbox == null) {
        await database
            .into(database.goalOutboxOperations)
            .insert(
              GoalOutboxOperationsCompanion.insert(
                operationId: operationId,
                profileId: profileId,
                entityType: 'goal',
                entityId: goal.id,
                action: GoalActivityAction.created.name,
                payloadJson: jsonEncode(<String, Object?>{
                  'goalId': goal.id,
                  'role': role.storageName,
                  'slot': definition.position + 1,
                  'title': title,
                  'iconId': goal.iconId,
                }),
                createdAtUtc: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      if (definition.position == 3 && definition.label != goal.title) {
        await (database.update(database.lifeIndicatorDefinitions)..where(
              (table) =>
                  table.id.equals(definition.id) &
                  table.label.equals(definition.label),
            ))
            .write(
              LifeIndicatorDefinitionsCompanion(
                label: Value<String>(goal.title),
              ),
            );
      }
    }
  }
}

final class DriftGoalRepository implements GoalRepository {
  const DriftGoalRepository({
    required this.database,
    required this.clock,
    required this.identifiers,
  });

  final AppDatabase database;
  final AppClock clock;
  final IdentifierSource identifiers;

  @override
  Stream<void> watchChanges(String profileId) {
    return database
        .tableUpdates(
          TableUpdateQuery.onAllTables(<ResultSetImplementation>[
            database.goals,
            database.goalActivities,
            database.goalOutboxOperations,
            database.indicatorGoalRevisions,
            database.weeklyIndicatorTargetRevisions,
            database.activityLedgerEntries,
            database.lifeIndicatorDefinitions,
          ]),
        )
        .map((_) {});
  }

  @override
  Future<void> ensureCanonicalGoals(String profileId) async {
    await GoalBootstrap.ensure(database, profileId, nowUtc: clock.nowUtc());
    final mappings = await _goalMappings(profileId);
    for (final goal in mappings.values) {
      final indicatorNulls =
          await (database.select(database.indicatorGoalRevisions)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.indicatorKey.equals(goal.indicatorKey ?? '') &
                    table.goalId.isNull(),
              ))
              .get();
      if (indicatorNulls.isNotEmpty) {
        await database.customUpdate(
          'UPDATE indicator_goal_revisions SET goal_id = ? '
          'WHERE profile_id = ? AND indicator_key = ? AND goal_id IS NULL',
          variables: <Variable<Object>>[
            Variable<String>(goal.id),
            Variable<String>(profileId),
            Variable<String>(goal.indicatorKey ?? ''),
          ],
          updates: <ResultSetImplementation>{database.indicatorGoalRevisions},
        );
      }
      final weeklyNulls =
          await (database.select(database.weeklyIndicatorTargetRevisions)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.indicatorKey.equals(goal.indicatorKey ?? '') &
                      table.goalId.isNull(),
                ))
              .get();
      if (weeklyNulls.isNotEmpty) {
        await database.customUpdate(
          'UPDATE weekly_indicator_target_revisions SET goal_id = ? '
          'WHERE profile_id = ? AND indicator_key = ? AND goal_id IS NULL',
          variables: <Variable<Object>>[
            Variable<String>(goal.id),
            Variable<String>(profileId),
            Variable<String>(goal.indicatorKey ?? ''),
          ],
          updates: <ResultSetImplementation>{
            database.weeklyIndicatorTargetRevisions,
          },
        );
      }
    }
  }

  @override
  Future<List<Goal>> readActiveGoals(String profileId) async {
    await ensureCanonicalGoals(profileId);
    final rows =
        await (database.select(database.goals)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.status.equals(GoalStatus.active.name),
              )
              ..orderBy(<OrderingTerm Function(Goals)>[
                (table) => OrderingTerm.asc(table.activeSlotIndex),
              ]))
            .get();
    return rows.map(_mapGoal).toList(growable: false);
  }

  @override
  Future<Goal?> readGoal({
    required String profileId,
    required String goalId,
  }) async {
    final row =
        await (database.select(database.goals)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) & table.id.equals(goalId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _mapGoal(row);
  }

  @override
  Future<GoalCapacity> readCapacity(String profileId) async {
    await ensureCanonicalGoals(profileId);
    final rows =
        await (database.select(database.goals)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.status.equals(GoalStatus.active.name),
            ))
            .get();
    final counts = <GoalRole, int>{for (final role in GoalRole.values) role: 0};
    for (final row in rows) {
      final role = _roleFromName(row.role);
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return GoalCapacity(activeByRole: counts);
  }

  @override
  Future<Goal> createGoal({
    required String profileId,
    required GoalRole role,
    required String title,
    required GoalTargets targets,
    String? indicatorKey,
    String? operationId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const GoalValidationException('Goal name is required.');
    }
    await ensureCanonicalGoals(profileId);
    final effectiveOperationId = operationId ?? identifiers.nextUuid();
    return database.transaction(() async {
      final prior = await _goalForOperation(profileId, effectiveOperationId);
      if (prior != null) {
        return prior;
      }
      final goalId = identifiers.nextUuid();
      final slot = await _freeSlot(profileId, role);
      final now = clock.nowUtc();
      final goal = Goal(
        id: goalId,
        profileId: profileId,
        indicatorKey: indicatorKey,
        role: role,
        activeSlotIndex: slot,
        title: normalizedTitle,
        iconId: null,
        status: GoalStatus.active,
        createdAtUtc: now,
        updatedAtUtc: now,
        archivedAtUtc: null,
      );
      await database.into(database.goals).insert(_goalCompanion(goal));
      await _writeTargets(
        goal: goal,
        targets: targets,
        operationId: effectiveOperationId,
      );
      await _writeActivity(
        goal: goal,
        action: GoalActivityAction.created,
        operationId: effectiveOperationId,
        newValue: normalizedTitle,
      );
      await _writeOutbox(
        profileId: profileId,
        goalId: goalId,
        operationId: effectiveOperationId,
        action: GoalActivityAction.created.name,
        payload: <String, Object?>{
          'goalId': goalId,
          'role': role.storageName,
          'slot': slot,
          'title': normalizedTitle,
          'iconId': null,
          'targets': _targetsPayload(targets),
        },
      );
      return goal;
    });
  }

  @override
  Future<Goal> saveGoal({
    required String profileId,
    required String goalId,
    required String title,
    required GoalTargets targets,
    String? operationId,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const GoalValidationException('Goal name is required.');
    }
    await ensureCanonicalGoals(profileId);
    final effectiveOperationId = operationId ?? identifiers.nextUuid();
    return database.transaction(() async {
      final prior = await _goalForOperation(profileId, effectiveOperationId);
      if (prior != null) {
        return prior;
      }
      final row = await _goalRow(profileId, goalId);
      if (row == null || row.status != GoalStatus.active.name) {
        throw const GoalValidationException('Active Goal was not found.');
      }
      final before = _mapGoal(row);
      final now = clock.nowUtc();
      final titleChanged = before.title != normalizedTitle;
      await (database.update(database.goals)..where(
            (table) =>
                table.profileId.equals(profileId) & table.id.equals(goalId),
          ))
          .write(
            GoalsCompanion(
              title: Value<String>(normalizedTitle),
              updatedAtUtc: Value<DateTime>(now),
            ),
          );
      if (titleChanged && before.indicatorKey != null) {
        await (database.update(database.lifeIndicatorDefinitions)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.indicatorKey.equals(before.indicatorKey!),
            ))
            .write(
              LifeIndicatorDefinitionsCompanion(label: Value(normalizedTitle)),
            );
      }
      await _writeTargets(
        goal: before,
        targets: targets,
        operationId: effectiveOperationId,
      );
      if (titleChanged) {
        await _writeActivity(
          goal: before,
          action: GoalActivityAction.renamed,
          operationId: effectiveOperationId,
          previousValue: before.title,
          newValue: normalizedTitle,
        );
      }
      await _writeOutbox(
        profileId: profileId,
        goalId: goalId,
        operationId: effectiveOperationId,
        action: titleChanged ? GoalActivityAction.renamed.name : 'updated',
        payload: <String, Object?>{
          'goalId': goalId,
          'title': normalizedTitle,
          'targets': _targetsPayload(targets),
        },
      );
      return _mapGoal((await _goalRow(profileId, goalId))!);
    });
  }

  @override
  Future<void> archiveGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  }) async {
    await ensureCanonicalGoals(profileId);
    await _mutateLifecycle(
      profileId: profileId,
      goalId: goalId,
      action: GoalActivityAction.archived,
      operationId: operationId,
    );
  }

  @override
  Future<Goal> restoreGoal({
    required String profileId,
    required String goalId,
    String? operationId,
  }) async {
    await ensureCanonicalGoals(profileId);
    final effectiveOperationId = operationId ?? identifiers.nextUuid();
    return database.transaction(() async {
      final prior = await _goalForOperation(profileId, effectiveOperationId);
      if (prior != null) {
        return prior;
      }
      final row = await _goalRow(profileId, goalId);
      if (row == null || row.status != GoalStatus.archived.name) {
        throw const GoalValidationException('Archived Goal was not found.');
      }
      final goal = _mapGoal(row);
      final slot = await _freeSlot(profileId, goal.role);
      final now = clock.nowUtc();
      await (database.update(database.goals)..where(
            (table) =>
                table.profileId.equals(profileId) & table.id.equals(goalId),
          ))
          .write(
            GoalsCompanion(
              status: Value<String>(GoalStatus.active.name),
              activeSlotIndex: Value<int?>(slot),
              archivedAtUtc: const Value<DateTime?>(null),
              updatedAtUtc: Value<DateTime>(now),
            ),
          );
      final restored = _mapGoal((await _goalRow(profileId, goalId))!);
      await _ensureCurrentTargetsAfterRestore(
        goal: restored,
        operationId: effectiveOperationId,
      );
      await _writeActivity(
        goal: restored,
        action: GoalActivityAction.restored,
        operationId: effectiveOperationId,
        newValue: slot.toString(),
      );
      await _writeOutbox(
        profileId: profileId,
        goalId: goalId,
        operationId: effectiveOperationId,
        action: GoalActivityAction.restored.name,
        payload: <String, Object?>{'goalId': goalId, 'slot': slot},
      );
      return restored;
    });
  }

  @override
  Future<List<Goal>> readArchivedGoals({
    required String profileId,
    String? query,
  }) async {
    final rows =
        await (database.select(database.goals)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.status.equals(GoalStatus.archived.name),
              )
              ..orderBy(<OrderingTerm Function(Goals)>[
                (table) => OrderingTerm.desc(table.archivedAtUtc),
              ]))
            .get();
    final activities = await (database.select(
      database.goalActivities,
    )..where((table) => table.profileId.equals(profileId))).get();
    final aliases = <String, Set<String>>{};
    for (final activity in activities) {
      final values = aliases.putIfAbsent(activity.goalId, () => <String>{});
      for (final value in <String?>[
        activity.previousValue,
        activity.newValue,
      ]) {
        if (value != null && value.trim().isNotEmpty) {
          values.add(value.trim().toLowerCase());
        }
      }
    }
    final normalized = query?.trim().toLowerCase();
    return rows
        .where(
          (row) =>
              normalized == null ||
              normalized.isEmpty ||
              row.title.toLowerCase().contains(normalized) ||
              (aliases[row.id] ?? const <String>{}).any(
                (alias) => alias.contains(normalized),
              ),
        )
        .map(_mapGoal)
        .toList(growable: false);
  }

  @override
  Future<List<GoalActivityHistoryItem>> readActivityHistory(
    String profileId,
  ) async {
    final rows =
        await (database.select(database.goalActivities)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(GoalActivities)>[
                (table) => OrderingTerm.desc(table.occurredAtUtc),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    final goals = await (database.select(
      database.goals,
    )..where((table) => table.profileId.equals(profileId))).get();
    final byId = <String, Goal>{for (final row in goals) row.id: _mapGoal(row)};
    return rows
        .map(
          (row) => GoalActivityHistoryItem(
            activity: _mapActivity(row),
            goalTitle: byId[row.goalId]?.title ?? 'Archived Goal',
            role: byId[row.goalId]?.role ?? GoalRole.weekly,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Map<String, Object?>> exportGoalBackup(String profileId) async {
    await ensureCanonicalGoals(profileId);
    final goals = await (database.select(
      database.goals,
    )..where((table) => table.profileId.equals(profileId))).get();
    final activities =
        await (database.select(database.goalActivities)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(GoalActivities)>[
                (table) => OrderingTerm.asc(table.occurredAtUtc),
              ]))
            .get();
    final outbox =
        await (database.select(database.goalOutboxOperations)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(GoalOutboxOperations)>[
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    final mappings = await _goalMappings(profileId);
    final targetRows = <String, Map<String, Object?>>{};
    final canonicalTargets = await (database.select(
      database.indicatorGoalRevisions,
    )..where((table) => table.profileId.equals(profileId))).get();
    for (final row in canonicalTargets) {
      final goalId = row.goalId ?? mappings[row.indicatorKey]?.id;
      if (goalId == null) {
        continue;
      }
      targetRows[row.id] = _exportGoalTarget(
        id: row.id,
        goalId: goalId,
        indicatorKey: row.indicatorKey,
        periodType: row.periodType,
        periodStartDate: row.periodStartDate,
        periodEndDate: row.periodEndDate,
        state: row.state,
        valueScaled: row.valueScaled,
        valueScale: row.valueScale,
        unit: row.unit,
        supersedesRevisionId: row.supersedesRevisionId,
        operationId: row.operationId,
        createdAtUtc: row.createdAtUtc,
      );
    }
    final legacyTargets = await (database.select(
      database.weeklyIndicatorTargetRevisions,
    )..where((table) => table.profileId.equals(profileId))).get();
    for (final row in legacyTargets) {
      final goalId = row.goalId ?? mappings[row.indicatorKey]?.id;
      if (goalId == null) {
        continue;
      }
      targetRows.putIfAbsent(
        row.id,
        () => _exportGoalTarget(
          id: row.id,
          goalId: goalId,
          indicatorKey: row.indicatorKey,
          periodType: IndicatorGoalPeriodType.weekly.name,
          periodStartDate: row.periodStartDate,
          periodEndDate: _periodEndDate(
            IndicatorGoalPeriodType.weekly,
            row.periodStartDate,
          ),
          state: row.state,
          valueScaled: row.valueScaled,
          valueScale: row.valueScale,
          unit: row.unit,
          supersedesRevisionId: row.supersedesRevisionId,
          operationId: row.operationId,
          createdAtUtc: row.createdAtUtc,
        ),
      );
    }
    return <String, Object?>{
      'format': 'rmplanner.goals.v1',
      'schemaVersion': 1,
      'profileId': profileId,
      'goals': <Map<String, Object?>>[
        for (final row in goals)
          <String, Object?>{
            'id': row.id,
            'indicatorKey': row.indicatorKey,
            'role': row.role,
            'activeSlotIndex': row.activeSlotIndex,
            'title': row.title,
            'iconId': row.iconId,
            'status': row.status,
            'createdAtUtc': row.createdAtUtc.toUtc().toIso8601String(),
            'updatedAtUtc': row.updatedAtUtc.toUtc().toIso8601String(),
            'archivedAtUtc': row.archivedAtUtc?.toUtc().toIso8601String(),
          },
      ],
      'goalActivities': <Map<String, Object?>>[
        for (final row in activities)
          <String, Object?>{
            'id': row.id,
            'goalId': row.goalId,
            'operationId': row.operationId,
            'action': row.action,
            'previousValue': row.previousValue,
            'newValue': row.newValue,
            'occurredAtUtc': row.occurredAtUtc.toUtc().toIso8601String(),
          },
      ],
      'goalTargets': targetRows.values.toList(growable: false),
      'goalOutboxOperations': <Map<String, Object?>>[
        for (final row in outbox)
          <String, Object?>{
            'operationId': row.operationId,
            'entityType': row.entityType,
            'entityId': row.entityId,
            'action': row.action,
            'payloadJson': row.payloadJson,
            'createdAtUtc': row.createdAtUtc.toUtc().toIso8601String(),
          },
      ],
    };
  }

  @override
  Future<void> importGoalBackup({
    required String profileId,
    required Map<String, Object?> backup,
  }) async {
    await ensureCanonicalGoals(profileId);
    final incomingGoals = _backupMaps(backup['goals']);
    final incomingActivities = _backupMaps(backup['goalActivities']);
    final incomingTargets = _backupMaps(
      backup['goalTargets'] ?? backup['targets'],
    );
    final incomingOutbox = _backupMaps(backup['goalOutboxOperations']);
    await database.transaction(() async {
      final currentRows = await (database.select(
        database.goals,
      )..where((table) => table.profileId.equals(profileId))).get();
      final merged = <String, _BackupGoalRecord>{
        for (final row in currentRows)
          row.id: _BackupGoalRecord.fromGoal(_mapGoal(row)),
      };
      final incoming = <String, _BackupGoalRecord>{};
      for (final map in incomingGoals) {
        final record = _BackupGoalRecord.fromMap(
          map,
          fallbackNowUtc: clock.nowUtc(),
        );
        incoming[record.id] = record;
        merged[record.id] = record;
      }
      _validateBackupOccupancy(merged.values);

      for (final record in incoming.values) {
        final existing = currentRows
            .where((row) => row.id == record.id)
            .firstOrNull;
        if (existing == null) {
          await database
              .into(database.goals)
              .insert(_goalCompanion(record.toGoal(profileId)));
        } else {
          await (database.update(database.goals)..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.id.equals(record.id),
              ))
              .write(
                GoalsCompanion(
                  indicatorKey: Value<String?>(record.indicatorKey),
                  role: Value<String>(record.role.storageName),
                  activeSlotIndex: Value<int?>(record.activeSlotIndex),
                  title: Value<String>(record.title),
                  iconId: Value<String?>(record.iconId),
                  status: Value<String>(record.status.name),
                  updatedAtUtc: Value<DateTime>(record.updatedAtUtc),
                  archivedAtUtc: Value<DateTime?>(record.archivedAtUtc),
                ),
              );
        }
      }

      final validGoalIds = merged.keys.toSet();
      for (final map in incomingActivities) {
        final goalId = _requiredBackupString(map, 'goalId');
        if (!validGoalIds.contains(goalId)) {
          throw const GoalValidationException(
            'Goal backup activity references an unknown Goal.',
          );
        }
        final id = _requiredBackupString(map, 'id');
        final operationId = _backupString(map['operationId']) ?? id;
        await database
            .into(database.goalActivities)
            .insert(
              GoalActivitiesCompanion.insert(
                id: id,
                profileId: profileId,
                goalId: goalId,
                operationId: operationId,
                action:
                    _backupString(map['action']) ??
                    GoalActivityAction.created.name,
                previousValue: Value<String?>(
                  _backupString(map['previousValue']),
                ),
                newValue: Value<String?>(_backupString(map['newValue'])),
                occurredAtUtc: _backupDate(
                  map['occurredAtUtc'],
                  clock.nowUtc(),
                ),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      final targetIds = <String>{};
      for (final map in incomingTargets) {
        final id = _requiredBackupString(map, 'id');
        if (!targetIds.add(id)) {
          continue;
        }
        final goalId = _backupString(map['goalId']);
        final indicatorKey =
            _backupString(map['indicatorKey']) ??
            (goalId == null ? null : merged[goalId]?.indicatorKey);
        final resolvedGoalId =
            goalId ??
            (indicatorKey == null
                ? null
                : merged.values
                      .where((record) => record.indicatorKey == indicatorKey)
                      .firstOrNull
                      ?.id);
        if (resolvedGoalId == null || !validGoalIds.contains(resolvedGoalId)) {
          throw const GoalValidationException(
            'Goal backup target references an unknown Goal.',
          );
        }
        final periodType = _backupPeriodType(map['periodType']);
        final periodStart = _requiredBackupString(map, 'periodStartDate');
        final operationId = _backupString(map['operationId']) ?? id;
        await database
            .into(database.indicatorGoalRevisions)
            .insert(
              IndicatorGoalRevisionsCompanion.insert(
                id: id,
                profileId: profileId,
                goalId: Value<String?>(resolvedGoalId),
                indicatorKey: indicatorKey ?? 'goal:$resolvedGoalId',
                periodType: periodType.name,
                periodStartDate: periodStart,
                periodEndDate:
                    _backupString(map['periodEndDate']) ??
                    _periodEndDate(periodType, periodStart),
                state: _backupString(map['state']) ?? 'notSet',
                valueScaled: Value<int?>(_backupInt(map['valueScaled'])),
                valueScale: _backupInt(map['valueScale']) ?? 0,
                unit: _backupString(map['unit']) ?? 'count',
                supersedesRevisionId: Value<String?>(
                  _backupString(map['supersedesRevisionId']),
                ),
                operationId: operationId,
                createdAtUtc: _backupDate(map['createdAtUtc'], clock.nowUtc()),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      for (final map in incomingOutbox) {
        final operationId = _backupString(map['operationId']);
        final entityId = _backupString(map['entityId']);
        if (operationId == null ||
            entityId == null ||
            !validGoalIds.contains(entityId)) {
          continue;
        }
        await database
            .into(database.goalOutboxOperations)
            .insert(
              GoalOutboxOperationsCompanion.insert(
                operationId: operationId,
                profileId: profileId,
                entityType: _backupString(map['entityType']) ?? 'goal',
                entityId: entityId,
                action: _backupString(map['action']) ?? 'updated',
                payloadJson: _backupString(map['payloadJson']) ?? '{}',
                createdAtUtc: _backupDate(map['createdAtUtc'], clock.nowUtc()),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  @override
  Future<Map<String, Object?>> exportBackup(String profileId) {
    return exportGoalBackup(profileId);
  }

  @override
  Future<void> importBackup({
    required String profileId,
    required Map<String, Object?> backup,
  }) {
    return importGoalBackup(profileId: profileId, backup: backup);
  }

  @override
  Future<GoalPlanningSnapshot> readPlanning({
    required String profileId,
    required PlannerDate periodStart,
  }) async {
    final goals = await readActiveGoals(profileId);
    final progress = <GoalProgress>[];
    for (final goal in goals) {
      final value = await _readProgress(
        goal: goal,
        today: periodStart,
        periodStart: periodStart,
      );
      progress.add(value);
    }
    return GoalPlanningSnapshot(
      periodStart: _mondayOf(periodStart),
      periodEnd: _mondayOf(periodStart).addDays(6),
      daily: progress
          .where((value) => value.goal.role == GoalRole.dailyWeekly)
          .firstOrNull,
      weekly: progress
          .where((value) => value.goal.role == GoalRole.weekly)
          .toList(growable: false),
      monthly: progress
          .where((value) => value.goal.role == GoalRole.weeklyMonthly)
          .firstOrNull,
    );
  }

  @override
  Future<GoalProgress?> readProgress({
    required String profileId,
    required String goalId,
    required PlannerDate today,
  }) async {
    final goal = await readGoal(profileId: profileId, goalId: goalId);
    if (goal == null) {
      return null;
    }
    return _readProgress(goal: goal, today: today, periodStart: today);
  }

  Future<GoalProgress> _readProgress({
    required Goal goal,
    required PlannerDate today,
    required PlannerDate periodStart,
  }) async {
    final unit = await _unitForGoal(goal);
    final dailyPeriod = IndicatorGoalPeriod.daily(today);
    final weeklyPeriod = IndicatorGoalPeriod.weekly(periodStart);
    final monthlyPeriod = IndicatorGoalPeriod.monthly(today);
    final daily = await _target(goal, dailyPeriod, unit);
    final weekly = await _target(goal, weeklyPeriod, unit);
    final monthly = await _target(goal, monthlyPeriod, unit);
    return GoalProgress(
      goal: goal,
      dailyActual: await _actual(goal, dailyPeriod.indicatorPeriod, unit),
      dailyTarget: _mapTarget(daily, unit),
      weeklyActual: await _actual(goal, weeklyPeriod.indicatorPeriod, unit),
      weeklyTarget: _mapTarget(weekly, unit),
      monthlyActual: await _actual(goal, monthlyPeriod.indicatorPeriod, unit),
      monthlyTarget: _mapTarget(monthly, unit),
    );
  }

  Future<IndicatorAmount> _actual(
    Goal goal,
    IndicatorPeriod period,
    String unit,
  ) async {
    final key = goal.indicatorKey;
    if (key == null) {
      return IndicatorAmount(
        scaledValue: 0,
        scale: IndicatorUnitPolicy.allowedScale(unit),
        unit: unit,
      );
    }
    final rows =
        await (database.select(database.activityLedgerEntries)..where(
              (table) =>
                  table.profileId.equals(goal.profileId) &
                  table.indicatorKey.equals(key) &
                  table.activityDate.isBiggerOrEqualValue(
                    period.start.iso8601,
                  ) &
                  table.activityDate.isSmallerOrEqualValue(period.end.iso8601),
            ))
            .get();
    final scale =
        rows.firstOrNull?.valueScale ?? IndicatorUnitPolicy.allowedScale(unit);
    return IndicatorAmount(
      scaledValue: rows.fold<int>(0, (sum, row) => sum + row.valueScaled),
      scale: scale,
      unit: unit,
    );
  }

  Future<IndicatorGoalRevisionRow?> _target(
    Goal goal,
    IndicatorGoalPeriod period,
    String unit,
  ) async {
    final byGoal =
        await (database.select(database.indicatorGoalRevisions)
              ..where(
                (table) =>
                    table.profileId.equals(goal.profileId) &
                    table.goalId.equals(goal.id) &
                    table.periodType.equals(period.type.name) &
                    table.periodStartDate.equals(period.start.iso8601),
              )
              ..orderBy(<OrderingTerm Function(IndicatorGoalRevisions)>[
                (table) => OrderingTerm.desc(table.createdAtUtc),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (byGoal != null) {
      return byGoal;
    }
    final key = goal.indicatorKey;
    if (key == null) {
      return null;
    }
    return (database.select(database.indicatorGoalRevisions)
          ..where(
            (table) =>
                table.profileId.equals(goal.profileId) &
                table.indicatorKey.equals(key) &
                table.periodType.equals(period.type.name) &
                table.periodStartDate.equals(period.start.iso8601),
          )
          ..orderBy(<OrderingTerm Function(IndicatorGoalRevisions)>[
            (table) => OrderingTerm.desc(table.createdAtUtc),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  IndicatorTarget _mapTarget(IndicatorGoalRevisionRow? row, String unit) {
    if (row == null || row.state != 'explicit' || row.valueScaled == null) {
      return const IndicatorTarget.notSet();
    }
    return IndicatorTarget.explicit(
      IndicatorAmount(
        scaledValue: row.valueScaled!,
        scale: row.valueScale,
        unit: row.unit.isEmpty ? unit : row.unit,
      ),
    );
  }

  Future<String> _unitForGoal(Goal goal) async {
    final key = goal.indicatorKey;
    if (key == null) {
      return 'count';
    }
    final row =
        await (database.select(database.lifeIndicatorDefinitions)
              ..where(
                (table) =>
                    table.profileId.equals(goal.profileId) &
                    table.indicatorKey.equals(key),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.unit ?? 'count';
  }

  Future<int> _freeSlot(String profileId, GoalRole role) async {
    final used =
        await (database.select(database.goals)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.status.equals(GoalStatus.active.name),
            ))
            .get();
    final slots = switch (role) {
      GoalRole.dailyWeekly => <int>[1],
      GoalRole.weekly => <int>[2, 3, 4, 5],
      GoalRole.weeklyMonthly => <int>[6],
    };
    final available = slots.where(
      (slot) => used.every((row) => row.activeSlotIndex != slot),
    );
    final slot = available.firstOrNull;
    if (slot == null) {
      throw GoalCapacityException(role);
    }
    return slot;
  }

  Future<void> _writeTargets({
    required Goal goal,
    required GoalTargets targets,
    required String operationId,
  }) async {
    final unit = await _unitForGoal(goal);
    final values = <IndicatorGoalPeriod, IndicatorAmount?>{
      if (goal.role == GoalRole.dailyWeekly)
        IndicatorGoalPeriod.daily(_today()): targets.daily,
      if (goal.role == GoalRole.dailyWeekly || goal.role == GoalRole.weekly)
        IndicatorGoalPeriod.weekly(_today()): targets.weekly,
      if (goal.role ==
          GoalRole.weeklyMonthly) ...<IndicatorGoalPeriod, IndicatorAmount?>{
        IndicatorGoalPeriod.weekly(_today()): targets.weekly,
        IndicatorGoalPeriod.monthly(_today()): targets.monthly,
      },
    };
    for (final entry in values.entries) {
      final value = entry.value;
      if (value != null &&
          (value.scaledValue < 0 ||
              value.unit != unit ||
              value.scale != IndicatorUnitPolicy.allowedScale(unit))) {
        throw const GoalValidationException('Goal target is invalid.');
      }
      final prior = await _target(goal, entry.key, unit);
      final priorValue = prior?.state == 'explicit' ? prior?.valueScaled : null;
      final nextValue = value?.scaledValue;
      if (prior != null && priorValue == nextValue) {
        continue;
      }
      await database
          .into(database.indicatorGoalRevisions)
          .insert(
            IndicatorGoalRevisionsCompanion.insert(
              id: identifiers.nextUuid(),
              profileId: goal.profileId,
              goalId: Value<String?>(goal.id),
              indicatorKey: goal.indicatorKey ?? 'goal:${goal.id}',
              periodType: entry.key.type.name,
              periodStartDate: entry.key.start.iso8601,
              periodEndDate: entry.key.end.iso8601,
              state: value == null ? 'notSet' : 'explicit',
              valueScaled: Value<int?>(value?.scaledValue),
              valueScale:
                  value?.scale ?? IndicatorUnitPolicy.allowedScale(unit),
              unit: unit,
              supersedesRevisionId: Value<String?>(prior?.id),
              operationId:
                  '$operationId:target:${entry.key.type.name}:${entry.key.start.iso8601}',
              createdAtUtc: clock.nowUtc(),
            ),
          );
    }
  }

  Future<void> _ensureCurrentTargetsAfterRestore({
    required Goal goal,
    required String operationId,
  }) async {
    final today = _today();
    final unit = await _unitForGoal(goal);
    final periods = <IndicatorGoalPeriod>[
      if (goal.role == GoalRole.dailyWeekly) IndicatorGoalPeriod.daily(today),
      if (goal.role == GoalRole.dailyWeekly || goal.role == GoalRole.weekly)
        IndicatorGoalPeriod.weekly(today),
      if (goal.role == GoalRole.weeklyMonthly) ...<IndicatorGoalPeriod>[
        IndicatorGoalPeriod.weekly(today),
        IndicatorGoalPeriod.monthly(today),
      ],
    ];
    for (final period in periods) {
      final current =
          await (database.select(database.indicatorGoalRevisions)
                ..where(
                  (table) =>
                      table.profileId.equals(goal.profileId) &
                      table.goalId.equals(goal.id) &
                      table.periodType.equals(period.type.name) &
                      table.periodStartDate.equals(period.start.iso8601),
                )
                ..orderBy(<OrderingTerm Function(IndicatorGoalRevisions)>[
                  (table) => OrderingTerm.desc(table.createdAtUtc),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (current != null) {
        continue;
      }
      final historical =
          await (database.select(database.indicatorGoalRevisions)
                ..where(
                  (table) =>
                      table.profileId.equals(goal.profileId) &
                      table.goalId.equals(goal.id) &
                      table.periodType.equals(period.type.name) &
                      table.periodStartDate.isSmallerThanValue(
                        period.start.iso8601,
                      ) &
                      table.state.equals('explicit') &
                      table.valueScaled.isNotNull(),
                )
                ..orderBy(<OrderingTerm Function(IndicatorGoalRevisions)>[
                  (table) => OrderingTerm.desc(table.periodStartDate),
                  (table) => OrderingTerm.desc(table.createdAtUtc),
                ])
                ..limit(1))
              .getSingleOrNull();
      if (historical == null) {
        continue;
      }
      await database
          .into(database.indicatorGoalRevisions)
          .insert(
            IndicatorGoalRevisionsCompanion.insert(
              id: identifiers.nextUuid(),
              profileId: goal.profileId,
              goalId: Value<String?>(goal.id),
              indicatorKey: goal.indicatorKey ?? 'goal:${goal.id}',
              periodType: period.type.name,
              periodStartDate: period.start.iso8601,
              periodEndDate: period.end.iso8601,
              state: 'explicit',
              valueScaled: Value<int?>(historical.valueScaled),
              valueScale: historical.valueScale,
              unit: historical.unit.isEmpty ? unit : historical.unit,
              supersedesRevisionId: const Value<String?>(null),
              operationId:
                  '$operationId:restore-target:${period.type.name}:${period.start.iso8601}',
              createdAtUtc: clock.nowUtc(),
            ),
          );
    }
  }

  // Target writes use the repository clock, not wall-clock time from the
  // caller, so daily/monthly boundaries are stable under fake-clock tests.
  PlannerDate _today() => PlannerDate.fromDateTime(clock.nowUtc().toLocal());

  Future<void> _mutateLifecycle({
    required String profileId,
    required String goalId,
    required GoalActivityAction action,
    String? operationId,
  }) async {
    final effectiveOperationId = operationId ?? identifiers.nextUuid();
    await database.transaction(() async {
      final prior = await _goalForOperation(profileId, effectiveOperationId);
      if (prior != null) {
        return;
      }
      final row = await _goalRow(profileId, goalId);
      if (row == null || row.status != GoalStatus.active.name) {
        throw const GoalValidationException('Active Goal was not found.');
      }
      final goal = _mapGoal(row);
      final now = clock.nowUtc();
      await (database.update(database.goals)..where(
            (table) =>
                table.profileId.equals(profileId) & table.id.equals(goalId),
          ))
          .write(
            GoalsCompanion(
              status: Value<String>(GoalStatus.archived.name),
              activeSlotIndex: const Value<int?>(null),
              archivedAtUtc: Value<DateTime?>(now),
              updatedAtUtc: Value<DateTime>(now),
            ),
          );
      final archived = _mapGoal((await _goalRow(profileId, goalId))!);
      await _writeActivity(
        goal: archived,
        action: action,
        operationId: effectiveOperationId,
        newValue: archived.title,
      );
      await _writeOutbox(
        profileId: profileId,
        goalId: goalId,
        operationId: effectiveOperationId,
        action: action.name,
        payload: <String, Object?>{'goalId': goalId, 'title': goal.title},
      );
    });
  }

  Future<void> _writeActivity({
    required Goal goal,
    required GoalActivityAction action,
    required String operationId,
    String? previousValue,
    String? newValue,
  }) async {
    await database
        .into(database.goalActivities)
        .insert(
          GoalActivitiesCompanion.insert(
            id: identifiers.nextUuid(),
            profileId: goal.profileId,
            goalId: goal.id,
            operationId: operationId,
            action: action.name,
            previousValue: Value<String?>(previousValue),
            newValue: Value<String?>(newValue),
            occurredAtUtc: clock.nowUtc(),
          ),
        );
  }

  Future<void> _writeOutbox({
    required String profileId,
    required String goalId,
    required String operationId,
    required String action,
    required Map<String, Object?> payload,
  }) async {
    await database
        .into(database.goalOutboxOperations)
        .insert(
          GoalOutboxOperationsCompanion.insert(
            operationId: operationId,
            profileId: profileId,
            entityType: 'goal',
            entityId: goalId,
            action: action,
            payloadJson: jsonEncode(payload),
            createdAtUtc: clock.nowUtc(),
          ),
        );
  }

  Future<Goal?> _goalForOperation(String profileId, String operationId) async {
    final operation =
        await (database.select(database.goalOutboxOperations)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.operationId.equals(operationId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (operation == null) {
      return null;
    }
    final row = await _goalRow(profileId, operation.entityId);
    return row == null ? null : _mapGoal(row);
  }

  Future<GoalRow?> _goalRow(String profileId, String goalId) {
    return (database.select(database.goals)
          ..where(
            (table) =>
                table.profileId.equals(profileId) & table.id.equals(goalId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Map<String, GoalRow>> _goalMappings(String profileId) async {
    final rows = await (database.select(
      database.goals,
    )..where((table) => table.profileId.equals(profileId))).get();
    return <String, GoalRow>{
      for (final row in rows)
        if (row.indicatorKey != null) row.indicatorKey!: row,
    };
  }

  Goal _mapGoal(GoalRow row) {
    return Goal(
      id: row.id,
      profileId: row.profileId,
      indicatorKey: row.indicatorKey,
      role: _roleFromName(row.role),
      activeSlotIndex: row.activeSlotIndex,
      title: row.title,
      iconId: row.iconId,
      status: row.status == GoalStatus.archived.name
          ? GoalStatus.archived
          : GoalStatus.active,
      createdAtUtc: row.createdAtUtc.toUtc(),
      updatedAtUtc: row.updatedAtUtc.toUtc(),
      archivedAtUtc: row.archivedAtUtc?.toUtc(),
    );
  }

  GoalActivity _mapActivity(GoalActivityRow row) {
    return GoalActivity(
      id: row.id,
      profileId: row.profileId,
      goalId: row.goalId,
      operationId: row.operationId,
      action: GoalActivityAction.values.firstWhere(
        (value) => value.name == row.action,
        orElse: () => GoalActivityAction.created,
      ),
      previousValue: row.previousValue,
      newValue: row.newValue,
      occurredAtUtc: row.occurredAtUtc.toUtc(),
    );
  }

  GoalsCompanion _goalCompanion(Goal goal) {
    return GoalsCompanion.insert(
      id: goal.id,
      profileId: goal.profileId,
      indicatorKey: Value<String?>(goal.indicatorKey),
      role: goal.role.storageName,
      activeSlotIndex: Value<int?>(goal.activeSlotIndex),
      title: goal.title,
      iconId: Value<String?>(goal.iconId),
      status: goal.status.name,
      createdAtUtc: goal.createdAtUtc,
      updatedAtUtc: goal.updatedAtUtc,
      archivedAtUtc: Value<DateTime?>(goal.archivedAtUtc),
    );
  }

  GoalRole _roleFromName(String value) {
    return GoalRole.values.firstWhere(
      (role) => role.storageName == value,
      orElse: () => GoalRole.weekly,
    );
  }

  Map<String, Object?> _targetsPayload(GoalTargets targets) {
    return <String, Object?>{
      'daily': targets.daily?.scaledValue,
      'weekly': targets.weekly?.scaledValue,
      'monthly': targets.monthly?.scaledValue,
    };
  }

  PlannerDate _mondayOf(PlannerDate date) {
    return date.addDays(-(date.asLocalDate.weekday - DateTime.monday));
  }
}

Map<String, Object?> _exportGoalTarget({
  required String id,
  required String goalId,
  required String indicatorKey,
  required String periodType,
  required String periodStartDate,
  required String periodEndDate,
  required String state,
  required int? valueScaled,
  required int valueScale,
  required String unit,
  required String? supersedesRevisionId,
  required String operationId,
  required DateTime createdAtUtc,
}) {
  return <String, Object?>{
    'id': id,
    'goalId': goalId,
    'indicatorKey': indicatorKey,
    'periodType': periodType,
    'periodStartDate': periodStartDate,
    'periodEndDate': periodEndDate,
    'state': state,
    'valueScaled': valueScaled,
    'valueScale': valueScale,
    'unit': unit,
    'supersedesRevisionId': supersedesRevisionId,
    'operationId': operationId,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
  };
}

String _periodEndDate(IndicatorGoalPeriodType type, String startDate) {
  final start = PlannerDate.fromDateTime(DateTime.parse(startDate));
  return switch (type) {
    IndicatorGoalPeriodType.daily => start.iso8601,
    IndicatorGoalPeriodType.weekly => start.addDays(6).iso8601,
    IndicatorGoalPeriodType.monthly => IndicatorGoalPeriod.monthly(
      start,
    ).end.iso8601,
  };
}

List<Map<String, Object?>> _backupMaps(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map(
        (row) => <String, Object?>{
          for (final entry in row.entries)
            if (entry.key is String) entry.key as String: entry.value,
        },
      )
      .toList(growable: false);
}

String? _backupString(Object? value) {
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
  return null;
}

String _requiredBackupString(Map<String, Object?> map, String key) {
  final value = _backupString(map[key]);
  if (value == null) {
    throw GoalValidationException('Goal backup is missing "$key".');
  }
  return value;
}

int? _backupInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return value is String ? int.tryParse(value) : null;
}

DateTime _backupDate(Object? value, DateTime fallback) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toUtc();
    }
  }
  return fallback.toUtc();
}

IndicatorGoalPeriodType _backupPeriodType(Object? value) {
  final name = _backupString(value);
  for (final periodType in IndicatorGoalPeriodType.values) {
    if (periodType.name == name) {
      return periodType;
    }
  }
  throw const GoalValidationException(
    'Goal backup has an invalid period type.',
  );
}

GoalRole _backupRole(Object? value) {
  final name = _backupString(value);
  for (final role in GoalRole.values) {
    if (role.storageName == name) {
      return role;
    }
  }
  throw const GoalValidationException('Goal backup has an invalid Goal role.');
}

GoalStatus _backupStatus(Map<String, Object?> map) {
  if (map['isArchived'] == true) {
    return GoalStatus.archived;
  }
  final value = _backupString(map['status']);
  return value == GoalStatus.archived.name
      ? GoalStatus.archived
      : GoalStatus.active;
}

bool _slotSupportsRole(GoalRole role, int slot) {
  return switch (role) {
    GoalRole.dailyWeekly => slot == 1,
    GoalRole.weekly => slot >= 2 && slot <= 5,
    GoalRole.weeklyMonthly => slot == 6,
  };
}

void _validateBackupOccupancy(Iterable<_BackupGoalRecord> records) {
  final active = records.where((record) => record.status == GoalStatus.active);
  final owners = <int, String>{};
  final counts = <GoalRole, int>{for (final role in GoalRole.values) role: 0};
  for (final record in active) {
    final slot = record.activeSlotIndex;
    if (slot == null || !_slotSupportsRole(record.role, slot)) {
      throw GoalValidationException(
        'Goal "${record.title}" has an incompatible active slot.',
      );
    }
    final prior = owners[slot];
    if (prior != null && prior != record.id) {
      throw const GoalValidationException(
        'Goal backup contains a conflicting active slot.',
      );
    }
    owners[slot] = record.id;
    counts[record.role] = (counts[record.role] ?? 0) + 1;
  }
  for (final role in GoalRole.values) {
    if ((counts[role] ?? 0) > role.capacity) {
      throw GoalCapacityException(role);
    }
  }
}

final class _BackupGoalRecord {
  const _BackupGoalRecord({
    required this.id,
    required this.indicatorKey,
    required this.role,
    required this.activeSlotIndex,
    required this.title,
    required this.iconId,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.archivedAtUtc,
  });

  final String id;
  final String? indicatorKey;
  final GoalRole role;
  final int? activeSlotIndex;
  final String title;
  final String? iconId;
  final GoalStatus status;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? archivedAtUtc;

  factory _BackupGoalRecord.fromGoal(Goal goal) {
    return _BackupGoalRecord(
      id: goal.id,
      indicatorKey: goal.indicatorKey,
      role: goal.role,
      activeSlotIndex: goal.activeSlotIndex,
      title: goal.title,
      iconId: goal.iconId,
      status: goal.status,
      createdAtUtc: goal.createdAtUtc,
      updatedAtUtc: goal.updatedAtUtc,
      archivedAtUtc: goal.archivedAtUtc,
    );
  }

  factory _BackupGoalRecord.fromMap(
    Map<String, Object?> map, {
    required DateTime fallbackNowUtc,
  }) {
    final id = _requiredBackupString(map, 'id');
    final role = _backupRole(map['role']);
    final status = _backupStatus(map);
    final title = _requiredBackupString(map, 'title');
    final requestedSlot = _backupInt(
      map['activeSlotIndex'] ?? map['activeSlot'] ?? map['slot'],
    );
    final slot = status == GoalStatus.active
        ? requestedSlot ?? (role == GoalRole.weekly ? null : role.slotIndex)
        : null;
    if (status == GoalStatus.active && slot == null) {
      throw GoalValidationException(
        'Active Weekly Goal "$title" is missing its slot.',
      );
    }
    if (slot != null && !_slotSupportsRole(role, slot)) {
      throw GoalValidationException(
        'Goal "$title" has an incompatible active slot.',
      );
    }
    final created = _backupDate(map['createdAtUtc'], fallbackNowUtc);
    return _BackupGoalRecord(
      id: id,
      indicatorKey: _backupString(map['indicatorKey']),
      role: role,
      activeSlotIndex: slot,
      title: title,
      iconId: _backupString(map['iconId']),
      status: status,
      createdAtUtc: created,
      updatedAtUtc: _backupDate(map['updatedAtUtc'], created),
      archivedAtUtc: status == GoalStatus.archived
          ? _backupDateOrNull(map['archivedAtUtc']) ?? created
          : null,
    );
  }

  Goal toGoal(String profileId) {
    return Goal(
      id: id,
      profileId: profileId,
      indicatorKey: indicatorKey,
      role: role,
      activeSlotIndex: activeSlotIndex,
      title: title,
      iconId: iconId,
      status: status,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc,
      archivedAtUtc: archivedAtUtc,
    );
  }
}

DateTime? _backupDateOrNull(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }
  return null;
}
