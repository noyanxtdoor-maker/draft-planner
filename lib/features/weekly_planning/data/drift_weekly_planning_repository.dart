import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/indicators/application/indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_repository.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

abstract interface class WeeklyPlanningWriteGuard {
  Future<void> beforeCommit();
}

final class AllowWeeklyPlanningWrites implements WeeklyPlanningWriteGuard {
  const AllowWeeklyPlanningWrites();

  @override
  Future<void> beforeCommit() async {}
}

final class DriftWeeklyPlanningRepository implements WeeklyPlanningRepository {
  const DriftWeeklyPlanningRepository({
    required this.database,
    required this.clock,
    required this.identifiers,
    required this.timeZones,
    required this.indicators,
    required this.calendarEvents,
    this.writeGuard = const AllowWeeklyPlanningWrites(),
  });

  final AppDatabase database;
  final AppClock clock;
  final IdentifierSource identifiers;
  final IanaCalendarEventTimeZones timeZones;
  final IndicatorRepository indicators;
  final CalendarEventRepository calendarEvents;
  final WeeklyPlanningWriteGuard writeGuard;

  @override
  Future<PlannerDate> todayForProfile(String profileId) async {
    final zone = await _profileTimeZone(profileId);
    return PlannerDate.fromDateTime(
      timeZones.utcToWall(value: clock.nowUtc(), timeZoneId: zone),
    );
  }

