import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  test('AC-C-001,009,017: date-only navigation is deterministic', () {
    expect(PlannerDate.parse('2026-07-27'), selected);
    expect(selected.addDays(1).iso8601, '2026-07-28');
    expect(selected.addDays(-1).iso8601, '2026-07-26');
    expect(
      () => PlannerDate.parse('2026-02-30'),
      throwsA(isA<FormatException>()),
    );
  });

  test('AC-D-002,003,007,012,020: Task identity and classification are '
      'explicit and title-independent', () {
    const draft = PlannerTaskDraft(
      id: 'task-1',
      title: '  Scripture Study  ',
      dueDate: null,
      requiresReport: false,
    );

    final normalized = draft.normalized();

    expect(normalized.title, 'Scripture Study');
    expect(normalized.dueDate, isNull);
    expect(normalized.contributionRuleKey, isNull);
    expect(
      () => const PlannerTaskDraft(
        id: 'task-2',
        title: '   ',
        dueDate: null,
        requiresReport: false,
      ).normalized(),
      throwsA(isA<PlannerTaskValidationException>()),
    );
  });

  test('AC-D-005,006,010,011,018,019: statuses remain factual and direct '
      'completion remains idempotent', () {
    final task = _task(
      status: PlannerTaskStatus.incomplete,
      requiresReport: true,
      dueDate: const PlannerDate(year: 2026, month: 7, day: 26),
    );

    expect(task.isOverdueOn(selected), isTrue);
    expect(
      TaskStatusPolicy.evaluate(
        task: task,
        target: PlannerTaskStatus.completed,
        hasReportOrLedgerEffect: false,
      ),
      TaskStatusChangeOutcome.changed,
    );
    expect(
      TaskStatusPolicy.evaluate(
        task: task,
        target: PlannerTaskStatus.skipped,
        hasReportOrLedgerEffect: false,
      ),
      TaskStatusChangeOutcome.changed,
    );

    final completed = _task(status: PlannerTaskStatus.completed);
    expect(
      TaskStatusPolicy.evaluate(
        task: completed,
        target: PlannerTaskStatus.incomplete,
        hasReportOrLedgerEffect: true,
      ),
      TaskStatusChangeOutcome.correctionRequired,
    );
    expect(
      TaskStatusPolicy.evaluate(
        task: completed,
        target: PlannerTaskStatus.incomplete,
        hasReportOrLedgerEffect: false,
      ),
      TaskStatusChangeOutcome.changed,
    );
  });

  test('Planner Task recurrence projects schema-free matching dates and stops '
      'after a factual status change', () {
    final anchor = const PlannerDate(year: 2026, month: 1, day: 31);
    final daily = _task(
      dueDate: anchor,
      recurrence: PlannerTaskRecurrence.daily,
    );
    final weekly = _task(
      dueDate: anchor,
      recurrence: PlannerTaskRecurrence.weekly,
    );
    final monthly = _task(
      dueDate: anchor,
      recurrence: PlannerTaskRecurrence.monthly,
    );
    final yearly = _task(
      dueDate: const PlannerDate(year: 2024, month: 2, day: 29),
      recurrence: PlannerTaskRecurrence.yearly,
    );

    expect(
      daily.projectsOn(const PlannerDate(year: 2026, month: 2, day: 1)),
      isTrue,
    );
    expect(
      daily.projectsOn(const PlannerDate(year: 2026, month: 1, day: 30)),
      isFalse,
    );
    expect(
      weekly.projectsOn(const PlannerDate(year: 2026, month: 2, day: 7)),
      isTrue,
    );
    expect(
      weekly.projectsOn(const PlannerDate(year: 2026, month: 2, day: 8)),
      isFalse,
    );
    expect(
      monthly.projectsOn(const PlannerDate(year: 2026, month: 2, day: 28)),
      isTrue,
    );
    expect(
      yearly.projectsOn(const PlannerDate(year: 2025, month: 2, day: 28)),
      isTrue,
    );
    for (final status in <PlannerTaskStatus>[
      PlannerTaskStatus.completed,
      PlannerTaskStatus.skipped,
      PlannerTaskStatus.cancelled,
    ]) {
      expect(
        _task(
          dueDate: anchor,
          recurrence: PlannerTaskRecurrence.daily,
          status: status,
        ).projectsOn(const PlannerDate(year: 2026, month: 2, day: 1)),
        isFalse,
        reason: '$status ends future Task projections.',
      );
    }
    expect(
      _task(
        dueDate: null,
        recurrence: PlannerTaskRecurrence.daily,
      ).projectsOn(const PlannerDate(year: 2026, month: 2, day: 1)),
      isFalse,
      reason: 'undated Tasks never fabricate recurrence dates',
    );
  });

  test('AC-C-002,003,006..008,013..016,020: event presentation derives '
      'attention without mutating outcomes or identities', () {
    final ended = PlannerCalendarItem(
      id: 'event-1',
      title: 'Private event',
      date: selected,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: true,
      hasOutcomeReport: false,
      startLocal: DateTime(2026, 7, 27, 8),
      endLocal: DateTime(2026, 7, 27, 9),
      locationText: 'Stored location',
      isRecurring: true,
      linkedTaskIds: const <String>['task-1'],
    );
    final cancelled = PlannerCalendarItem(
      id: 'event-2',
      title: 'Cancelled event',
      date: selected,
      timing: PlannerEventTiming.allDay,
      state: PlannerEventState.cancelled,
      requiresReport: false,
      hasOutcomeReport: false,
    );
    final rescheduled = PlannerCalendarItem(
      id: 'event-3',
      title: 'Original event',
      date: selected,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.rescheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      replacementId: 'event-4',
    );

    expect(ended.isAwaitingReport(DateTime(2026, 7, 27, 10)), isTrue);
    expect(ended.state, PlannerEventState.scheduled);
    expect(ended.locationText, 'Stored location');
    expect(ended.linkedTaskIds, contains('task-1'));
    expect(cancelled.isChange, isTrue);
    expect(rescheduled.isChange, isTrue);
    expect(rescheduled.replacementId, 'event-4');
  });
}

PlannerTask _task({
  PlannerTaskStatus status = PlannerTaskStatus.incomplete,
  bool requiresReport = false,
  PlannerDate? dueDate,
  PlannerTaskRecurrence recurrence = PlannerTaskRecurrence.none,
}) {
  return PlannerTask(
    id: 'task-1',
    profileId: 'profile-1',
    title: 'Task',
    dueDate: dueDate,
    recurrence: recurrence,
    status: status,
    requiresReport: requiresReport,
    createdAtUtc: DateTime.utc(2026, 7, 26),
    updatedAtUtc: DateTime.utc(2026, 7, 26),
  );
}
