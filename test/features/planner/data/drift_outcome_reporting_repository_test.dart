import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

const _taskId = '11111111-1111-4111-8111-111111111111';
const _eventId = '22222222-2222-4222-8222-222222222222';
const _reportId = '33333333-3333-4333-8333-333333333333';
const _correctedReportId = '44444444-4444-4444-8444-444444444444';
const _manualReportId = '55555555-5555-4555-8555-555555555555';
const _operationId = '66666666-6666-4666-8666-666666666666';
const _correctionOperationId = '77777777-7777-4777-8777-777777777777';
const _manualOperationId = '88888888-8888-4888-8888-888888888888';
const _reasonGuardReportId = '99999999-9999-4999-8999-999999999999';
const _reasonGuardCorrectionId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _reasonGuardOperationId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _reasonGuardCorrectionOperationId =
    'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const _date = PlannerDate(year: 2026, month: 7, day: 28);

void main() {
  late AppDatabase database;
  late String profileId;
  late DriftOutcomeReportingRepository reports;
  late DriftPlannerRepository tasks;
  late DriftCalendarEventRepository events;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    reports = DriftOutcomeReportingRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 12)),
    );
    tasks = DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 12)),
      historicalEffectReader: reports,
    );
    events = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 12)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      reportSource: reports,
    );
  });

  tearDown(() => database.close());

  test('AC-G-001..005,008,009,013,015..019: Event occurrence Draft and '
      'submission stay factual, offline, and idempotent', () async {
    await events.saveEvent(
      profileId: profileId,
      draft: const CalendarEventDraft(
        id: _eventId,
        title: 'Explicit report source',
        timing: CalendarEventTiming.timed,
        startDate: _date,
        startMinute: 8 * 60,
        endMinute: 9 * 60,
        timeZoneId: 'Asia/Manila',
        requiresReport: true,
      ),
    );
    final source = await reports.readEventSource(
      profileId: profileId,
      eventId: _eventId,
      originalDate: _date,
    );
    expect(source, isNotNull);

    final draft = OutcomeReportDraft(
      id: _reportId,
      source: source!,
      activityDate: _date,
      outcome: OutcomeKind.completedHappened,
      privateNotes: 'Private and non-contributory',
      contributions: const <ContributionDraft>[
        ContributionDraft(
          ruleKey: 'user-confirmed:exercise:count',
          indicatorKey: 'exercise',
          value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
        ),
      ],
    );
    final savedDraft = await reports.saveDraft(
      profileId: profileId,
      draft: draft,
    );
    final beforeSubmission = await events.readOccurrence(
      profileId: profileId,
      eventId: _eventId,
      originalDate: _date,
    );

    expect(savedDraft.status, OutcomeReportStatus.draft);
    expect(savedDraft.draftContributions, hasLength(1));
    expect(beforeSubmission!.status, CalendarEventStatus.scheduled);
    expect(
      beforeSubmission.isAwaitingReport(
        nowUtc: DateTime.utc(2026, 7, 28, 12),
        displayToday: _date,
      ),
      isTrue,
    );
    expect(
      (await reports.readActual(
        profileId: profileId,
        indicatorKey: 'exercise',
        startDate: _date,
        endDate: _date,
      )).value.scaledValue,
      0,
    );

    final submitted = await reports.submit(
      profileId: profileId,
      draft: draft,
      operationId: _operationId,
    );
    final retried = await reports.submit(
      profileId: profileId,
      draft: draft,
      operationId: _operationId,
    );
    final afterSubmission = await events.readOccurrence(
      profileId: profileId,
      eventId: _eventId,
      originalDate: _date,
    );

    expect(submitted.unchanged, isFalse);
    expect(retried.unchanged, isTrue);
    expect(afterSubmission!.status, CalendarEventStatus.completedHappened);
    expect(submitted.report.activityDate, _date);
    expect(submitted.report.submittedAtUtc, DateTime.utc(2026, 7, 28, 12));
    expect(submitted.report.privateNotes, 'Private and non-contributory');
    expect(await database.select(database.outcomeReports).get(), hasLength(1));
    expect(
      await database.select(database.activityLedgerEntries).get(),
      hasLength(1),
    );
  });

  test('AC-G-006,007,013,016,018 / AC-H-001..009,017,018,020: required '
      'Task completion and explicit contribution commit atomically', () async {
    await tasks.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: _taskId,
        title: 'Title is never a contribution classifier',
        dueDate: _date,
        requiresReport: true,
      ),
    );
    final source = await reports.readTaskSource(
      profileId: profileId,
      taskId: _taskId,
    );
    final draft = OutcomeReportDraft(
      id: _reportId,
      source: source!,
      activityDate: _date,
      outcome: OutcomeKind.completedHappened,
      contributions: const <ContributionDraft>[
        ContributionDraft(
          ruleKey: 'user-confirmed:job_applications:count',
          indicatorKey: 'job_applications',
          value: IndicatorValue(scaledValue: 2, scale: 0, unit: 'count'),
        ),
      ],
    );

    final result = await reports.submit(
      profileId: profileId,
      draft: draft,
      operationId: _operationId,
    );
    final task = await tasks.readTask(profileId: profileId, taskId: _taskId);
    final actual = await reports.readActual(
      profileId: profileId,
      indicatorKey: 'job_applications',
      startDate: _date,
      endDate: _date,
    );

    expect(task!.status, PlannerTaskStatus.completed);
    expect(result.entries.single.ruleKey, contains('job_applications'));
    expect(result.entries.single.indicatorKey, 'job_applications');
    expect(result.entries.single.value.scaledValue, 2);
    expect(result.entries.single.value.unit, 'count');
    expect(actual.value.scaledValue, 2);
    expect(actual.value.unit, 'count');
    expect(
      await tasks.changeTaskStatus(
        profileId: profileId,
        taskId: _taskId,
        target: PlannerTaskStatus.incomplete,
        operationId: _manualOperationId,
      ),
      TaskStatusChangeOutcome.correctionRequired,
    );
  });

  test('AC-G-010..012,014,016,020 / AC-H-010..016: correction preserves '
      'report and ledger history using reversal and replacement', () async {
    await tasks.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: _taskId,
        title: 'Correctable report',
        dueDate: _date,
        requiresReport: true,
      ),
    );
    final source = (await reports.readTaskSource(
      profileId: profileId,
      taskId: _taskId,
    ))!;
    await reports.submit(
      profileId: profileId,
      draft: OutcomeReportDraft(
        id: _reportId,
        source: source,
        activityDate: _date,
        outcome: OutcomeKind.completedHappened,
        contributions: const <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'user-confirmed:exercise:count',
            indicatorKey: 'exercise',
            value: IndicatorValue(scaledValue: 2, scale: 0, unit: 'count'),
          ),
        ],
      ),
      operationId: _operationId,
    );

    await expectLater(
      reports.submit(
        profileId: profileId,
        draft: OutcomeReportDraft(
          id: _correctedReportId,
          source: source,
          activityDate: _date,
          outcome: OutcomeKind.completedHappened,
          correctsReportId: _reportId,
          contributions: const <ContributionDraft>[
            ContributionDraft(
              ruleKey: 'user-confirmed:exercise:count',
              indicatorKey: 'exercise',
              value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
            ),
          ],
        ),
        operationId: _correctionOperationId,
      ),
      throwsA(isA<OutcomeReportValidationException>()),
    );

    final correction = await reports.submit(
      profileId: profileId,
      draft: OutcomeReportDraft(
        id: _correctedReportId,
        source: source,
        activityDate: _date,
        outcome: OutcomeKind.completedHappened,
        correctsReportId: _reportId,
        correctionReason: 'Duplicate quantity corrected',
        contributions: const <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'user-confirmed:exercise:count',
            indicatorKey: 'exercise',
            value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
          ),
        ],
      ),
      operationId: _correctionOperationId,
    );
    final history = await reports.readReportHistory(profileId);
    final allEntries = await reports.readLedgerHistory(
      profileId: profileId,
      effectiveOnly: false,
    );
    final effectiveEntries = await reports.readLedgerHistory(
      profileId: profileId,
    );
    final actual = await reports.readActual(
      profileId: profileId,
      indicatorKey: 'exercise',
      startDate: _date,
      endDate: _date,
    );

    expect(correction.report.correctionReason, isNotEmpty);
    expect(history, hasLength(2));
    expect(history.first.status, OutcomeReportStatus.submitted);
    expect(history.last.status, OutcomeReportStatus.superseded);
    expect(allEntries, hasLength(3));
    expect(
      allEntries.where(
        (entry) => entry.type == ActivityLedgerEntryType.reversal,
      ),
      hasLength(1),
    );
    expect(effectiveEntries, hasLength(1));
    expect(effectiveEntries.single.replacesEntryId, isNotNull);
    expect(actual.value.scaledValue, 1);
    expect((await reports.auditProjection(profileId)).isConsistent, isTrue);
  });

  test('OPD-2-005 / AC-G-014: adding the first contribution by correction '
      'requires a reason because Actual changes', () async {
    const source = OutcomeReportSource(
      type: OutcomeSourceType.manual,
      sourceId: _reasonGuardReportId,
      label: 'Reason guard fixture',
      activityDate: _date,
    );
    await reports.submit(
      profileId: profileId,
      draft: const OutcomeReportDraft(
        id: _reasonGuardReportId,
        source: source,
        activityDate: _date,
        outcome: OutcomeKind.completedHappened,
      ),
      operationId: _reasonGuardOperationId,
    );

    await expectLater(
      reports.submit(
        profileId: profileId,
        draft: const OutcomeReportDraft(
          id: _reasonGuardCorrectionId,
          source: source,
          activityDate: _date,
          outcome: OutcomeKind.completedHappened,
          correctsReportId: _reasonGuardReportId,
          contributions: <ContributionDraft>[
            ContributionDraft(
              ruleKey: 'user-selected:exercise',
              indicatorKey: 'exercise',
              value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
            ),
          ],
        ),
        operationId: _reasonGuardCorrectionOperationId,
      ),
      throwsA(
        isA<OutcomeReportValidationException>().having(
          (error) => error.message,
          'message',
          contains('changes Actual'),
        ),
      ),
    );
    expect(
      await database.select(database.activityLedgerEntries).get(),
      isEmpty,
    );
    expect(await database.select(database.outcomeReports).get(), hasLength(1));
  });

  test('AC-G-002,008,015 / AC-H-002,003,005,009,017,018: invalid or '
      'implicit contributions are rejected without partial writes', () async {
    const manualSource = OutcomeReportSource(
      type: OutcomeSourceType.manual,
      sourceId: _manualReportId,
      label: 'Structured manual activity',
      activityDate: _date,
    );
    await expectLater(
      reports.submit(
        profileId: profileId,
        draft: const OutcomeReportDraft(
          id: _manualReportId,
          source: manualSource,
          activityDate: _date,
          outcome: OutcomeKind.didNotHappen,
          contributions: <ContributionDraft>[
            ContributionDraft(
              ruleKey: 'title-guessed-rule',
              indicatorKey: 'exercise',
              value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
            ),
          ],
        ),
        operationId: _manualOperationId,
      ),
      throwsA(isA<OutcomeReportValidationException>()),
    );
    await expectLater(
      reports.submit(
        profileId: profileId,
        draft: const OutcomeReportDraft(
          id: _manualReportId,
          source: manualSource,
          activityDate: _date,
          outcome: OutcomeKind.partiallyCompleted,
        ),
        operationId: _manualOperationId,
      ),
      throwsA(isA<OutcomeReportValidationException>()),
    );
    await expectLater(
      reports.submit(
        profileId: profileId,
        draft: const OutcomeReportDraft(
          id: _manualReportId,
          source: manualSource,
          activityDate: _date,
          outcome: OutcomeKind.completedHappened,
          contributions: <ContributionDraft>[
            ContributionDraft(
              ruleKey: 'explicit:exercise:hours',
              indicatorKey: 'exercise',
              value: IndicatorValue(scaledValue: 125, scale: 2, unit: 'hours'),
            ),
          ],
        ),
        operationId: _manualOperationId,
      ),
      throwsA(isA<OutcomeReportValidationException>()),
    );
    expect(await database.select(database.outcomeReports).get(), isEmpty);
    expect(
      await database.select(database.activityLedgerEntries).get(),
      isEmpty,
    );
  });

  test('AC-G-020 / AC-H-012..015,019,020: manual Activity Report exposes '
      'effective history and survives planning-source archival', () async {
    const source = OutcomeReportSource(
      type: OutcomeSourceType.manual,
      sourceId: _manualReportId,
      label: 'Manual factual activity',
      activityDate: _date,
    );
    final result = await reports.submit(
      profileId: profileId,
      draft: const OutcomeReportDraft(
        id: _manualReportId,
        source: source,
        activityDate: _date,
        outcome: OutcomeKind.partiallyCompleted,
        factualValue: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
        contributions: <ContributionDraft>[
          ContributionDraft(
            ruleKey: 'manual:meaningful_connections:count',
            indicatorKey: 'meaningful_connections',
            value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
          ),
        ],
      ),
      operationId: _manualOperationId,
    );
    final rebuilt = await reports.rebuildActuals(
      profileId: profileId,
      startDate: _date,
      endDate: _date,
    );
    final sourceReport = await reports.readReport(
      profileId: profileId,
      reportId: result.entries.single.sourceReportId,
    );

    expect(result.report.outcome, OutcomeKind.partiallyCompleted);
    expect(sourceReport!.id, _manualReportId);
    expect(
      rebuilt
          .singleWhere(
            (actual) => actual.indicatorKey == 'meaningful_connections',
          )
          .value
          .scaledValue,
      1,
    );
    expect(await reports.readReportHistory(profileId), hasLength(1));
    expect(await reports.readLedgerHistory(profileId: profileId), hasLength(1));
  });

  test('AC-G-007,016 / AC-H-020: injected failure rolls back report, Task, '
      'and ledger atomically', () async {
    await tasks.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: _taskId,
        title: 'Atomic report',
        dueDate: _date,
        requiresReport: true,
      ),
    );
    final failing = DriftOutcomeReportingRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 28, 12)),
      writeGuard: const _FailingOutcomeReportingWriteGuard(),
    );
    final source = (await failing.readTaskSource(
      profileId: profileId,
      taskId: _taskId,
    ))!;

    await expectLater(
      failing.submit(
        profileId: profileId,
        draft: OutcomeReportDraft(
          id: _reportId,
          source: source,
          activityDate: _date,
          outcome: OutcomeKind.completedHappened,
          contributions: const <ContributionDraft>[
            ContributionDraft(
              ruleKey: 'atomic:exercise:count',
              indicatorKey: 'exercise',
              value: IndicatorValue(scaledValue: 1, scale: 0, unit: 'count'),
            ),
          ],
        ),
        operationId: _operationId,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await database.select(database.outcomeReports).get(), isEmpty);
    expect(
      await database.select(database.activityLedgerEntries).get(),
      isEmpty,
    );
    expect(
      (await tasks.readTask(profileId: profileId, taskId: _taskId))!.status,
      PlannerTaskStatus.incomplete,
    );
  });
}

final class _FailingOutcomeReportingWriteGuard
    implements OutcomeReportingWriteGuard {
  const _FailingOutcomeReportingWriteGuard();

  @override
  Future<void> beforeCommit() {
    throw StateError('Injected report write failure');
  }
}
