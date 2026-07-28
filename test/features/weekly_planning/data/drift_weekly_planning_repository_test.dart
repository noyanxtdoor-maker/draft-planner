import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/data/drift_weekly_planning_repository.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  test('AC-I-001..020: offline lifecycle preserves identity, evidence, review, '
      'history, and explicit Task-only carryover', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final clock = _MutableClock(DateTime.utc(2026, 7, 27, 12));
    final timeZones = IanaCalendarEventTimeZones(
      displayTimeZoneId: 'Asia/Manila',
    );
    final reporting = DriftOutcomeReportingRepository(
      database: database,
      clock: clock,
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: timeZones,
      reportSource: reporting,
    );
    final indicators = DriftIndicatorRepository(
      database: database,
      clock: clock,
      calendarEvents: calendar,
    );
    final repository = DriftWeeklyPlanningRepository(
      database: database,
      clock: clock,
      identifiers: _Ids(),
      timeZones: timeZones,
      indicators: indicators,
      calendarEvents: calendar,
    );

    await database
        .into(database.plannerTasks)
        .insert(
          PlannerTasksCompanion.insert(
            id: 'task-1',
            profileId: profile.id,
            title: 'Prepare applications',
            dueDate: Value<String?>(monday.addDays(2).iso8601),
            requiresReport: const Value<bool>(true),
            createdAtUtc: clock.nowUtc(),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'event-1',
            profileId: profile.id,
            title: 'Application session',
            timing: 'allDay',
            startDate: monday.addDays(1).iso8601,
            requiresReport: const Value<bool>(true),
            contributionRuleKey: Value<String?>(
              const ScheduledPotentialRule(
                indicatorKey: 'job_applications',
                value: IndicatorAmount(scaledValue: 2, scale: 0, unit: 'count'),
              ).encode(),
            ),
            createdAtUtc: clock.nowUtc(),
            updatedAtUtc: clock.nowUtc(),
          ),
        );
    await indicators.saveTarget(
      profileId: profile.id,
      draft: IndicatorTargetRevisionDraft(
        id: '81000000-0000-4000-8000-000000000001',
        operationId: '81000000-0000-4000-8000-000000000002',
        indicatorKey: 'job_applications',
        period: IndicatorPeriod(start: monday, end: monday.addDays(6)),
        value: const IndicatorAmount(scaledValue: 0, scale: 0, unit: 'count'),
      ),
    );

    final created = await repository.openOrCreate(
      profileId: profile.id,
      date: monday.addDays(3),
    );
    final reopened = await repository.openOrCreate(
      profileId: profile.id,
      date: monday,
    );
    expect(reopened.id, created.id);
    expect(reopened.period.start, monday);
    expect(reopened.period.end, monday.addDays(6));
    expect(reopened.timeZoneId, 'Asia/Manila');
    expect(
      (await database.select(database.localProfiles).get()).single.timeZoneId,
      'Asia/Manila',
    );
    final jobs = reopened.indicators.firstWhere(
      (item) => item.indicatorKey == 'job_applications',
    );
    expect(jobs.actual.scaledValue, 0);
    expect(jobs.target.isExplicitZero, isTrue);
    expect(jobs.scheduled.scaledValue, 2);

    final tasks = await repository.readTaskCandidates(
      profileId: profile.id,
      planId: created.id,
    );
    final events = await repository.readEventCandidates(
      profileId: profile.id,
      planId: created.id,
    );
    expect(tasks.single.sourceId, 'task-1');
    expect(events.single.sourceId, 'event-1');
    await repository.addCommitment(
      profileId: profile.id,
      planId: created.id,
      type: WeeklyCommitmentType.task,
      sourceId: 'task-1',
    );
    await repository.addCommitment(
      profileId: profile.id,
      planId: created.id,
      type: WeeklyCommitmentType.event,
      sourceId: 'event-1',
      occurrenceId: events.single.occurrenceId,
    );
    final active = (await repository.readPlan(
      profileId: profile.id,
      planId: created.id,
    ))!;
    expect(active.storedState, WeeklyPlanState.active);
    expect(active.commitments, hasLength(2));
    expect(active.unresolvedReports, hasLength(2));

    clock.value = DateTime.utc(2026, 8, 3, 12);
    expect(
      active.effectiveState(await repository.todayForProfile(profile.id)),
      WeeklyPlanState.reviewDue,
    );
    await expectLater(
      repository.completeReview(
        profileId: profile.id,
        planId: created.id,
        reviewId: 'review-1',
        operationId: 'review-operation-1',
        unresolvedReportsAcknowledged: false,
      ),
      throwsA(isA<WeeklyPlanningValidationException>()),
    );
    final reviewed = await repository.completeReview(
      profileId: profile.id,
      planId: created.id,
      reviewId: 'review-1',
      operationId: 'review-operation-1',
      unresolvedReportsAcknowledged: true,
      privateReflection: '  Local private note.  ',
    );
    expect(reviewed.storedState, WeeklyPlanState.reviewed);
    expect(reviewed.review!.indicators, hasLength(6));
    expect(reviewed.review!.privateReflection, 'Local private note.');
    await expectLater(
      indicators.saveTarget(
        profileId: profile.id,
        draft: IndicatorTargetRevisionDraft(
          id: '81000000-0000-4000-8000-000000000006',
          operationId: '81000000-0000-4000-8000-000000000007',
          indicatorKey: 'job_applications',
          period: IndicatorPeriod(start: monday, end: monday.addDays(6)),
          value: const IndicatorAmount(scaledValue: 4, scale: 0, unit: 'count'),
        ),
      ),
      throwsStateError,
    );
    final retry = await repository.completeReview(
      profileId: profile.id,
      planId: created.id,
      reviewId: 'unused-review',
      operationId: 'review-operation-1',
      unresolvedReportsAcknowledged: true,
    );
    expect(retry.review!.id, 'review-1');

    clock.value = DateTime.utc(2026, 8, 3, 13);
    await reporting.submit(
      profileId: profile.id,
      draft: OutcomeReportDraft(
        id: '81000000-0000-4000-8000-000000000003',
        source: OutcomeReportSource(
          type: OutcomeSourceType.manual,
          sourceId: '81000000-0000-4000-8000-000000000004',
          label: 'Late factual report',
          activityDate: monday.addDays(4),
        ),
        activityDate: monday.addDays(4),
        outcome: OutcomeKind.completedHappened,
        contributions: const <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'late-confirmed',
            indicatorKey: 'job_applications',
            value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
          ),
        ],
      ),
      operationId: '81000000-0000-4000-8000-000000000005',
    );
    final changed = (await repository.readPlan(
      profileId: profile.id,
      planId: created.id,
    ))!;
    expect(changed.review!.indicators.first.actual.scaledValue, 0);
    expect(
      changed.indicators
          .firstWhere((item) => item.indicatorKey == 'job_applications')
          .actual
          .scaledValue,
      1,
    );
    expect(changed.postReviewChanges, hasLength(1));

    final next = await repository.startNextWeek(
      profileId: profile.id,
      fromPlanId: created.id,
      nextPlanId: 'next-plan-1',
      taskDecisions: const <String, TaskCarryoverDecision>{
        'task-1': TaskCarryoverDecision.carry,
      },
    );
    expect(next.period.start, monday.addDays(7));
    expect(next.timeZoneId, 'Asia/Manila');
    expect(next.commitments, hasLength(1));
    expect(next.commitments.single.type, WeeklyCommitmentType.task);
    expect(
      next.commitments.any((item) => item.type == WeeklyCommitmentType.event),
      isFalse,
    );
    final historical = (await repository.readPlan(
      profileId: profile.id,
      planId: created.id,
    ))!;
    expect(historical.storedState, WeeklyPlanState.historical);
    expect(await repository.readHistory(profile.id), hasLength(2));
  });

  test(
    'AC-I-003,020 / Q3: failed local commitment transaction is retry-safe',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final clock = _MutableClock(DateTime.utc(2026, 7, 27, 12));
      final timeZones = IanaCalendarEventTimeZones(
        displayTimeZoneId: 'Asia/Manila',
      );
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: timeZones,
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      final healthy = DriftWeeklyPlanningRepository(
        database: database,
        clock: clock,
        identifiers: _Ids(),
        timeZones: timeZones,
        indicators: indicators,
        calendarEvents: calendar,
      );
      final plan = await healthy.openOrCreate(
        profileId: profile.id,
        date: monday,
      );
      await database
          .into(database.plannerTasks)
          .insert(
            PlannerTasksCompanion.insert(
              id: 'rollback-task',
              profileId: profile.id,
              title: 'Rollback fixture',
              requiresReport: const Value<bool>(false),
              createdAtUtc: clock.nowUtc(),
              updatedAtUtc: clock.nowUtc(),
            ),
          );
      final failing = DriftWeeklyPlanningRepository(
        database: database,
        clock: clock,
        identifiers: _Ids(),
        timeZones: timeZones,
        indicators: indicators,
        calendarEvents: calendar,
        writeGuard: const _FailingGuard(),
      );
      await expectLater(
        failing.addCommitment(
          profileId: profile.id,
          planId: plan.id,
          type: WeeklyCommitmentType.task,
          sourceId: 'rollback-task',
        ),
        throwsStateError,
      );
      final unchanged = (await healthy.readPlan(
        profileId: profile.id,
        planId: plan.id,
      ))!;
      expect(unchanged.storedState, WeeklyPlanState.draft);
      expect(unchanged.commitments, isEmpty);
    },
  );
}

final class _MutableClock implements AppClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class _Ids implements IdentifierSource {
  int _value = 0;

  @override
  String nextUuid() {
    _value += 1;
    return 'weekly-id-$_value';
  }
}

final class _FailingGuard implements WeeklyPlanningWriteGuard {
  const _FailingGuard();

  @override
  Future<void> beforeCommit() async {
    throw StateError('Injected weekly planning write failure');
  }
}
