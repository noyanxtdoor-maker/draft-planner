import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/indicators/application/indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
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
    final scheduled = await _scheduledSources(
      profileId: profileId,
      period: period,
      today: today,
    );
    final staleKeys = await _staleIndicatorKeys(profileId);
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
            sourceLabel: labels[row.sourceReportId] ?? 'Activity Report',
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
    if (!Uuid.isValidUUID(fromString: draft.id) ||
        !Uuid.isValidUUID(fromString: draft.operationId)) {
      throw StateError('Target revisions require stable UUID identities');
    }
    await database.transaction(() async {
      final priorOperation =
          await (database.select(database.weeklyIndicatorTargetRevisions)
                ..where((table) => table.operationId.equals(draft.operationId))
                ..limit(1))
              .getSingleOrNull();
      if (priorOperation != null) {
        return;
      }
      final plan =
          await (database.select(database.weeklyPlans)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.periodStartDate.equals(draft.period.start.iso8601),
                )
                ..limit(1))
              .getSingleOrNull();
      if (plan != null &&
          (plan.state == 'reviewed' || plan.state == 'historical')) {
        throw StateError(
          'Reviewed and historical Weekly Plan targets are read-only',
        );
      }
      final definition =
          await (database.select(database.lifeIndicatorDefinitions)
                ..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.indicatorKey.equals(draft.indicatorKey),
                )
                ..limit(1))
              .getSingleOrNull();
      if (definition == null) {
        throw StateError('Life Indicator not found');
      }
      final value = draft.value;
      if (value != null) {
        if (value.scaledValue < 0 ||
            value.unit != definition.unit ||
            value.scale != IndicatorUnitPolicy.allowedScale(definition.unit)) {
          throw StateError('Target value does not match the indicator unit');
        }
      }
      final prior = await _latestTarget(
        profileId,
        draft.indicatorKey,
        draft.period.start,
      );
      await database
          .into(database.weeklyIndicatorTargetRevisions)
          .insert(
            WeeklyIndicatorTargetRevisionsCompanion.insert(
              id: draft.id,
              profileId: profileId,
              indicatorKey: draft.indicatorKey,
              periodStartDate: draft.period.start.iso8601,
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
  Future<List<IndicatorTargetRevision>> readTargetHistory({
    required String profileId,
    required String indicatorKey,
    required PlannerDate periodStart,
  }) async {
    final rows =
        await (database.select(database.weeklyIndicatorTargetRevisions)..where(
              (table) =>
                  table.profileId.equals(profileId) &
                  table.indicatorKey.equals(indicatorKey) &
                  table.periodStartDate.equals(periodStart.iso8601),
            ))
            .get();
    final byId = <String, WeeklyIndicatorTargetRevisionRow>{
      for (final row in rows) row.id: row,
    };
    final superseded = rows
        .map((row) => row.supersedesRevisionId)
        .whereType<String>()
        .toSet();
    WeeklyIndicatorTargetRevisionRow? current;
    for (final row in rows) {
      if (!superseded.contains(row.id)) {
        current = row;
        break;
      }
    }
    final ordered = <WeeklyIndicatorTargetRevisionRow>[];
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

  Future<Map<String, WeeklyIndicatorTargetRevisionRow>> _latestTargets(
    String profileId,
    PlannerDate start,
  ) async {
    final rows =
        await (database.select(database.weeklyIndicatorTargetRevisions)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.periodStartDate.equals(start.iso8601),
              )
              ..orderBy(<OrderingTerm Function(WeeklyIndicatorTargetRevisions)>[
                (table) => OrderingTerm.desc(table.createdAtUtc),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    final supersededIds = rows
        .map((row) => row.supersedesRevisionId)
        .whereType<String>()
        .toSet();
    final latest = <String, WeeklyIndicatorTargetRevisionRow>{};
    for (final row in rows) {
      if (!supersededIds.contains(row.id)) {
        latest.putIfAbsent(row.indicatorKey, () => row);
      }
    }
    return latest;
  }

  Future<WeeklyIndicatorTargetRevisionRow?> _latestTarget(
    String profileId,
    String indicatorKey,
    PlannerDate start,
  ) async {
    final rows =
        await (database.select(database.weeklyIndicatorTargetRevisions)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.indicatorKey.equals(indicatorKey) &
                    table.periodStartDate.equals(start.iso8601),
              )
              ..orderBy(<OrderingTerm Function(WeeklyIndicatorTargetRevisions)>[
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

  IndicatorTarget _mapTarget(WeeklyIndicatorTargetRevisionRow? row) {
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
