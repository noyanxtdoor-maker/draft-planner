import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';

import '../../../support/counting_query_executor.dart';
import '../../../support/test_dependencies.dart';

const _selected = PlannerDate(year: 2026, month: 7, day: 27);
final _clock = DateTime.utc(2026, 7, 27, 12);

void main() {
  late AppDatabase database;
  late CountingQueryExecutor executor;
  late String profileId;
  late DriftPlannerRepository planner;
  late DriftTaskEventLinkRepository links;
  late DriftOutcomeReportingRepository reports;
  late DriftCalendarEventRepository calendar;

  setUp(() async {
    executor = CountingQueryExecutor(NativeDatabase.memory());
    database = AppDatabase.forTesting(executor);
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    links = DriftTaskEventLinkRepository(
      database: database,
      clock: FixedClock(_clock),
    );
    reports = DriftOutcomeReportingRepository(
      database: database,
      clock: FixedClock(_clock),
    );
    calendar = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(_clock),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      taskContextSource: links,
      linkContextTransfer: links,
      reportSource: reports,
    );
    planner = DriftPlannerRepository(
      database: database,
      clock: FixedClock(_clock),
      calendarSource: calendar,
      taskContextSource: links,
      historicalEffectReader: reports,
    );
  });

  tearDown(() => database.close());

  Future<void> seedEvent(String eventId) {
    return database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: eventId,
            profileId: profileId,
            title: 'Event $eventId',
            timing: CalendarEventTiming.allDay.name,
            startDate: _selected.iso8601,
            createdAtUtc: _clock,
            updatedAtUtc: _clock,
          ),
        );
  }

  Future<void> seedTask(String taskId) {
    return database
        .into(database.plannerTasks)
        .insert(
          PlannerTasksCompanion.insert(
            id: taskId,
            profileId: profileId,
            title: 'Task $taskId',
            dueDate: Value<String?>(_selected.iso8601),
            createdAtUtc: _clock,
            updatedAtUtc: _clock,
          ),
        );
  }

  Future<void> seedLink(String id, String taskId, String eventId) {
    return database
        .into(database.taskEventLinks)
        .insert(
          TaskEventLinksCompanion.insert(
            id: id,
            profileId: profileId,
            taskId: taskId,
            eventId: eventId,
            scope: TaskEventLinkScope.series.name,
            targetKey: 'series',
            occurrenceId: const Value<String?>(null),
            originalDate: const Value<String?>(null),
            status: Value<String>(TaskEventLinkStatus.active.name),
            canonicalSource: TaskEventCanonicalSource.task.name,
            createdAtUtc: _clock,
            updatedAtUtc: _clock,
          ),
        );
  }

  Future<void> seedReport(String eventId, String occurrenceId) {
    return database
        .into(database.outcomeReports)
        .insert(
          OutcomeReportsCompanion.insert(
            id: 'report-$eventId',
            profileId: profileId,
            sourceType: OutcomeSourceType.event.name,
            sourceId: eventId,
            sourceLabel: 'Event',
            sourceSlotKey: 'event:$eventId:$occurrenceId',
            eventId: Value<String?>(eventId),
            occurrenceId: Value<String?>(occurrenceId),
            originalDate: Value<String?>(_selected.iso8601),
            effectiveSlotKey: Value<String?>(_selected.iso8601),
            status: OutcomeReportStatus.submitted.name,
            outcome: Value<String?>(OutcomeKind.completedHappened.name),
            activityDate: _selected.iso8601,
            createdAtUtc: _clock,
            updatedAtUtc: _clock,
          ),
        );
  }

  Future<void> seedDataset({
    required int eventCount,
    int startIndex = 0,
    bool withTasks = true,
    bool withLinks = false,
    bool withReports = false,
  }) async {
    for (var index = startIndex; index < startIndex + eventCount; index += 1) {
      await seedEvent('evt-$index');
    }
    if (withTasks) {
      for (var index = 0; index < 3; index += 1) {
        await seedTask('task-$index');
      }
    }
    if (withLinks) {
      for (
        var index = startIndex;
        index < startIndex + eventCount;
        index += 1
      ) {
        await seedLink('link-$index', 'task-0', 'evt-$index');
      }
    }
    if (withReports) {
      for (
        var index = startIndex;
        index < startIndex + eventCount;
        index += 1
      ) {
        final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
          eventId: 'evt-$index',
          originalDate: _selected,
        );
        await seedReport('evt-$index', occurrenceId);
      }
    }
  }

  Future<int> readDayCount() async {
    executor.clear();
    await planner.readDay(
      profileId: profileId,
      selectedDate: _selected,
      today: _selected,
    );
    return executor.statementCount;
  }

  bool hasRowShape(String table, String column) => executor.statements.any(
    (statement) =>
        statement.contains(table) && statement.contains('$column = ?'),
  );

  test('DATASET A (10 events, 3 tasks): readDay stays bounded and leaves no '
      'per-row SQL shapes', () async {
    await seedDataset(eventCount: 10);
    final count = await readDayCount();
    expect(count, lessThanOrEqualTo(12));
    expect(hasRowShape('outcome_reports', 'event_id'), isFalse);
    expect(hasRowShape('calendar_event_exceptions', 'event_id'), isFalse);
    expect(hasRowShape('task_event_links', 'event_id'), isFalse);
    expect(hasRowShape('task_event_links', 'task_id'), isFalse);
  });

  test('DATASET B (176 events, 3 tasks): owner-sized read is <=12 statements '
      '(hard ceiling <=20)', () async {
    await seedDataset(eventCount: 176, withLinks: true, withReports: true);
    final count = await readDayCount();
    expect(
      count,
      lessThanOrEqualTo(12),
      reason: 'preferred target for the owner-sized profile',
    );
    expect(count, lessThanOrEqualTo(20), reason: 'hard acceptance ceiling');
    expect(hasRowShape('outcome_reports', 'event_id'), isFalse);
    expect(hasRowShape('calendar_event_exceptions', 'event_id'), isFalse);
    expect(hasRowShape('task_event_links', 'event_id'), isFalse);
    expect(hasRowShape('task_event_links', 'task_id'), isFalse);
  });

  test('statement count does NOT scale with Event count (17x regression '
      'guard)', () async {
    await seedDataset(eventCount: 10, withLinks: true);
    final countA = await readDayCount();
    await seedDataset(
      eventCount: 166,
      startIndex: 10,
      withTasks: false,
      withLinks: true,
    );
    final countB = await readDayCount();
    expect(
      countB,
      lessThan(countA * 3),
      reason: 'growth must come from batch chunk count, not per-Event queries',
    );
    expect(countB, lessThanOrEqualTo(12));
  });

  test('DATASET C (600+ events): growth comes only from chunk count', () async {
    await seedDataset(eventCount: 600, withLinks: true);
    final countC = await readDayCount();
    expect(
      countC,
      lessThanOrEqualTo(12),
      reason: '600 events still fit within the owner-sized budget',
    );

    await seedDataset(eventCount: 176, startIndex: 600, withTasks: false);
    final countB = await readDayCount();
    expect(
      countC,
      lessThanOrEqualTo(countB + 6),
      reason: '600 Events add at most one extra IN() chunk per batch query',
    );
  });

  test('linked Tasks add only the single batched existence query', () async {
    await seedDataset(eventCount: 20, withLinks: true);
    final countWithLinks = await readDayCount();

    await seedDataset(eventCount: 20, startIndex: 20, withTasks: false);
    final countWithoutLinks = await readDayCount();

    expect(
      countWithLinks,
      lessThanOrEqualTo(countWithoutLinks + 1),
      reason: 'Task existence validation must be one set-based query',
    );
  });

  test(
    'readDay still produces correct content through the batched path',
    () async {
      await seedDataset(eventCount: 4);
      await seedLink('link-0', 'task-0', 'evt-0');
      await seedLink('link-1', 'task-0', 'evt-1');
      await seedReport(
        'evt-0',
        CalendarEventOccurrenceIdentity.forDate(
          eventId: 'evt-0',
          originalDate: _selected,
        ),
      );
      final day = await planner.readDay(
        profileId: profileId,
        selectedDate: _selected,
        today: _selected,
      );
      expect(day.allDayEvents, hasLength(4));
      expect(day.timedEvents, isEmpty);
      expect(day.tasks, hasLength(3));
      expect(
        day.allDayEvents.singleWhere((item) => item.eventId == 'evt-0').state,
        PlannerEventState.completedHappened,
        reason: 'the batched report lookup must overlay the submitted outcome',
      );
      expect(
        day.allDayEvents
            .singleWhere((item) => item.eventId == 'evt-1')
            .linkedTaskIds,
        <String>['task-0'],
      );
      expect(
        day.allDayEvents
            .singleWhere((item) => item.eventId == 'evt-3')
            .linkedTaskIds,
        isEmpty,
      );
    },
  );
}
