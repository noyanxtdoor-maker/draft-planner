import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late String profileId;
  late DriftPlannerRepository repository;
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    repository = DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('AC-C-004,005,011,019 and AC-D-001..007,015..017: offline saves '
      'are atomic, idempotent, and derive due sections', () async {
    const stableDraft = PlannerTaskDraft(
      id: 'task-stable',
      title: '  Prepare plan  ',
      dueDate: selected,
      requiresReport: false,
    );
    final first = await repository.saveTask(
      profileId: profileId,
      draft: stableDraft,
    );
    final retry = await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-stable',
        title: 'Prepare updated plan',
        dueDate: selected,
        requiresReport: false,
      ),
    );
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-overdue',
        title: 'Overdue Task',
        dueDate: PlannerDate(year: 2026, month: 7, day: 26),
        requiresReport: false,
      ),
    );
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-no-date',
        title: 'No due date',
        dueDate: null,
        requiresReport: false,
      ),
    );

    final day = await repository.readDay(
      profileId: profileId,
      selectedDate: selected,
      today: selected,
    );
    final rows = await database.select(database.plannerTasks).get();

    expect(first.status, PlannerTaskStatus.incomplete);
    expect(retry.title, 'Prepare updated plan');
    expect(rows, hasLength(3));
    expect(
      day.tasks.map((task) => task.id),
      containsAll(<String>['task-stable', 'task-no-date']),
    );
    expect(day.overdueTasks.single.id, 'task-overdue');
  });

  test('Phase B: Day projects only the effective canonical Task outcome',
      () async {
    const taskId = 'task-report-badge';
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: taskId,
        title: 'Status source fixture',
        dueDate: selected,
        dueMinute: 9 * 60,
        requiresReport: true,
      ),
    );
    await database.into(database.outcomeReports).insert(
          OutcomeReportsCompanion.insert(
            id: 'task-report-badge-effective',
            profileId: profileId,
            sourceType: OutcomeSourceType.task.name,
            sourceId: taskId,
            sourceLabel: 'Status source fixture',
            sourceSlotKey: 'task:$taskId',
            effectiveSlotKey: Value<String>('task:$taskId'),
            status: OutcomeReportStatus.submitted.name,
            outcome: Value<String>(
              OutcomeKind.partiallyCompleted.name,
            ),
            activityDate: selected.iso8601,
            createdAtUtc: DateTime.utc(2026, 7, 27, 12),
            updatedAtUtc: DateTime.utc(2026, 7, 27, 12),
          ),
        );

    var day = await repository.readDay(
      profileId: profileId,
      selectedDate: selected,
      today: selected,
    );
    expect(
      day.tasks.singleWhere((task) => task.id == taskId).reportedOutcome,
      OutcomeKind.partiallyCompleted,
    );

    await (database.update(database.outcomeReports)
          ..where((row) => row.id.equals('task-report-badge-effective')))
        .write(
          OutcomeReportsCompanion(
            status: Value<String>(OutcomeReportStatus.superseded.name),
            effectiveSlotKey: Value<String?>(null),
          ),
        );
    day = await repository.readDay(
      profileId: profileId,
      selectedDate: selected,
      today: selected,
    );
    expect(
      day.tasks.singleWhere((task) => task.id == taskId).reportedOutcome,
      isNull,
      reason: 'A cleared status must not be inferred from Task lifecycle.',
    );
  });

  test('recurring Tasks project only matching dates without persisted '
      'occurrences or duplicate overdue rows', () async {
    const anchor = PlannerDate(year: 2026, month: 1, day: 31);
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'daily',
        title: 'Daily',
        dueDate: anchor,
        recurrence: PlannerTaskRecurrence.daily,
        requiresReport: false,
      ),
    );
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'monthly',
        title: 'Monthly',
        dueDate: anchor,
        recurrence: PlannerTaskRecurrence.monthly,
        requiresReport: false,
      ),
    );
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'weekly',
        title: 'Weekly',
        dueDate: anchor,
        recurrence: PlannerTaskRecurrence.weekly,
        requiresReport: false,
      ),
    );

    final matchingDay = await repository.readDay(
      profileId: profileId,
      selectedDate: const PlannerDate(year: 2026, month: 2, day: 28),
      today: selected,
    );
    final nonMatchingDay = await repository.readDay(
      profileId: profileId,
      selectedDate: const PlannerDate(year: 2026, month: 2, day: 27),
      today: selected,
    );
    final rows = await database.select(database.plannerTasks).get();

    expect(
      matchingDay.tasks.map((task) => task.id),
      containsAll(<String>['daily', 'monthly', 'weekly']),
    );
    expect(matchingDay.overdueTasks, isEmpty);
    expect(nonMatchingDay.tasks.map((task) => task.id), contains('daily'));
    expect(
      nonMatchingDay.tasks.map((task) => task.id),
      isNot(contains('monthly')),
    );
    expect(
      nonMatchingDay.overdueTasks.map((task) => task.id),
      containsAll(<String>['monthly', 'weekly']),
    );
    expect(
      rows,
      hasLength(3),
      reason: 'recurrence is a read projection, not persisted occurrences',
    );

    await repository.changeTaskStatus(
      profileId: profileId,
      taskId: 'daily',
      target: PlannerTaskStatus.completed,
      operationId: 'daily-completed',
    );
    final afterCompletion = await repository.readDay(
      profileId: profileId,
      selectedDate: const PlannerDate(year: 2026, month: 3, day: 2),
      today: selected,
    );
    expect(
      afterCompletion.tasks.map((task) => task.id),
      isNot(contains('daily')),
    );
  });

  test('VS08-OWNER / TASK PEOPLE: selected People normalize, persist, and '
      'can be removed on edit', () async {
    final saved = await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-people',
        title: 'Visit family',
        dueDate: null,
        requiresReport: false,
        people: <String>['  Allen  ', 'Mia', 'Allen'],
      ),
    );
    expect(saved.people, <String>['Allen', 'Mia']);

    final updated = await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-people',
        title: 'Visit family',
        dueDate: null,
        requiresReport: false,
        people: <String>['Mia'],
      ),
    );
    expect(
      (await repository.readTask(
        profileId: profileId,
        taskId: 'task-people',
      ))?.people,
      <String>['Mia'],
    );
    expect(updated.people, <String>['Mia']);
  });

  test('AC-C-002,003,006..008,013..016,020: mixed event read models remain '
      'distinct and use the locked section rules', () async {
    final source = MemoryPlannerCalendarSource(<PlannerCalendarItem>[
      PlannerCalendarItem(
        id: 'all-day',
        title: 'All day',
        date: selected,
        timing: PlannerEventTiming.allDay,
        state: PlannerEventState.scheduled,
        requiresReport: false,
        hasOutcomeReport: false,
        locationText: 'Typed location',
      ),
      PlannerCalendarItem(
        id: 'timed',
        title: 'Timed',
        date: selected,
        timing: PlannerEventTiming.timed,
        state: PlannerEventState.scheduled,
        requiresReport: false,
        hasOutcomeReport: false,
        startLocal: DateTime(2026, 7, 27, 13),
        endLocal: DateTime(2026, 7, 27, 14),
        isRecurring: true,
      ),
      PlannerCalendarItem(
        id: 'awaiting',
        title: 'Needs report',
        date: selected,
        timing: PlannerEventTiming.timed,
        state: PlannerEventState.scheduled,
        requiresReport: true,
        hasOutcomeReport: false,
        startLocal: DateTime(2020, 1, 1, 8),
        endLocal: DateTime(2020, 1, 1, 9),
      ),
      PlannerCalendarItem(
        id: 'cancelled',
        title: 'Cancelled',
        date: selected,
        timing: PlannerEventTiming.allDay,
        state: PlannerEventState.cancelled,
        requiresReport: false,
        hasOutcomeReport: false,
      ),
      PlannerCalendarItem(
        id: 'rescheduled',
        title: 'Original',
        date: selected,
        timing: PlannerEventTiming.timed,
        state: PlannerEventState.rescheduled,
        requiresReport: false,
        hasOutcomeReport: false,
        replacementId: 'replacement',
      ),
    ]);
    final eventRepository = DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      calendarSource: source,
    );

    final day = await eventRepository.readDay(
      profileId: profileId,
      selectedDate: selected,
      today: selected,
    );

    expect(day.allDayEvents.single.id, 'all-day');
    expect(day.allDayEvents.single.locationText, 'Typed location');
    final timed = day.timedEvents.singleWhere((event) => event.id == 'timed');
    expect(timed.isRecurring, isTrue);
    expect(
      day.timedEvents.map((event) => event.id),
      contains('awaiting'),
      reason: 'Awaiting Report is an overlay, not a visibility filter.',
    );
    expect(day.awaitingReportEvents.single.id, 'awaiting');
    expect(
      day.changes.map((change) => change.id),
      containsAll(<String>['cancelled', 'rescheduled']),
    );
  });

  test('AC-D-005,008..012,017..020: status writes preserve independence, '
      'direct completion, and retry identity', () async {
    await repository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-report',
        title: 'Report Task',
        dueDate: selected,
        requiresReport: true,
      ),
    );
    final completed = await repository.changeTaskStatus(
      profileId: profileId,
      taskId: 'task-report',
      target: PlannerTaskStatus.completed,
      operationId: 'operation-completed',
    );
    final skipped = await repository.changeTaskStatus(
      profileId: profileId,
      taskId: 'task-report',
      target: PlannerTaskStatus.skipped,
      operationId: 'operation-skip',
    );
    final retry = await repository.changeTaskStatus(
      profileId: profileId,
      taskId: 'task-report',
      target: PlannerTaskStatus.skipped,
      operationId: 'operation-skip',
    );
    final task = await repository.readTask(
      profileId: profileId,
      taskId: 'task-report',
    );
    final changes = await database.select(database.taskStatusChanges).get();
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        )
        .get();

    expect(completed, TaskStatusChangeOutcome.changed);
    expect(skipped, TaskStatusChangeOutcome.correctionRequired);
    expect(retry, TaskStatusChangeOutcome.correctionRequired);
    expect(task!.status, PlannerTaskStatus.completed);
    expect(changes, hasLength(1));
    expect(
      changes.map((change) => change.toStatus),
      contains(PlannerTaskStatus.completed.name),
    );
    expect(
      tables.map((row) => row.read<String>('name')),
      isNot(contains('actual_contributions')),
    );
  });

  test(
    'AC-C-019 / BR-C-010: injected save failure rolls back false records',
    () async {
      final failing = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        writeGuard: const FailingTaskWriteGuard(),
      );

      await expectLater(
        failing.saveTask(
          profileId: profileId,
          draft: const PlannerTaskDraft(
            id: 'false-task',
            title: 'Must roll back',
            dueDate: selected,
            requiresReport: false,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await database.select(database.plannerTasks).get(), isEmpty);
    },
  );

  test('AC-D-018 / OPD-1-013: historical effects require correction', () async {
    final guardedRepository = DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      historicalEffectReader: const FixedHistoricalEffectReader(true),
    );
    await guardedRepository.saveTask(
      profileId: profileId,
      draft: const PlannerTaskDraft(
        id: 'task-correction',
        title: 'Correction Task',
        dueDate: selected,
        requiresReport: false,
      ),
    );
    await guardedRepository.changeTaskStatus(
      profileId: profileId,
      taskId: 'task-correction',
      target: PlannerTaskStatus.completed,
      operationId: 'complete',
    );

    final reopen = await guardedRepository.changeTaskStatus(
      profileId: profileId,
      taskId: 'task-correction',
      target: PlannerTaskStatus.incomplete,
      operationId: 'reopen',
    );

    expect(reopen, TaskStatusChangeOutcome.correctionRequired);
    expect(
      (await guardedRepository.readTask(
        profileId: profileId,
        taskId: 'task-correction',
      ))!.status,
      PlannerTaskStatus.completed,
    );
  });

  test(
    'BR-D-009,010: concurrent status writes preserve factual history',
    () async {
      await repository.saveTask(
        profileId: profileId,
        draft: const PlannerTaskDraft(
          id: 'task-concurrent',
          title: 'Concurrent Task',
          dueDate: selected,
          requiresReport: false,
        ),
      );

      final outcomes = await Future.wait(<Future<TaskStatusChangeOutcome>>[
        repository.changeTaskStatus(
          profileId: profileId,
          taskId: 'task-concurrent',
          target: PlannerTaskStatus.completed,
          operationId: 'operation-complete',
        ),
        repository.changeTaskStatus(
          profileId: profileId,
          taskId: 'task-concurrent',
          target: PlannerTaskStatus.skipped,
          operationId: 'operation-skip',
        ),
      ]);
      final changes = await database.select(database.taskStatusChanges).get();

      expect(outcomes, contains(TaskStatusChangeOutcome.changed));
      expect(outcomes, contains(TaskStatusChangeOutcome.correctionRequired));
      expect(changes, hasLength(1));
      expect(changes.single.fromStatus, PlannerTaskStatus.incomplete.name);
    },
  );
}
