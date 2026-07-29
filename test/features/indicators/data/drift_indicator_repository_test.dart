import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);
  final period = IndicatorPeriod(start: monday, end: monday.addDays(6));

  test('AC-B-001..010,016..020: factual current-week projections remain '
      'separate, explainable, and local', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final reporting = DriftOutcomeReportingRepository(
      database: database,
      clock: clock,
    );
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      reportSource: reporting,
    );
    final repository = DriftIndicatorRepository(
      database: database,
      clock: clock,
      calendarEvents: calendar,
    );
    await reporting.submit(
      profileId: profile.id,
      draft: OutcomeReportDraft(
        id: '71000000-0000-4000-8000-000000000001',
        source: const OutcomeReportSource(
          type: OutcomeSourceType.manual,
          sourceId: '71000000-0000-4000-8000-000000000002',
          label: 'Confirmed application',
          activityDate: monday,
        ),
        activityDate: monday,
        outcome: OutcomeKind.completedHappened,
        contributions: const <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'confirmed-submission',
            indicatorKey: 'job_applications',
            value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
          ),
        ],
      ),
      operationId: '71000000-0000-4000-8000-000000000003',
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000004',
        title: 'Explicit application session',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(1),
        requiresReport: true,
        contributionRuleKey: const ScheduledPotentialRule(
          indicatorKey: 'job_applications',
          value: IndicatorAmount(scaledValue: 2, scale: 0, unit: 'count'),
        ).encode(),
      ),
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000007',
        title: 'Job Applications title only',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(1),
        requiresReport: true,
      ),
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000008',
        title: 'Cancelled qualified session',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(2),
        requiresReport: true,
        contributionRuleKey: const ScheduledPotentialRule(
          indicatorKey: 'job_applications',
          value: IndicatorAmount(scaledValue: 5, scale: 0, unit: 'count'),
        ).encode(),
      ),
    );
    await calendar.cancelEvent(
      profileId: profile.id,
      eventId: '71000000-0000-4000-8000-000000000008',
      originalDate: monday.addDays(2),
      scope: CalendarEventEditScope.occurrence,
      operationId: '71000000-0000-4000-8000-000000000009',
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000010',
        title: 'Original qualified session',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(3),
        requiresReport: true,
        contributionRuleKey: const ScheduledPotentialRule(
          indicatorKey: 'job_applications',
          value: IndicatorAmount(scaledValue: 3, scale: 0, unit: 'count'),
        ).encode(),
      ),
    );
    await calendar.rescheduleEvent(
      profileId: profile.id,
      eventId: '71000000-0000-4000-8000-000000000010',
      originalDate: monday.addDays(3),
      scope: CalendarEventEditScope.occurrence,
      replacement: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000011',
        title: 'Replacement qualified session',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(4),
        requiresReport: true,
        contributionRuleKey: const ScheduledPotentialRule(
          indicatorKey: 'job_applications',
          value: IndicatorAmount(scaledValue: 3, scale: 0, unit: 'count'),
        ).encode(),
      ),
      operationId: '71000000-0000-4000-8000-000000000012',
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000013',
        title: 'Primary paired session',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(5),
        requiresReport: true,
        contributionRuleKey: const ScheduledPotentialRule(
          indicatorKey: 'job_applications',
          value: IndicatorAmount(scaledValue: 4, scale: 0, unit: 'count'),
        ).encode(),
      ),
    );
    await calendar.saveEvent(
      profileId: profile.id,
      draft: CalendarEventDraft(
        id: '71000000-0000-4000-8000-000000000014',
        title: 'Backup paired session',
        timing: CalendarEventTiming.allDay,
        startDate: monday.addDays(5),
        requiresReport: true,
        contributionRuleKey: const ScheduledPotentialRule(
          indicatorKey: 'job_applications',
          value: IndicatorAmount(scaledValue: 4, scale: 0, unit: 'count'),
        ).encode(),
        isBackupAppointment: true,
        backupForEventId: '71000000-0000-4000-8000-000000000013',
        backupRelationshipProvenance: 'user-classified',
      ),
    );

    final first = await repository.readHome(
      profileId: profile.id,
      period: period,
      today: monday,
    );
    expect(first.indicators, hasLength(6));
    expect(first.indicators.map((item) => item.key), <String>[
      'job_applications',
      'scripture_study',
      'exercise',
      'meaningful_connections',
      'budget_review',
      'temple_visit',
    ]);
    final jobs = first.indicators.first;
    expect(jobs.actual.scaledValue, 1);
    expect(jobs.target.isSet, isFalse);
    expect(jobs.scheduledPotential.scaledValue, 9);
    expect(
      jobs.scheduledSources.map((source) => source.label),
      containsAll(<String>[
        'Explicit application session',
        'Replacement qualified session',
        'Primary paired session',
      ]),
    );
    expect(
      jobs.scheduledSources.map((source) => source.label),
      isNot(
        contains(
          anyOf('Job Applications title only', 'Cancelled qualified session'),
        ),
      ),
    );
    expect(
      jobs.scheduledSources.map((source) => source.label),
      isNot(contains('Backup paired session')),
      reason: 'A linked backup must not duplicate Scheduled Potential.',
    );

    await repository.saveTarget(
      profileId: profile.id,
      draft: IndicatorTargetRevisionDraft(
        id: '71000000-0000-4000-8000-000000000005',
        operationId: '71000000-0000-4000-8000-000000000006',
        indicatorKey: 'job_applications',
        period: period,
        value: const IndicatorAmount(scaledValue: 0, scale: 0, unit: 'count'),
      ),
    );
    final withZero = await repository.readHome(
      profileId: profile.id,
      period: period,
      today: monday,
    );
    expect(withZero.indicators.first.target.isExplicitZero, isTrue);
    expect(withZero.indicators.first.actual.scaledValue, 1);

    await repository.saveTarget(
      profileId: profile.id,
      draft: IndicatorTargetRevisionDraft(
        id: '71000000-0000-4000-8000-000000000000',
        operationId: '71000000-0000-4000-8000-000000000015',
        indicatorKey: 'job_applications',
        period: period,
        value: const IndicatorAmount(scaledValue: 3, scale: 0, unit: 'count'),
      ),
    );
    final withRevisedTarget = await repository.readHome(
      profileId: profile.id,
      period: period,
      today: monday,
    );
    expect(withRevisedTarget.indicators.first.target.display, '3');
    final targetHistory = await repository.readTargetHistory(
      profileId: profile.id,
      indicatorKey: 'job_applications',
      periodStart: monday,
    );
    expect(targetHistory, hasLength(2));
    expect(targetHistory.first.target.display, '3');
    expect(targetHistory.last.target.isExplicitZero, isTrue);

    await reporting.submit(
      profileId: profile.id,
      draft: OutcomeReportDraft(
        id: '71000000-0000-4000-8000-000000000016',
        source: const OutcomeReportSource(
          type: OutcomeSourceType.manual,
          sourceId: '71000000-0000-4000-8000-000000000002',
          label: 'Confirmed application',
          activityDate: monday,
        ),
        activityDate: monday,
        outcome: OutcomeKind.completedHappened,
        correctsReportId: '71000000-0000-4000-8000-000000000001',
        correctionReason: 'Corrected the confirmed application count.',
        contributions: const <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'confirmed-submission',
            indicatorKey: 'job_applications',
            value: IndicatorValue(scaledValue: 2, scale: 0, unit: 'count'),
          ),
        ],
      ),
      operationId: '71000000-0000-4000-8000-000000000017',
    );
    final afterCorrection = await repository.readHome(
      profileId: profile.id,
      period: period,
      today: monday,
    );
    expect(afterCorrection.indicators.first.actual.scaledValue, 2);
    final detail = await repository.readDetail(
      profileId: profile.id,
      indicatorKey: 'job_applications',
      period: period,
      today: monday,
    );
    expect(detail!.contributionHistory, hasLength(3));
    expect(
      detail.contributionHistory.map((item) => item.sourceLabel),
      everyElement('Confirmed application'),
    );
    expect(
      detail.contributionHistory.where((item) => item.isReversal),
      hasLength(1),
    );
  });

  test(
    'AC-B-011..012: one broken projection is isolated and labeled',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
        reportSource: reporting,
      );
      final repository = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      await reporting.submit(
        profileId: profile.id,
        draft: OutcomeReportDraft(
          id: '72000000-0000-4000-8000-000000000001',
          source: const OutcomeReportSource(
            type: OutcomeSourceType.manual,
            sourceId: '72000000-0000-4000-8000-000000000002',
            label: 'Fixture',
            activityDate: monday,
          ),
          activityDate: monday,
          outcome: OutcomeKind.completedHappened,
          contributions: const <ContributionDraft>[
            ContributionDraft(
              ruleKey: 'fixture',
              indicatorKey: 'exercise',
              value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
            ),
          ],
        ),
        operationId: '72000000-0000-4000-8000-000000000003',
      );
      await database
          .update(database.activityLedgerEntries)
          .write(
            const ActivityLedgerEntriesCompanion(valueScaled: Value<int>(0)),
          );
      final staleSnapshot = await repository.readHome(
        profileId: profile.id,
        period: period,
        today: monday,
      );
      expect(
        staleSnapshot.indicators
            .firstWhere((item) => item.key == 'exercise')
            .projectionState,
        IndicatorProjectionState.stale,
      );

      await database
          .update(database.activityLedgerEntries)
          .write(
            const ActivityLedgerEntriesCompanion(unit: Value<String>('hours')),
          );
      final snapshot = await repository.readHome(
        profileId: profile.id,
        period: period,
        today: monday,
      );
      expect(
        snapshot.indicators
            .firstWhere((item) => item.key == 'exercise')
            .projectionState,
        IndicatorProjectionState.failed,
      );
      expect(
        snapshot.indicators
            .firstWhere((item) => item.key == 'job_applications')
            .projectionState,
        IndicatorProjectionState.current,
      );
      expect(snapshot.hasPartialFailure, isTrue);
    },
  );
}
