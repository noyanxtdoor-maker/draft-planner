import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/indicators/application/indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';
import 'package:uuid/uuid.dart';

final class DriftIndicatorRepository implements IndicatorRepository {
  const DriftIndicatorRepository({
    required this.database,
    required this.clock,
    required this.calendarEvents,
  });

  final AppDatabase database;
  final AppClock clock;
  final CalendarEventRepository calendarEvents;

  @override
  Stream<void> watchChanges(String profileId) {
    return database
        .tableUpdates(
          TableUpdateQuery.onAllTables(<ResultSetImplementation>[
            database.lifeIndicatorDefinitions,
            database.weeklyIndicatorTargetRevisions,
            database.indicatorGoalRevisions,
            database.indicatorCommitmentLinks,
            database.activityLedgerEntries,
            database.outcomeReports,
            database.plannerTasks,
            database.calendarEvents,
            database.calendarEventExceptions,
            database.taskEventLinks,
          ]),
        )
        .map((_) {});
  }

  @override
  Future<HomeIndicatorSnapshot> readHome({
    required String profileId,
    required IndicatorPeriod period,
    required PlannerDate today,
  }) async {
    final definitions =
        await (database.select(database.lifeIndicatorDefinitions)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(LifeIndicatorDefinitions)>[
                (table) => OrderingTerm.asc(table.position),
              ]))
            .get();
    final targets = await _latestTargets(profileId, period.start);
    final currentWeekPlanned =
        definitions.isNotEmpty &&
        definitions.every(
          (definition) => targets[definition.indicatorKey]?.state == 'explicit',
        );
    final scheduled = await _scheduledSources(
      profileId: profileId,
      period: period,
      today: today,
    );
    final staleKeys = await _staleIndicatorKeys(profileId);
    final nextTempleVisit = await _readNextTempleVisit(
      profileId: profileId,
      today: today,
    );
    IndicatorAmount? monthlyTempleActual;
    IndicatorTarget? monthlyTempleTarget;
    final templeDefinition = definitions
        .where((definition) => definition.indicatorKey == 'temple_visit')
        .firstOrNull;
    if (templeDefinition != null) {
      final monthly = await _readGoalSnapshot(
        profileId: profileId,
        indicatorKey: templeDefinition.indicatorKey,
        period: IndicatorGoalPeriod.monthly(today),
        today: today,
        definition: templeDefinition,
      );
      monthlyTempleActual = monthly.actual;
      monthlyTempleTarget = monthly.target;
    }
    final indicators = <LifeIndicatorSummary>[];
    for (final definition in definitions) {
      try {
        final actual = await _readActual(
          profileId: profileId,
          definition: definition,
          period: period,
        );
        final sources =
            scheduled.sourcesByIndicator[definition.indicatorKey] ??
            const <ScheduledIndicatorSource>[];
        indicators.add(
          LifeIndicatorSummary(
            key: definition.indicatorKey,
            label: definition.label,
            unit: definition.unit,
            position: definition.position,
            actual: actual,
            target: _mapTarget(targets[definition.indicatorKey]),
            scheduledPotential: _sumSources(sources, definition.unit),
            scheduledSources: sources,
            projectionState: staleKeys.contains(definition.indicatorKey)
                ? IndicatorProjectionState.stale
                : IndicatorProjectionState.current,
          ),
        );
      } on Object {
        indicators.add(
          LifeIndicatorSummary(
            key: definition.indicatorKey,
            label: definition.label,
            unit: definition.unit,
            position: definition.position,
            actual: IndicatorAmount(
              scaledValue: 0,
              scale: IndicatorUnitPolicy.allowedScale(definition.unit),
              unit: definition.unit,
            ),
            target: _mapTarget(targets[definition.indicatorKey]),
            scheduledPotential: IndicatorAmount(
              scaledValue: 0,
              scale: IndicatorUnitPolicy.allowedScale(definition.unit),
              unit: definition.unit,
            ),
            scheduledSources: const <ScheduledIndicatorSource>[],
            projectionState: IndicatorProjectionState.failed,
            failureMessage: 'Projection unavailable. Other indicators remain.',
          ),
        );
      }
    }
    return HomeIndicatorSnapshot(
      period: period,
      indicators: indicators,
      overdueTaskCount: scheduled.overdueTaskCount,
      awaitingReportCount: scheduled.awaitingReportCount,
      nextTempleVisit: nextTempleVisit,
      currentWeekPlanned: currentWeekPlanned,
      monthlyTempleActual: monthlyTempleActual,
      monthlyTempleTarget: monthlyTempleTarget,
    );
  }

  @override
  Future<IndicatorDetail?> readDetail({
    required String profileId,
    required String indicatorKey,
    required IndicatorPeriod period,
    required PlannerDate today,
  }) async {
    final snapshot = await readHome(
      profileId: profileId,
      period: period,
      today: today,
    );
    final matches = snapshot.indicators.where(
      (indicator) => indicator.key == indicatorKey,
    );
    if (matches.isEmpty) {
      return null;
    }
    final rows =
        await (database.select(database.activityLedgerEntries)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.indicatorKey.equals(indicatorKey) &
                    table.activityDate.isBiggerOrEqualValue(
                      period.start.iso8601,
                    ) &
                    table.activityDate.isSmallerOrEqualValue(
                      period.end.iso8601,
                    ),
              )
              ..orderBy(<OrderingTerm Function(ActivityLedgerEntries)>[
                (table) => OrderingTerm.desc(table.recordedAtUtc),
              ]))
            .get();
    final reportIds = rows.map((row) => row.sourceReportId).toSet();
    final reports = reportIds.isEmpty
        ? const <OutcomeReportRow>[]
        : await (database.select(
            database.outcomeReports,
          )..where((table) => table.id.isIn(reportIds))).get();
    final labels = <String, String>{
      for (final report in reports) report.id: report.sourceLabel,
    };
    return IndicatorDetail(
      summary: matches.single,
      period: period,
      contributionHistory: <IndicatorContributionHistoryItem>[
        for (final row in rows)
          IndicatorContributionHistoryItem(
            entryId: row.id,
            reportId: row.sourceReportId,
            sourceLabel: labels[row.sourceReportId] ?? 'Current Status',
            activityDate: PlannerDate.parse(row.activityDate),
            value: IndicatorAmount(
              scaledValue: row.valueScaled,
              scale: row.valueScale,
              unit: row.unit,
            ),
            isReversal: row.entryType == ActivityLedgerEntryType.reversal.name,
          ),
      ],
    );
  }

  @override
  Future<void> saveTarget({
    required String profileId,
    required IndicatorTargetRevisionDraft draft,
  }) async {
    await saveGoal(
      profileId: profileId,
      draft: IndicatorGoalRevisionDraft(
        id: draft.id,
        operationId: draft.operationId,
        indicatorKey: draft.indicatorKey,
        period: IndicatorGoalPeriod.weekly(draft.period.start),
        value: draft.value,
      ),
    );
  }

  @override
  Future<void> saveGoal({
    required String profileId,
    required IndicatorGoalRevisionDraft draft,
  }) async {
    if (!Uuid.isValidUUID(fromString: draft.id) ||
        !Uuid.isValidUUID(fromString: draft.operationId)) {
      throw StateError('Goal revisions require stable UUID identities');
    }
    await database.transaction(() async {
      final priorOperation =
          await (database.select(database.indicatorGoalRevisions)
                ..where((table) => table.operationId.equals(draft.operationId))
                ..limit(1))
              .getSingleOrNull();
      if (priorOperation != null) {
        return;
      }
      if (draft.period.type == IndicatorGoalPeriodType.weekly) {
        final plan =
            await (database.select(database.weeklyPlans)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.periodStartDate.equals(
                          draft.period.start.iso8601,
                        ),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (plan != null &&
            (plan.state == 'reviewed' || plan.state == 'historical')) {
          throw StateError(
            'Reviewed and historical Weekly Plan targets are read-only',
          );
        }
      }
      final definition = await _definition(profileId, draft.indicatorKey);
      final value = draft.value;
      if (value != null &&
          (value.scaledValue < 0 ||
              value.unit != definition.unit ||
              value.scale !=
                  IndicatorUnitPolicy.allowedScale(definition.unit))) {
        throw StateError('Goal value does not match the indicator unit');
      }
      final prior = await _latestGoal(
        profileId: profileId,
        indicatorKey: draft.indicatorKey,
        period: draft.period,
      );
      await database
          .into(database.indicatorGoalRevisions)
          .insert(
            IndicatorGoalRevisionsCompanion.insert(
              id: draft.id,
              profileId: profileId,
              indicatorKey: draft.indicatorKey,
              periodType: draft.period.type.name,
              periodStartDate: draft.period.start.iso8601,
              periodEndDate: draft.period.end.iso8601,
              state: value == null ? 'notSet' : 'explicit',
              valueScaled: Value<int?>(value?.scaledValue),
              valueScale:
                  value?.scale ??
                  IndicatorUnitPolicy.allowedScale(definition.unit),
              unit: definition.unit,
              supersedesRevisionId: Value<String?>(prior?.id),
              operationId: draft.operationId,
              createdAtUtc: clock.nowUtc(),
            ),
          );
    });
  }

  @override
  Future<IndicatorGoalSnapshot> readGoal({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriod period,
    required PlannerDate today,
  }) async {
    final definition = await _definition(profileId, indicatorKey);
    return _readGoalSnapshot(
      profileId: profileId,
      indicatorKey: indicatorKey,
      period: period,
      today: today,
      definition: definition,
    );
  }

  @override
  Future<List<IndicatorGoalSnapshot>> readGoalHistory({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriodType periodType,
    required PlannerDate anchor,
    required PlannerDate today,
  }) async {
    final periods = <IndicatorGoalPeriod>[];
    switch (periodType) {
      case IndicatorGoalPeriodType.daily:
        for (var offset = 4; offset >= 0; offset -= 1) {
          periods.add(IndicatorGoalPeriod.daily(anchor.addDays(-offset)));
        }
      case IndicatorGoalPeriodType.weekly:
        final current = IndicatorGoalPeriod.weekly(anchor);
        for (var offset = 4; offset >= 0; offset -= 1) {
          periods.add(
            IndicatorGoalPeriod.weekly(current.start.addDays(-7 * offset)),
          );
        }
      case IndicatorGoalPeriodType.monthly:
        final cursor = IndicatorGoalPeriod.monthly(anchor);
        for (var offset = 4; offset >= 0; offset -= 1) {
          final month = DateTime(
            cursor.start.year,
            cursor.start.month - offset,
            1,
          );
          periods.add(
            IndicatorGoalPeriod.monthly(PlannerDate.fromDateTime(month)),
          );
        }
    }
    final definition = await _definition(profileId, indicatorKey);
    return <IndicatorGoalSnapshot>[
      for (final period in periods)
        await _readGoalSnapshot(
          profileId: profileId,
          indicatorKey: indicatorKey,
          period: period,
          today: today,
          definition: definition,
        ),
    ];
  }

  @override
  Future<void> renameIndicator({
    required String profileId,
    required String indicatorKey,
    required String label,
  }) async {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Label is required.');
    }
    await database.transaction(() async {
      final definitions = await (database.select(
        database.lifeIndicatorDefinitions,
      )..where((table) => table.profileId.equals(profileId))).get();
      final definition = definitions
          .where((row) => row.indicatorKey == indicatorKey)
          .firstOrNull;
      if (definition == null) {
        throw StateError('Life Indicator not found.');
      }
      final duplicate = definitions.any(
        (row) =>
            row.indicatorKey != indicatorKey &&
            row.label.trim().toLowerCase() == normalizedLabel.toLowerCase(),
      );
      if (duplicate) {
        throw StateError('Life Indicator names must be unique.');
      }
      await (database.update(database.lifeIndicatorDefinitions)..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.indicatorKey.equals(indicatorKey),
          ))
          .write(
            LifeIndicatorDefinitionsCompanion(
              label: Value<String>(normalizedLabel),
            ),
          );
    });
  }

  @override
  Future<List<IndicatorTargetRevision>> readTargetHistory({
    required String profileId,
    required String indicatorKey,
    required PlannerDate periodStart,
  }) async {
    final rows =
        await (database.select(database.indicatorGoalRevisions)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.indicatorKey.equals(indicatorKey) &
                  table.periodType.equals(IndicatorGoalPeriodType.weekly.name) &
                  table.periodStartDate.equals(periodStart.iso8601),
            ))
            .get();
    final byId = <String, IndicatorGoalRevisionRow>{
      for (final row in rows) row.id: row,
    };
    final superseded = rows
        .map((row) => row.supersedesRevisionId)
        .whereType<String>()
        .toSet();
    IndicatorGoalRevisionRow? current;
    for (final row in rows) {
      if (!superseded.contains(row.id)) {
        current = row;
        break;
      }
    }
    final ordered = <IndicatorGoalRevisionRow>[];
    while (current != null) {
      ordered.add(current);
      current = current.supersedesRevisionId == null
          ? null
          : byId[current.supersedesRevisionId];
    }
    return ordered
        .map(
          (row) => IndicatorTargetRevision(
            id: row.id,
            target: row.state == 'explicit'
                ? IndicatorTarget.explicit(
                    IndicatorAmount(
                      scaledValue: row.valueScaled!,
                      scale: row.valueScale,
                      unit: row.unit,
                    ),
                  )
                : const IndicatorTarget.notSet(),
            createdAtUtc: row.createdAtUtc.toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> linkCommitment({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriod period,
    required IndicatorCommitmentEntityType entityType,
    required String entityId,
    String? occurrenceId,
    required String linkId,
    required String operationId,
  }) async {
    if (!Uuid.isValidUUID(fromString: linkId) ||
        !Uuid.isValidUUID(fromString: operationId)) {
      throw StateError('Commitment links require stable UUID identities');
    }
    if (entityId.trim().isEmpty) {
      throw StateError('Commitment links require a source entity');
    }
    await database.transaction(() async {
      final priorOperation =
          await (database.select(database.indicatorCommitmentLinks)
                ..where((table) => table.operationId.equals(operationId))
                ..limit(1))
              .getSingleOrNull();
      if (priorOperation != null) {
        return;
      }
      await _definition(profileId, indicatorKey);
      final commitmentKey =
          '${entityType.name}:$entityId:${occurrenceId ?? ''}';
      final existing =
          await (database.select(database.indicatorCommitmentLinks)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.indicatorKey.equals(indicatorKey) &
                      table.periodType.equals(period.type.name) &
                      table.periodStartDate.equals(period.start.iso8601) &
                      table.commitmentKey.equals(commitmentKey),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        return;
      }
      await database
          .into(database.indicatorCommitmentLinks)
          .insert(
            IndicatorCommitmentLinksCompanion.insert(
              id: linkId,
              profileId: profileId,
              indicatorKey: indicatorKey,
              periodType: period.type.name,
              periodStartDate: period.start.iso8601,
              entityType: entityType.name,
              entityId: entityId,
              occurrenceId: Value<String?>(occurrenceId),
              commitmentKey: commitmentKey,
              operationId: operationId,
              createdAtUtc: clock.nowUtc(),
            ),
          );
    });
  }

  @override
  Future<List<IndicatorCommitment>> readCommitments({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriod period,
  }) async {
    final links =
        await (database.select(database.indicatorCommitmentLinks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.indicatorKey.equals(indicatorKey),
              )
              ..orderBy(<OrderingTerm Function(IndicatorCommitmentLinks)>[
                (table) => OrderingTerm.asc(table.createdAtUtc),
              ]))
            .get();
    final result = <IndicatorCommitment>[];
    final seen = <String>{};
    for (final link in links) {
      final type = IndicatorCommitmentEntityType.values
          .where((value) => value.name == link.entityType)
          .firstOrNull;
      if (type == null) {
        // Unknown link kinds are ignored so a future migration cannot make a
        // valid goal screen fail to render its other commitments.
        continue;
      }
      if (type == IndicatorCommitmentEntityType.task) {
        final task =
            await (database.select(database.plannerTasks)
                  ..where(
                    (table) =>
                        table.profileId.equals(profileId) &
                        table.id.equals(link.entityId),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (task == null || task.status == 'cancelled') {
          continue;
        }
        final date = task.dueDate == null
            ? null
            : PlannerDate.parse(task.dueDate!);
        final inCreationPeriod =
            link.periodType == period.type.name &&
            link.periodStartDate == period.start.iso8601;
        if (date == null && !inCreationPeriod) {
          continue;
        }
        if (date != null && !period.indicatorPeriod.contains(date)) {
          continue;
        }
        final identity = '${link.id}:task:${task.id}';
        if (!seen.add(identity)) {
          continue;
        }
        result.add(
          IndicatorCommitment(
            linkId: link.id,
            indicatorKey: indicatorKey,
            entityType: type,
            entityId: task.id,
            label: task.title,
            date: date,
            startMinute: task.dueMinute,
            endMinute: task.dueMinute == null ? null : task.dueMinute! + 30,
            colorArgb: 0xFF8C8F93,
            isRecurring: _isRecurringTask(task.recurrenceFrequency),
            statusLabel: _taskStatusLabel(task.status),
            isBackup: false,
            occurrenceId: link.occurrenceId,
            isUnscheduled: date == null,
          ),
        );
        continue;
      }

      final draft = await calendarEvents.readEventDraft(
        profileId: profileId,
        eventId: link.entityId,
      );
      if (draft == null) {
        continue;
      }
      final dates = _commitmentEventDates(draft, period);
      for (final originalDate in dates) {
        final occurrence = await calendarEvents.readOccurrence(
          profileId: profileId,
          eventId: link.entityId,
          originalDate: originalDate,
        );
        if (occurrence == null ||
            occurrence.status == CalendarEventStatus.cancelled ||
            !period.indicatorPeriod.contains(occurrence.displayDate)) {
          continue;
        }
        final identity = '${link.id}:event:${occurrence.id}';
        if (!seen.add(identity)) {
          continue;
        }
        result.add(
          IndicatorCommitment(
            linkId: link.id,
            indicatorKey: indicatorKey,
            entityType: type,
            entityId: occurrence.eventId,
            occurrenceId: occurrence.id,
            label: occurrence.displayTitle,
            date: occurrence.displayDate,
            startMinute: occurrence.startDisplay == null
                ? null
                : occurrence.startDisplay!.hour * 60 +
                      occurrence.startDisplay!.minute,
            endMinute: occurrence.endDisplay == null
                ? null
                : occurrence.endDisplay!.hour * 60 +
                      occurrence.endDisplay!.minute,
            colorArgb: occurrence.activityTypeColorValue ?? 0xFFE91E63,
            isRecurring: occurrence.isRecurring,
            statusLabel: calendarEventStatusLabel(occurrence.status),
            isBackup: occurrence.isBackupAppointment,
            activityTypeId: occurrence.activityTypeId,
          ),
        );
      }
    }
    result.sort((left, right) {
      final leftDate = left.date;
      final rightDate = right.date;
      if (leftDate == null && rightDate != null) {
        return -1;
      }
      if (leftDate != null && rightDate == null) {
        return 1;
      }
      final dateCompare = leftDate?.compareTo(rightDate!) ?? 0;
      if (dateCompare != 0) {
        return dateCompare;
      }
      return left.label.compareTo(right.label);
    });
    return result;
  }

  List<PlannerDate> _commitmentEventDates(
    CalendarEventDraft draft,
    IndicatorGoalPeriod period,
  ) {
    if (!draft.recurrence.isRecurring) {
      return <PlannerDate>[draft.startDate];
    }
    final dates = <PlannerDate>{draft.startDate};
    for (
      var offset = 0;
      offset <=
          period.end.asLocalDate.difference(period.start.asLocalDate).inDays;
      offset += 1
    ) {
      final candidate = period.start.addDays(offset);
      if (draft.recurrence.occurrenceIndexOn(
            startDate: draft.startDate,
            targetDate: candidate,
          ) !=
          null) {
        dates.add(candidate);
      }
    }
    return dates.toList(growable: false);
  }

  bool _isRecurringTask(String rawFrequency) {
    final frequency = PlannerTaskRecurrence.values
        .where((value) => value.name == rawFrequency)
        .firstOrNull;
    return frequency != null && frequency != PlannerTaskRecurrence.none;
  }

  String _taskStatusLabel(String rawStatus) {
    return switch (rawStatus) {
      'completed' => 'Completed',
      'skipped' => 'Skipped',
      'cancelled' => 'Cancelled',
      _ => 'Incomplete',
    };
  }

  Future<IndicatorAmount> _readActual({
    required String profileId,
    required LifeIndicatorDefinitionRow definition,
    required IndicatorPeriod period,
  }) async {
    final rows =
        await (database.select(database.activityLedgerEntries)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.indicatorKey.equals(definition.indicatorKey) &
                  table.activityDate.isBiggerOrEqualValue(
                    period.start.iso8601,
                  ) &
                  table.activityDate.isSmallerOrEqualValue(period.end.iso8601),
            ))
            .get();
    final scale = IndicatorUnitPolicy.allowedScale(definition.unit);
    var total = 0;
    for (final row in rows) {
      if (row.unit != definition.unit) {
        throw StateError('Ledger unit mismatch');
      }
      total += _rescale(row.valueScaled, row.valueScale, scale);
    }
    return IndicatorAmount(
      scaledValue: total,
      scale: scale,
      unit: definition.unit,
    );
  }

  Future<LifeIndicatorDefinitionRow> _definition(
    String profileId,
    String indicatorKey,
  ) async {
    final definition =
        await (database.select(database.lifeIndicatorDefinitions)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.indicatorKey.equals(indicatorKey),
              )
              ..limit(1))
            .getSingleOrNull();
    if (definition == null) {
      throw StateError('Life Indicator not found');
    }
    return definition;
  }

  Future<IndicatorGoalSnapshot> _readGoalSnapshot({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriod period,
    required PlannerDate today,
    required LifeIndicatorDefinitionRow definition,
  }) async {
    final actual = await _readActual(
      profileId: profileId,
      definition: definition,
      period: period.indicatorPeriod,
    );
    final target = _mapGoalTarget(
      await _latestGoal(
        profileId: profileId,
        indicatorKey: indicatorKey,
        period: period,
      ),
    );
    return IndicatorGoalSnapshot(
      indicatorKey: indicatorKey,
      period: period,
      actual: actual,
      target: target,
    );
  }

  Future<IndicatorGoalRevisionRow?> _latestGoal({
    required String profileId,
    required String indicatorKey,
    required IndicatorGoalPeriod period,
  }) async {
    final rows =
        await (database.select(database.indicatorGoalRevisions)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.indicatorKey.equals(indicatorKey) &
                    table.periodType.equals(period.type.name) &
                    table.periodStartDate.equals(period.start.iso8601),
              )
              ..orderBy(<OrderingTerm Function(IndicatorGoalRevisions)>[
                (table) => OrderingTerm.desc(table.createdAtUtc),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    final supersededIds = rows
        .map((row) => row.supersedesRevisionId)
        .whereType<String>()
        .toSet();
    return rows.where((row) => !supersededIds.contains(row.id)).firstOrNull;
  }

  IndicatorTarget _mapGoalTarget(IndicatorGoalRevisionRow? row) {
    if (row == null || row.state == 'notSet' || row.valueScaled == null) {
      return const IndicatorTarget.notSet();
    }
    return IndicatorTarget.explicit(
      IndicatorAmount(
        scaledValue: row.valueScaled!,
        scale: row.valueScale,
        unit: row.unit,
      ),
    );
  }

  Future<Map<String, IndicatorGoalRevisionRow>> _latestTargets(
    String profileId,
    PlannerDate start,
  ) async {
    final rows =
        await (database.select(database.indicatorGoalRevisions)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.periodType.equals(
                      IndicatorGoalPeriodType.weekly.name,
                    ) &
                    table.periodStartDate.equals(start.iso8601),
              )
              ..orderBy(<OrderingTerm Function(IndicatorGoalRevisions)>[
                (table) => OrderingTerm.desc(table.createdAtUtc),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    final supersededIds = rows
        .map((row) => row.supersedesRevisionId)
        .whereType<String>()
        .toSet();
    final latest = <String, IndicatorGoalRevisionRow>{};
    for (final row in rows) {
      if (!supersededIds.contains(row.id)) {
        latest.putIfAbsent(row.indicatorKey, () => row);
      }
    }
    return latest;
  }

  IndicatorTarget _mapTarget(IndicatorGoalRevisionRow? row) {
    if (row == null || row.state == 'notSet' || row.valueScaled == null) {
      return const IndicatorTarget.notSet();
    }
    return IndicatorTarget.explicit(
      IndicatorAmount(
        scaledValue: row.valueScaled!,
        scale: row.valueScale,
        unit: row.unit,
      ),
    );
  }

  Future<_ScheduledRead> _scheduledSources({
    required String profileId,
    required IndicatorPeriod period,
    required PlannerDate today,
  }) async {
    final result = <String, List<ScheduledIndicatorSource>>{};
    final links =
        await (database.select(database.taskEventLinks)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.status.equals(TaskEventLinkStatus.active.name),
            ))
            .get();
    final taskRows = await (database.select(
      database.plannerTasks,
    )..where((table) => table.profileId.equals(profileId))).get();
    var overdueTasks = 0;
    for (final row in taskRows) {
      final due = row.dueDate == null ? null : PlannerDate.parse(row.dueDate!);
      if (row.status == PlannerTaskStatus.incomplete.name &&
          due != null &&
          due.compareTo(today) < 0) {
        overdueTasks += 1;
      }
      final rule = ScheduledPotentialRule.tryParse(row.contributionRuleKey);
      if (row.status != PlannerTaskStatus.incomplete.name ||
          due == null ||
          due.compareTo(today) < 0 ||
          !period.contains(due) ||
          rule == null ||
          links.any(
            (link) =>
                link.taskId == row.id &&
                link.canonicalSource == TaskEventCanonicalSource.event.name,
          )) {
        continue;
      }
      result
          .putIfAbsent(rule.indicatorKey, () => [])
          .add(
            ScheduledIndicatorSource(
              sourceType: 'task',
              sourceId: row.id,
              label: row.title,
              date: due,
              value: rule.value,
              explanation: 'Explicit Task planning rule',
            ),
          );
    }

    var awaitingReports = 0;
    final eventRows = await (database.select(
      database.calendarEvents,
    )..where((table) => table.profileId.equals(profileId))).get();
    for (final row in eventRows) {
      final recurrence = CalendarRecurrenceRule(
        frequency: CalendarRecurrenceFrequency.values.byName(
          row.recurrenceFrequency,
        ),
        endMode: CalendarRecurrenceEndMode.values.byName(row.recurrenceEndMode),
        endDate: row.recurrenceEndDate == null
            ? null
            : PlannerDate.parse(row.recurrenceEndDate!),
        occurrenceCount: row.recurrenceCount,
      );
      final start = PlannerDate.parse(row.startDate);
      for (
        var date = period.start;
        date.compareTo(period.end) <= 0;
        date = date.addDays(1)
      ) {
        if (recurrence.occurrenceIndexOn(startDate: start, targetDate: date) ==
            null) {
          continue;
        }
        final occurrence = await calendarEvents.readOccurrence(
          profileId: profileId,
          eventId: row.id,
          originalDate: date,
        );
        if (occurrence == null) {
          continue;
        }
        if (occurrence.isAwaitingReport(
          nowUtc: clock.nowUtc(),
          displayToday: today,
        )) {
          awaitingReports += 1;
        }
        final rule = ScheduledPotentialRule.tryParse(
          occurrence.contributionRuleKey,
        );
        final excludedByCanonicalTask = links.any(
          (link) =>
              link.eventId == row.id &&
              link.canonicalSource == TaskEventCanonicalSource.task.name &&
              (link.scope == TaskEventLinkScope.series.name ||
                  link.occurrenceId == occurrence.id),
        );
        if (occurrence.status != CalendarEventStatus.scheduled ||
            occurrence.displayDate.compareTo(today) < 0 ||
            !period.contains(occurrence.displayDate) ||
            (occurrence.isBackupAppointment &&
                occurrence.backupForEventId != null) ||
            occurrence.isAwaitingReport(
              nowUtc: clock.nowUtc(),
              displayToday: today,
            ) ||
            rule == null ||
            excludedByCanonicalTask) {
          continue;
        }
        result
            .putIfAbsent(rule.indicatorKey, () => [])
            .add(
              ScheduledIndicatorSource(
                sourceType: 'event',
                sourceId: occurrence.id,
                label: occurrence.title,
                date: occurrence.displayDate,
                value: rule.value,
                explanation: 'Explicit Calendar Event planning rule',
              ),
            );
      }
    }
    return _ScheduledRead(
      sourcesByIndicator: result,
      overdueTaskCount: overdueTasks,
      awaitingReportCount: awaitingReports,
    );
  }

  Future<PlannerDate?> _readNextTempleVisit({
    required String profileId,
    required PlannerDate today,
  }) async {
    final rows =
        await (database.select(database.calendarEvents)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.activityTypeId.equals(SystemEventTypeIds.templeVisit),
            ))
            .get();
    final horizon = today.addDays(366);
    PlannerDate? earliest;
    for (final row in rows) {
      final start = PlannerDate.parse(row.startDate);
      final recurrence = CalendarRecurrenceRule(
        frequency: CalendarRecurrenceFrequency.values.byName(
          row.recurrenceFrequency,
        ),
        endMode: CalendarRecurrenceEndMode.values.byName(row.recurrenceEndMode),
        endDate: row.recurrenceEndDate == null
            ? null
            : PlannerDate.parse(row.recurrenceEndDate!),
        occurrenceCount: row.recurrenceCount,
      );
      final firstDate = recurrence.isRecurring
          ? (start.compareTo(today) > 0 ? start : today)
          : start;
      if (firstDate.compareTo(today) < 0 || firstDate.compareTo(horizon) > 0) {
        continue;
      }
      if (recurrence.isRecurring) {
        for (
          var date = firstDate;
          date.compareTo(horizon) <= 0;
          date = date.addDays(1)
        ) {
          if (recurrence.occurrenceIndexOn(
                startDate: start,
                targetDate: date,
              ) ==
              null) {
            continue;
          }
          final occurrence = await calendarEvents.readOccurrence(
            profileId: profileId,
            eventId: row.id,
            originalDate: date,
          );
          if (occurrence == null ||
              occurrence.status != CalendarEventStatus.scheduled ||
              occurrence.replacementEventId != null ||
              occurrence.displayDate.compareTo(today) < 0 ||
              occurrence.displayDate.compareTo(horizon) > 0) {
            continue;
          }
          final currentEarliest = earliest;
          if (currentEarliest == null ||
              occurrence.displayDate.compareTo(currentEarliest) < 0) {
            earliest = occurrence.displayDate;
          }
        }
        continue;
      }
      final occurrence = await calendarEvents.readOccurrence(
        profileId: profileId,
        eventId: row.id,
        originalDate: firstDate,
      );
      final currentEarliest = earliest;
      if (occurrence != null &&
          occurrence.status == CalendarEventStatus.scheduled &&
          occurrence.replacementEventId == null &&
          occurrence.displayDate.compareTo(today) >= 0 &&
          occurrence.displayDate.compareTo(horizon) <= 0 &&
          (currentEarliest == null ||
              occurrence.displayDate.compareTo(currentEarliest) < 0)) {
        earliest = occurrence.displayDate;
      }
    }
    return earliest;
  }

  Future<Set<String>> _staleIndicatorKeys(String profileId) async {
    final rows = await (database.select(
      database.activityLedgerEntries,
    )..where((table) => table.profileId.equals(profileId))).get();
    final ids = rows.map((row) => row.id).toSet();
    return <String>{
      for (final row in rows)
        if ((row.entryType == ActivityLedgerEntryType.reversal.name &&
                (row.reversalOfEntryId == null ||
                    !ids.contains(row.reversalOfEntryId))) ||
            (row.entryType != ActivityLedgerEntryType.reversal.name &&
                row.valueScaled <= 0))
          row.indicatorKey,
    };
  }

  IndicatorAmount _sumSources(
    List<ScheduledIndicatorSource> sources,
    String unit,
  ) {
    final scale = IndicatorUnitPolicy.allowedScale(unit);
    var total = 0;
    for (final source in sources) {
      if (source.value.unit != unit) {
        throw StateError('Scheduled source unit mismatch');
      }
      total += _rescale(source.value.scaledValue, source.value.scale, scale);
    }
    return IndicatorAmount(scaledValue: total, scale: scale, unit: unit);
  }

  int _rescale(int value, int from, int to) {
    if (from == to) {
      return value;
    }
    if (from < to) {
      var multiplier = 1;
      for (var i = from; i < to; i += 1) {
        multiplier *= 10;
      }
      return value * multiplier;
    }
    var divisor = 1;
    for (var i = to; i < from; i += 1) {
      divisor *= 10;
    }
    if (value % divisor != 0) {
      throw StateError('Value precision is not compatible');
    }
    return value ~/ divisor;
  }
}

final class _ScheduledRead {
  const _ScheduledRead({
    required this.sourcesByIndicator,
    required this.overdueTaskCount,
    required this.awaitingReportCount,
  });

  final Map<String, List<ScheduledIndicatorSource>> sourcesByIndicator;
  final int overdueTaskCount;
  final int awaitingReportCount;
}