  @override
  Future<WeeklyPlan> openOrCreate({
    required String profileId,
    required PlannerDate date,
  }) async {
    final zone = await _profileTimeZone(profileId);
    final period = WeeklyPeriod.containing(date);
    final existing = await _rowForPeriod(profileId, period.start);
    if (existing != null) {
      return _mapPlan(existing);
    }
    final now = clock.nowUtc();
    final id = identifiers.nextUuid();
    await database.transaction(() async {
      await database
          .into(database.weeklyPlans)
          .insert(
            WeeklyPlansCompanion.insert(
              id: id,
              profileId: profileId,
              periodStartDate: period.start.iso8601,
              periodEndDate: period.end.iso8601,
              timeZoneId: zone,
              state: WeeklyPlanState.draft.name,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await writeGuard.beforeCommit();
    });
    return _mapPlan((await _rowForPeriod(profileId, period.start))!);
  }

  @override
  Future<WeeklyPlan?> readPlan({
    required String profileId,
    required String planId,
  }) async {
    final row = await _planRow(profileId, planId);
    return row == null ? null : _mapPlan(row);
  }

  @override
  Future<List<WeeklyPlan>> readHistory(String profileId) async {
    final rows =
        await (database.select(database.weeklyPlans)
              ..where((table) => table.profileId.equals(profileId))
              ..orderBy(<OrderingTerm Function(WeeklyPlans)>[
                (table) => OrderingTerm.desc(table.periodStartDate),
              ]))
            .get();
    final plans = <WeeklyPlan>[];
    for (final row in rows) {
      plans.add(await _mapPlan(row));
    }
    return plans;
  }

  @override
  Future<List<WeeklyPlanCommitment>> readTaskCandidates({
    required String profileId,
    required String planId,
  }) async {
    await _requireEditablePlan(profileId, planId);
    final existing = await _commitmentKeys(planId);
    final rows =
        await (database.select(database.plannerTasks)
              ..where(
                (table) =>
                    table.profileId.equals(profileId) &
                    table.status.equals(PlannerTaskStatus.incomplete.name),
              )
              ..orderBy(<OrderingTerm Function(PlannerTasks)>[
                (table) => OrderingTerm.asc(table.dueDate),
                (table) => OrderingTerm.asc(table.title),
              ]))
            .get();
    final candidates = <WeeklyPlanCommitment>[];
    for (final row in rows) {
      if (!existing.contains(_taskKey(row.id))) {
        candidates.add(await _taskCommitment(row, commitmentId: row.id));
      }
    }
    return candidates;
  }

  @override
  Future<List<WeeklyPlanCommitment>> readEventCandidates({
    required String profileId,
    required String planId,
  }) async {
    final plan = await _requireEditablePlan(profileId, planId);
    final existing = await _commitmentKeys(planId);
    final candidates = <WeeklyPlanCommitment>[];
    for (var offset = 0; offset < 7; offset += 1) {
      final day = plan.period.start.addDays(offset);
      final items = await calendarEvents.readDay(
        profileId: profileId,
        date: day,
      );
      for (final item in items) {
        final eventId = item.eventId ?? item.id;
        final occurrenceId = item.id;
        if (item.isChange ||
            existing.contains(_eventKey(eventId, occurrenceId))) {
          continue;
        }
        candidates.add(
          WeeklyPlanCommitment(
            id: occurrenceId,
            type: WeeklyCommitmentType.event,
            sourceId: eventId,
            occurrenceId: occurrenceId,
            label: item.title,
            requiresReport: item.requiresReport,
            reportResolved: item.hasOutcomeReport,
          ),
        );
      }
    }
    return candidates;
  }

  @override
  Future<WeeklyPlan> addCommitment({
    required String profileId,
    required String planId,
    required WeeklyCommitmentType type,
    required String sourceId,
    String? occurrenceId,
  }) async {
    await _requireEditablePlan(profileId, planId);
    final key = switch (type) {
      WeeklyCommitmentType.task => _taskKey(sourceId),
      WeeklyCommitmentType.event => _eventKey(
        sourceId,
        occurrenceId ??
            (throw const WeeklyPlanningValidationException(
              'An Event commitment requires a stable occurrence.',
            )),
      ),
    };
    await _requireSource(profileId, type, sourceId);
    final now = clock.nowUtc();
    await database.transaction(() async {
      await database
          .into(database.weeklyPlanCommitments)
          .insert(
            WeeklyPlanCommitmentsCompanion.insert(
              id: identifiers.nextUuid(),
              profileId: profileId,
              planId: planId,
              commitmentKey: key,
              sourceType: type.name,
              sourceId: sourceId,
              occurrenceId: Value<String?>(occurrenceId),
              addedAtUtc: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await (database.update(
        database.weeklyPlans,
      )..where((table) => table.id.equals(planId))).write(
        WeeklyPlansCompanion(
          state: const Value<String>('active'),
          updatedAtUtc: Value<DateTime>(now),
        ),
      );
      await writeGuard.beforeCommit();
    });
    return (await readPlan(profileId: profileId, planId: planId))!;
  }

  @override
  Future<WeeklyPlan> completeReview({
    required String profileId,
    required String planId,
    required String reviewId,
    required String operationId,
    required bool unresolvedReportsAcknowledged,
    String? privateReflection,
  }) async {
    final existingOperation =
        await (database.select(database.weeklyPlanReviews)
              ..where((table) => table.operationId.equals(operationId))
              ..limit(1))
            .getSingleOrNull();
    if (existingOperation != null) {
      if (existingOperation.profileId != profileId ||
          existingOperation.planId != planId) {
        throw const WeeklyPlanningValidationException(
          'That review operation belongs to a different Weekly Plan.',
        );
      }
      return (await readPlan(profileId: profileId, planId: planId))!;
    }
    final plan = await _requirePlan(profileId, planId);
    if (plan.review != null) {
      throw const WeeklyPlanningValidationException(
        'This Weekly Plan review is already complete.',
      );
    }
    final today = await todayForProfile(profileId);
    if (today.compareTo(plan.period.end) <= 0) {
      throw const WeeklyPlanningValidationException(
        'Weekly Review becomes available after Sunday ends.',
      );
    }
    if (plan.unresolvedReports.isNotEmpty && !unresolvedReportsAcknowledged) {
      throw const WeeklyPlanningValidationException(
        'Acknowledge unresolved reports before completing Weekly Review.',
      );
    }
    final normalizedReflection = _optional(privateReflection);
    final snapshot = await indicators.readHome(
      profileId: profileId,
      period: plan.period.indicatorPeriod,
      today: plan.period.end,
    );
    final now = clock.nowUtc();
    await database.transaction(() async {
      await database
          .into(database.weeklyPlanReviews)
          .insert(
            WeeklyPlanReviewsCompanion.insert(
              id: reviewId,
              profileId: profileId,
              planId: planId,
              operationId: operationId,
              privateReflection: Value<String?>(normalizedReflection),
              unresolvedReportsAcknowledged: unresolvedReportsAcknowledged,
              completedAtUtc: now,
            ),
          );
      for (final indicator in snapshot.indicators) {
        final target = indicator.target.value;
        await database
            .into(database.weeklyPlanReviewIndicatorSnapshots)
            .insert(
              WeeklyPlanReviewIndicatorSnapshotsCompanion.insert(
                id: identifiers.nextUuid(),
                profileId: profileId,
                reviewId: reviewId,
                indicatorKey: indicator.key,
                actualValueScaled: indicator.actual.scaledValue,
                actualValueScale: indicator.actual.scale,
                actualUnit: indicator.actual.unit,
                targetState: indicator.target.isSet ? 'set' : 'notSet',
                targetValueScaled: Value<int?>(target?.scaledValue),
                targetValueScale: target?.scale ?? 0,
                targetUnit: target?.unit ?? indicator.unit,
                scheduledValueScaled: indicator.scheduledPotential.scaledValue,
                scheduledValueScale: indicator.scheduledPotential.scale,
                scheduledUnit: indicator.scheduledPotential.unit,
              ),
            );
      }
      await (database.update(
        database.weeklyPlans,
      )..where((table) => table.id.equals(planId))).write(
        WeeklyPlansCompanion(
          state: const Value<String>('reviewed'),
          reviewCompletedAtUtc: Value<DateTime?>(now),
          updatedAtUtc: Value<DateTime>(now),
        ),
      );
      await writeGuard.beforeCommit();
    });
    return (await readPlan(profileId: profileId, planId: planId))!;
  }

  @override
  Future<WeeklyPlan> startNextWeek({
    required String profileId,
    required String fromPlanId,
    required String nextPlanId,
    required Map<String, TaskCarryoverDecision> taskDecisions,
  }) async {
    final from = await _requirePlan(profileId, fromPlanId);
    if (from.review == null) {
      throw const WeeklyPlanningValidationException(
        'Complete Weekly Review before starting the next week.',
      );
    }
    final nextPeriod = WeeklyPeriod(
      start: from.period.start.addDays(7),
      end: from.period.end.addDays(7),
    );
    final existing = await _rowForPeriod(profileId, nextPeriod.start);
    if (existing != null) {
      return _mapPlan(existing);
    }
    final incomplete = from.commitments
        .where((item) => item.isIncompleteTask)
        .toList(growable: false);
    final missing = incomplete
        .where((item) => !taskDecisions.containsKey(item.sourceId))
        .toList(growable: false);
    if (missing.isNotEmpty) {
      throw const WeeklyPlanningValidationException(
        'Choose Carry or Do not carry for every incomplete Task.',
      );
    }
    final now = clock.nowUtc();
    await database.transaction(() async {
      await database
          .into(database.weeklyPlans)
          .insert(
            WeeklyPlansCompanion.insert(
              id: nextPlanId,
              profileId: profileId,
              periodStartDate: nextPeriod.start.iso8601,
              periodEndDate: nextPeriod.end.iso8601,
              timeZoneId: from.timeZoneId,
              state: WeeklyPlanState.draft.name,
              createdAtUtc: now,
              updatedAtUtc: now,
            ),
          );
      for (final task in incomplete) {
        final decision = taskDecisions[task.sourceId]!;
        await database
            .into(database.weeklyPlanTaskCarryoverDecisions)
            .insert(
              WeeklyPlanTaskCarryoverDecisionsCompanion.insert(
                id: identifiers.nextUuid(),
                profileId: profileId,
                fromPlanId: fromPlanId,
                taskId: task.sourceId,
                decision: decision.name,
                toPlanId: decision == TaskCarryoverDecision.carry
                    ? Value<String?>(nextPlanId)
                    : const Value<String?>.absent(),
                operationId: 'carryover:$fromPlanId:${task.sourceId}',
                decidedAtUtc: now,
              ),
            );
        if (decision == TaskCarryoverDecision.carry) {
          await database
              .into(database.weeklyPlanCommitments)
              .insert(
                WeeklyPlanCommitmentsCompanion.insert(
                  id: identifiers.nextUuid(),
                  profileId: profileId,
                  planId: nextPlanId,
                  commitmentKey: _taskKey(task.sourceId),
                  sourceType: WeeklyCommitmentType.task.name,
                  sourceId: task.sourceId,
                  addedAtUtc: now,
                ),
              );
        }
      }
      await (database.update(
        database.weeklyPlans,
      )..where((table) => table.id.equals(fromPlanId))).write(
        WeeklyPlansCompanion(
          state: const Value<String>('historical'),
          updatedAtUtc: Value<DateTime>(now),
        ),
      );
      await writeGuard.beforeCommit();
    });
    return (await readPlan(profileId: profileId, planId: nextPlanId))!;
  }

  Future<String> _profileTimeZone(String profileId) async {
    final profile =
        await (database.select(database.localProfiles)
              ..where((table) => table.id.equals(profileId))
              ..limit(1))
            .getSingleOrNull();
    if (profile == null) {
      throw const WeeklyPlanningValidationException(
        'A Local Profile is required for Weekly Planning.',
      );
    }
    final stored = profile.timeZoneId;
    if (stored != null && timeZones.isValid(stored)) {
      return stored;
    }
    final resolved = timeZones.displayTimeZoneId;
    await (database.update(
      database.localProfiles,
    )..where((table) => table.id.equals(profileId))).write(
      LocalProfilesCompanion(
        timeZoneId: Value<String?>(resolved),
        updatedAtUtc: Value<DateTime>(clock.nowUtc()),
      ),
    );
    return resolved;
  }

  Future<WeeklyPlanRow?> _rowForPeriod(String profileId, PlannerDate start) {
    return (database.select(database.weeklyPlans)
          ..where(
            (table) =>
                table.profileId.equals(profileId) &
                table.periodStartDate.equals(start.iso8601),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WeeklyPlanRow?> _planRow(String profileId, String planId) {
    return (database.select(database.weeklyPlans)
          ..where(
            (table) =>
                table.profileId.equals(profileId) & table.id.equals(planId),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<WeeklyPlan> _requirePlan(String profileId, String planId) async {
    final row = await _planRow(profileId, planId);
    if (row == null) {
      throw const WeeklyPlanningValidationException(
        'Weekly Plan was not found for this Local Profile.',
      );
    }
    return _mapPlan(row);
  }

  Future<WeeklyPlan> _requireEditablePlan(
    String profileId,
    String planId,
  ) async {
    final plan = await _requirePlan(profileId, planId);
    final today = await todayForProfile(profileId);
    if (plan.isReadOnly ||
        plan.effectiveState(today) == WeeklyPlanState.reviewDue) {
      throw const WeeklyPlanningValidationException(
        'Review Due, reviewed, and historical Weekly Plans are read-only.',
      );
    }
    return plan;
  }

  Future<void> _requireSource(
    String profileId,
    WeeklyCommitmentType type,
    String sourceId,
  ) async {
    final exists = switch (type) {
      WeeklyCommitmentType.task =>
        await (database.select(database.plannerTasks)..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.id.equals(sourceId),
                ))
                .getSingleOrNull() !=
            null,
      WeeklyCommitmentType.event =>
        await (database.select(database.calendarEvents)..where(
                  (table) =>
                      table.profileId.equals(profileId) &
                      table.id.equals(sourceId),
                ))
                .getSingleOrNull() !=
            null,
    };
    if (!exists) {
      throw const WeeklyPlanningValidationException(
        'The selected commitment source no longer exists.',
      );
    }
  }

  Future<Set<String>> _commitmentKeys(String planId) async {
    final rows = await (database.select(
      database.weeklyPlanCommitments,
    )..where((table) => table.planId.equals(planId))).get();
    return rows.map((row) => row.commitmentKey).toSet();
  }

  Future<WeeklyPlan> _mapPlan(WeeklyPlanRow row) async {
    final period = WeeklyPeriod(
      start: PlannerDate.parse(row.periodStartDate),
      end: PlannerDate.parse(row.periodEndDate),
    );
    final commitmentRows =
        await (database.select(database.weeklyPlanCommitments)
              ..where((table) => table.planId.equals(row.id))
              ..orderBy(<OrderingTerm Function(WeeklyPlanCommitments)>[
                (table) => OrderingTerm.asc(table.addedAtUtc),
              ]))
            .get();
    final commitments = <WeeklyPlanCommitment>[];
    for (final commitment in commitmentRows) {
      if (commitment.sourceType == WeeklyCommitmentType.task.name) {
        final task =
            await (database.select(database.plannerTasks)
                  ..where((table) => table.id.equals(commitment.sourceId))
                  ..limit(1))
                .getSingleOrNull();
        if (task != null) {
          commitments.add(
            await _taskCommitment(task, commitmentId: commitment.id),
          );
        }
      } else {
        final event =
            await (database.select(database.calendarEvents)
                  ..where((table) => table.id.equals(commitment.sourceId))
                  ..limit(1))
                .getSingleOrNull();
        if (event != null) {
          commitments.add(
            WeeklyPlanCommitment(
              id: commitment.id,
              type: WeeklyCommitmentType.event,
              sourceId: event.id,
              occurrenceId: commitment.occurrenceId,
              label: event.title,
              requiresReport: event.requiresReport,
              reportResolved: await _hasSubmittedReport(
                type: WeeklyCommitmentType.event,
                sourceId: event.id,
                occurrenceId: commitment.occurrenceId,
              ),
            ),
          );
        }
      }
    }
    final indicatorSnapshot = await indicators.readHome(
      profileId: row.profileId,
      period: period.indicatorPeriod,
      today: await todayForProfile(row.profileId),
    );
    final currentIndicators = indicatorSnapshot.indicators
        .map(
          (item) => WeeklyIndicatorReview(
            indicatorKey: item.key,
            label: item.label,
            actual: item.actual,
            target: item.target,
            scheduled: item.scheduledPotential,
          ),
        )
        .toList(growable: false);
    final reviewRow =
        await (database.select(database.weeklyPlanReviews)
              ..where((table) => table.planId.equals(row.id))
              ..limit(1))
            .getSingleOrNull();
    WeeklyReview? review;
    if (reviewRow != null) {
      final snapshots = await (database.select(
        database.weeklyPlanReviewIndicatorSnapshots,
      )..where((table) => table.reviewId.equals(reviewRow.id))).get();
      final labels = <String, String>{
        for (final item in currentIndicators) item.indicatorKey: item.label,
      };
      review = WeeklyReview(
        id: reviewRow.id,
        completedAtUtc: reviewRow.completedAtUtc.toUtc(),
        unresolvedReportsAcknowledged: reviewRow.unresolvedReportsAcknowledged,
        privateReflection: reviewRow.privateReflection,
        indicators: snapshots
            .map(
              (item) => WeeklyIndicatorReview(
                indicatorKey: item.indicatorKey,
                label: labels[item.indicatorKey] ?? item.indicatorKey,
                actual: IndicatorAmount(
                  scaledValue: item.actualValueScaled,
                  scale: item.actualValueScale,
                  unit: item.actualUnit,
                ),
                target: item.targetState == 'set'
                    ? IndicatorTarget.explicit(
                        IndicatorAmount(
                          scaledValue: item.targetValueScaled!,
                          scale: item.targetValueScale,
                          unit: item.targetUnit,
                        ),
                      )
                    : const IndicatorTarget.notSet(),
                scheduled: IndicatorAmount(
                  scaledValue: item.scheduledValueScaled,
                  scale: item.scheduledValueScale,
                  unit: item.scheduledUnit,
                ),
              ),
            )
            .toList(growable: false),
      );
    }
    final changes = <PostReviewChange>[];
    if (review != null) {
      final rows =
          await (database.select(database.activityLedgerEntries)
                ..where(
                  (table) =>
                      table.profileId.equals(row.profileId) &
                      table.activityDate.isBiggerOrEqualValue(
                        period.start.iso8601,
                      ) &
                      table.activityDate.isSmallerOrEqualValue(
                        period.end.iso8601,
                      ) &
                      table.recordedAtUtc.isBiggerThanValue(
                        review!.completedAtUtc,
                      ),
                )
                ..orderBy(<OrderingTerm Function(ActivityLedgerEntries)>[
                  (table) => OrderingTerm.asc(table.recordedAtUtc),
                ]))
              .get();
      changes.addAll(
        rows.map(
          (entry) => PostReviewChange(
            indicatorKey: entry.indicatorKey,
            recordedAtUtc: entry.recordedAtUtc.toUtc(),
          ),
        ),
      );
    }
    return WeeklyPlan(
      id: row.id,
      profileId: row.profileId,
      period: period,
      timeZoneId: row.timeZoneId,
      storedState: WeeklyPlanState.values.byName(row.state),
      commitments: commitments,
      indicators: currentIndicators,
      review: review,
      postReviewChanges: changes,
      createdAtUtc: row.createdAtUtc.toUtc(),
      updatedAtUtc: row.updatedAtUtc.toUtc(),
    );
  }

  Future<WeeklyPlanCommitment> _taskCommitment(
    PlannerTaskRow row, {
    required String commitmentId,
  }) async {
    return WeeklyPlanCommitment(
      id: commitmentId,
      type: WeeklyCommitmentType.task,
      sourceId: row.id,
      label: row.title,
      requiresReport: row.requiresReport,
      reportResolved: await _hasSubmittedReport(
        type: WeeklyCommitmentType.task,
        sourceId: row.id,
      ),
      taskStatus: PlannerTaskStatus.values.byName(row.status),
    );
  }

  Future<bool> _hasSubmittedReport({
    required WeeklyCommitmentType type,
    required String sourceId,
    String? occurrenceId,
  }) async {
    final query = database.select(database.outcomeReports)
      ..where(
        (table) =>
            table.sourceType.equals(
              type == WeeklyCommitmentType.task
                  ? OutcomeSourceType.task.name
                  : OutcomeSourceType.event.name,
            ) &
            (type == WeeklyCommitmentType.task
                ? table.sourceId.equals(sourceId)
                : table.eventId.equals(sourceId)) &
            table.status.equals(OutcomeReportStatus.submitted.name),
      );
    if (type == WeeklyCommitmentType.event && occurrenceId != null) {
      query.where((table) => table.occurrenceId.equals(occurrenceId));
    }
    return (await query.get()).isNotEmpty;
  }

  String _taskKey(String taskId) => 'task:$taskId';

  String _eventKey(String eventId, String occurrenceId) =>
      'event:$eventId:$occurrenceId';

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
