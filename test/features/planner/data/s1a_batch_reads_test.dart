import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';

import '../../../support/counting_query_executor.dart';
import '../../../support/test_dependencies.dart';

final _profileTime = DateTime.utc(2026, 7, 27, 12);

/// Snapshot instances do not override `==`, so equivalence is asserted on
/// their identity fields (occurrenceId | originalDate | status).
List<String> _reportKeys(List<CalendarEventReportSnapshot> reports) {
  return reports
      .map(
        (report) =>
            '${report.occurrenceId}|${report.originalDate.iso8601}|'
            '${report.status.name}',
      )
      .toList(growable: false);
}

void main() {
  late AppDatabase database;
  late CountingQueryExecutor executor;
  late String profileId;
  var seedIndex = 0;

  setUp(() async {
    executor = CountingQueryExecutor(NativeDatabase.memory());
    database = AppDatabase.forTesting(executor);
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    seedIndex = 0;
  });

  tearDown(() => database.close());

  String nextId(String prefix) => '$prefix-${seedIndex++}';

  group('S1A-01 batch outcome reports', () {
    late DriftOutcomeReportingRepository repository;

    setUp(() {
      repository = DriftOutcomeReportingRepository(
        database: database,
        clock: FixedClock(_profileTime),
      );
    });

    Future<void> seedReport({
      required String eventId,
      required String occurrenceId,
      required PlannerDate originalDate,
      required String status,
      String? outcome,
      String? effectiveSlotKey,
      required DateTime createdAtUtc,
    }) {
      return database
          .into(database.outcomeReports)
          .insert(
            OutcomeReportsCompanion.insert(
              id: nextId('report'),
              profileId: profileId,
              sourceType: OutcomeSourceType.event.name,
              sourceId: eventId,
              sourceLabel: 'Event',
              sourceSlotKey: 'event:$eventId:$occurrenceId',
              eventId: Value<String?>(eventId),
              occurrenceId: Value<String?>(occurrenceId),
              originalDate: Value<String?>(originalDate.iso8601),
              effectiveSlotKey: Value<String?>(effectiveSlotKey),
              status: status,
              outcome: Value<String?>(outcome),
              activityDate: originalDate.iso8601,
              createdAtUtc: createdAtUtc,
              updatedAtUtc: createdAtUtc,
            ),
          );
    }

    test(
      'zero Event IDs return an empty map and issue zero statements',
      () async {
        executor.clear();
        final result = await repository.readSeriesReportsForEvents(
          const <String>[],
        );
        expect(result, isEmpty);
        expect(executor.statementCount, 0);
      },
    );

    test('one-ID batch is equivalent to the single-Event read', () async {
      const eventId = 'evt-a';
      const originalDate = PlannerDate(year: 2026, month: 7, day: 26);
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: originalDate,
      );
      await seedReport(
        eventId: eventId,
        occurrenceId: occurrenceId,
        originalDate: originalDate,
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: 'slot-1',
        createdAtUtc: _profileTime,
      );

      final single = await repository.readSeriesReports(eventId);
      final batch = await repository.readSeriesReportsForEvents(const <String>[
        eventId,
      ]);
      expect(_reportKeys(batch[eventId]!), _reportKeys(single));
      expect(batch[eventId]!.single.occurrenceId, occurrenceId);
    });

    test('multiple Event IDs group correctly and an Event with no reports '
        'has no map entry', () async {
      await seedReport(
        eventId: 'evt-a',
        occurrenceId: 'occ-1',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: 'slot-1',
        createdAtUtc: _profileTime,
      );
      await seedReport(
        eventId: 'evt-b',
        occurrenceId: 'occ-1',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 27),
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.didNotHappen.name,
        effectiveSlotKey: 'slot-2',
        createdAtUtc: _profileTime,
      );

      final batch = await repository.readSeriesReportsForEvents(const <String>[
        'evt-a',
        'evt-b',
        'evt-c',
      ]);
      expect(batch.keys, <String>{'evt-a', 'evt-b'});
      expect(batch['evt-a'], hasLength(1));
      expect(batch['evt-b']!.single.status, CalendarEventStatus.didNotHappen);
      expect(batch['evt-c'], isNull);
      expect(batch['evt-c'] ?? const <Object>[], isEmpty);
    });

    test('draft, superseded, and effectiveSlotKey-null rows are excluded '
        'exactly as the single-Event read', () async {
      const eventId = 'evt-a';
      await seedReport(
        eventId: eventId,
        occurrenceId: 'occ-draft',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
        status: OutcomeReportStatus.draft.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: null,
        createdAtUtc: _profileTime,
      );
      await seedReport(
        eventId: eventId,
        occurrenceId: 'occ-superseded',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
        status: OutcomeReportStatus.superseded.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: 'slot-old',
        createdAtUtc: _profileTime,
      );
      await seedReport(
        eventId: eventId,
        occurrenceId: 'occ-no-slot',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: null,
        createdAtUtc: _profileTime,
      );
      await seedReport(
        eventId: eventId,
        occurrenceId: 'occ-ok',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: 'slot-ok',
        createdAtUtc: _profileTime,
      );

      final single = await repository.readSeriesReports(eventId);
      final batch = await repository.readSeriesReportsForEvents(const <String>[
        eventId,
      ]);
      expect(_reportKeys(batch[eventId]!), _reportKeys(single));
      expect(single.map((item) => item.occurrenceId), <String>['occ-ok']);
    });

    test('per-Event ordering follows activityDate ascending', () async {
      const eventId = 'evt-a';
      await seedReport(
        eventId: eventId,
        occurrenceId: 'occ-later',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 27),
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.completedHappened.name,
        effectiveSlotKey: 'slot-2',
        createdAtUtc: _profileTime,
      );
      await seedReport(
        eventId: eventId,
        occurrenceId: 'occ-earlier',
        originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
        status: OutcomeReportStatus.submitted.name,
        outcome: OutcomeKind.partiallyCompleted.name,
        effectiveSlotKey: 'slot-1',
        createdAtUtc: _profileTime,
      );

      final batch = await repository.readSeriesReportsForEvents(const <String>[
        eventId,
      ]);
      expect(batch[eventId]!.map((item) => item.occurrenceId), <String>[
        'occ-earlier',
        'occ-later',
      ]);
      expect(
        _reportKeys(batch[eventId]!),
        _reportKeys(await repository.readSeriesReports(eventId)),
      );
    });

    test(
      'more than 500 Event IDs issue deterministic chunks and merge',
      () async {
        final eventIds = <String>[];
        for (var index = 0; index < 600; index += 1) {
          final eventId = 'evt-$index';
          eventIds.add(eventId);
          await seedReport(
            eventId: eventId,
            occurrenceId: 'occ-1',
            originalDate: const PlannerDate(year: 2026, month: 7, day: 26),
            status: OutcomeReportStatus.submitted.name,
            outcome: OutcomeKind.completedHappened.name,
            effectiveSlotKey: 'slot-1',
            createdAtUtc: _profileTime,
          );
        }
        executor.clear();
        final batch = await repository.readSeriesReportsForEvents(eventIds);
        expect(batch, hasLength(600));
        final reportStatements = executor.statements
            .where((statement) => statement.contains('outcome_reports'))
            .toList();
        expect(
          reportStatements,
          hasLength(2),
          reason: '600 IDs must split into two bounded IN() chunks',
        );
      },
    );
  });

  group('S1A-02 batch calendar event exceptions', () {
    late DriftCalendarEventRepository repository;

    setUp(() {
      repository = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(_profileTime),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
    });

    Future<void> seedEvent({
      required String eventId,
      required PlannerDate startDate,
      String timing = 'allDay',
    }) {
      return database
          .into(database.calendarEvents)
          .insert(
            CalendarEventsCompanion.insert(
              id: eventId,
              profileId: profileId,
              title: 'Event $eventId',
              timing: timing,
              startDate: startDate.iso8601,
              createdAtUtc: _profileTime,
              updatedAtUtc: _profileTime,
            ),
          );
    }

    Future<void> seedException({
      required String eventId,
      required String occurrenceId,
      required PlannerDate originalDate,
      required PlannerDate effectiveDate,
      required String title,
      required String status,
      required DateTime createdAtUtc,
    }) {
      return database
          .into(database.calendarEventExceptions)
          .insert(
            CalendarEventExceptionsCompanion.insert(
              id: nextId('exc'),
              profileId: profileId,
              eventId: eventId,
              occurrenceId: occurrenceId,
              originalDate: originalDate.iso8601,
              effectiveDate: effectiveDate.iso8601,
              title: title,
              timing: CalendarEventTiming.allDay.name,
              status: status,
              createdAtUtc: createdAtUtc,
            ),
          );
    }

    test('latest-wins for the same Event+occurrence matches the legacy '
        'single-Event read', () async {
      const eventId = 'evt-a';
      const start = PlannerDate(year: 2026, month: 7, day: 27);
      await seedEvent(eventId: eventId, startDate: start);
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: start,
      );
      await seedException(
        eventId: eventId,
        occurrenceId: occurrenceId,
        originalDate: start,
        effectiveDate: start,
        title: 'Earlier override',
        status: CalendarEventStatus.scheduled.name,
        createdAtUtc: _profileTime.subtract(const Duration(days: 1)),
      );
      await seedException(
        eventId: eventId,
        occurrenceId: occurrenceId,
        originalDate: start,
        effectiveDate: start,
        title: 'Latest override',
        status: CalendarEventStatus.scheduled.name,
        createdAtUtc: _profileTime,
      );

      // The batch map feeds readDay and must pick the same winner as the
      // legacy single-Event path used by readOccurrence.
      final day = await repository.readDay(profileId: profileId, date: start);
      expect(day, hasLength(1));
      expect(day.single.title, 'Latest override');

      final occurrence = await repository.readOccurrence(
        profileId: profileId,
        eventId: eventId,
        originalDate: start,
      );
      expect(occurrence!.title, 'Latest override');
    });

    test('cancelled and moved occurrence exceptions are preserved with their '
        'fields', () async {
      const cancelledEvent = 'evt-a';
      const movedEvent = 'evt-b';
      const start = PlannerDate(year: 2026, month: 7, day: 27);
      const movedDate = PlannerDate(year: 2026, month: 7, day: 28);
      await seedEvent(eventId: cancelledEvent, startDate: start);
      await seedEvent(eventId: movedEvent, startDate: start);
      final cancelledId = CalendarEventOccurrenceIdentity.forDate(
        eventId: cancelledEvent,
        originalDate: start,
      );
      await seedException(
        eventId: cancelledEvent,
        occurrenceId: cancelledId,
        originalDate: start,
        effectiveDate: start,
        title: 'Cancelled override',
        status: CalendarEventStatus.cancelled.name,
        createdAtUtc: _profileTime,
      );
      final movedId = CalendarEventOccurrenceIdentity.forDate(
        eventId: movedEvent,
        originalDate: start,
      );
      await seedException(
        eventId: movedEvent,
        occurrenceId: movedId,
        originalDate: start,
        effectiveDate: movedDate,
        title: 'Moved override',
        status: CalendarEventStatus.scheduled.name,
        createdAtUtc: _profileTime,
      );

      final cancelledDay = await repository.readDay(
        profileId: profileId,
        date: start,
      );
      expect(
        cancelledDay.single.title,
        'Cancelled override',
        reason: 'the cancelled lifecycle row stays on its original date',
      );
      expect(cancelledDay.single.state, PlannerEventState.cancelled);

      final movedDay = await repository.readDay(
        profileId: profileId,
        date: movedDate,
      );
      expect(
        movedDay.single.title,
        'Moved override',
        reason: 'the moved occurrence surfaces on its effective (new) day',
      );
      expect(movedDay.single.date, movedDate);
    });
  });

  group('S1A-03 batch Event->Task context snapshot', () {
    late DriftTaskEventLinkRepository links;

    setUp(() {
      links = DriftTaskEventLinkRepository(
        database: database,
        clock: FixedClock(_profileTime),
      );
    });

    Future<void> seedTask(String taskId) {
      return database
          .into(database.plannerTasks)
          .insert(
            PlannerTasksCompanion.insert(
              id: taskId,
              profileId: profileId,
              title: 'Task $taskId',
              createdAtUtc: _profileTime,
              updatedAtUtc: _profileTime,
            ),
          );
    }

    Future<void> seedLink({
      required String id,
      required String eventId,
      required String taskId,
      required TaskEventLinkScope scope,
      required TaskEventLinkStatus status,
      String? occurrenceId,
    }) {
      return database
          .into(database.taskEventLinks)
          .insert(
            TaskEventLinksCompanion.insert(
              id: id,
              profileId: profileId,
              taskId: taskId,
              eventId: eventId,
              scope: scope.name,
              targetKey: scope == TaskEventLinkScope.series
                  ? 'series'
                  : 'occurrence:$occurrenceId',
              occurrenceId: Value<String?>(occurrenceId),
              originalDate: const Value<String?>(null),
              status: Value<String>(status.name),
              canonicalSource: TaskEventCanonicalSource.task.name,
              createdAtUtc: _profileTime,
              updatedAtUtc: _profileTime,
            ),
          );
    }

    test(
      'zero Event IDs return an empty snapshot and issue zero statements',
      () async {
        executor.clear();
        final snapshot = await links.readTaskContextSnapshot(const <String>[]);
        expect(snapshot.isEmpty, isTrue);
        expect(executor.statementCount, 0);
      },
    );

    test('resolver equals the legacy readLinkedTaskIds for series, '
        'occurrence overrides, and removed overrides', () async {
      await seedTask('task-1');
      await seedTask('task-2');
      await seedTask('task-3');
      // task-ghost is referenced but does not exist -> filtered by both paths.
      const occX = 'occ-x';
      const occY = 'occ-y';
      await seedLink(
        id: 'l1',
        eventId: 'evt-a',
        taskId: 'task-1',
        scope: TaskEventLinkScope.series,
        status: TaskEventLinkStatus.active,
      );
      await seedLink(
        id: 'l2',
        eventId: 'evt-a',
        taskId: 'task-2',
        scope: TaskEventLinkScope.series,
        status: TaskEventLinkStatus.active,
      );
      await seedLink(
        id: 'l3',
        eventId: 'evt-a',
        taskId: 'task-ghost',
        scope: TaskEventLinkScope.series,
        status: TaskEventLinkStatus.active,
      );
      await seedLink(
        id: 'l4',
        eventId: 'evt-a',
        taskId: 'task-3',
        scope: TaskEventLinkScope.occurrence,
        status: TaskEventLinkStatus.active,
        occurrenceId: occX,
      );
      await seedLink(
        id: 'l5',
        eventId: 'evt-a',
        taskId: 'task-1',
        scope: TaskEventLinkScope.occurrence,
        status: TaskEventLinkStatus.removed,
        occurrenceId: occY,
      );
      await seedLink(
        id: 'l6',
        eventId: 'evt-b',
        taskId: 'task-2',
        scope: TaskEventLinkScope.series,
        status: TaskEventLinkStatus.active,
      );

      final snapshot = await links.readTaskContextSnapshot(const <String>[
        'evt-a',
        'evt-b',
      ]);
      const combos = <(String, String)>[
        ('evt-a', occX),
        ('evt-a', occY),
        ('evt-a', 'occ-z'),
        ('evt-b', occX),
        ('evt-c', occX),
      ];
      for (final (eventId, occurrenceId) in combos) {
        expect(
          snapshot.linkedTaskIds(eventId: eventId, occurrenceId: occurrenceId),
          await links.readLinkedTaskIds(
            eventId: eventId,
            occurrenceId: occurrenceId,
          ),
          reason:
              'snapshot resolver must match legacy readLinkedTaskIds '
              'for ($eventId, $occurrenceId)',
        );
      }
      // Explicit expectations for the fixed scenario.
      expect(
        snapshot.linkedTaskIds(eventId: 'evt-a', occurrenceId: occX),
        <String>['task-1', 'task-2', 'task-3'],
      );
      expect(
        snapshot.linkedTaskIds(eventId: 'evt-a', occurrenceId: occY),
        <String>['task-2'],
      );
    });

    test(
      'more than 500 Event IDs are chunked and resolved correctly',
      () async {
        await seedTask('task-0');
        final eventIds = <String>[];
        for (var index = 0; index < 600; index += 1) {
          final eventId = 'evt-$index';
          eventIds.add(eventId);
          await seedLink(
            id: 'link-$index',
            eventId: eventId,
            taskId: 'task-0',
            scope: TaskEventLinkScope.series,
            status: TaskEventLinkStatus.active,
          );
        }
        executor.clear();
        final snapshot = await links.readTaskContextSnapshot(eventIds);
        expect(snapshot.isEmpty, isFalse);
        expect(
          snapshot.linkedTaskIds(eventId: 'evt-599', occurrenceId: 'occ-x'),
          <String>['task-0'],
        );
        final linkStatements = executor.statements
            .where((statement) => statement.contains('task_event_links'))
            .toList();
        expect(
          linkStatements,
          hasLength(2),
          reason: '600 Event IDs must split into two bounded IN() chunks',
        );
      },
    );
  });

  group('S1A-04 batch Planner Task contexts', () {
    late DriftTaskEventLinkRepository links;

    setUp(() {
      links = DriftTaskEventLinkRepository(
        database: database,
        clock: FixedClock(_profileTime),
      );
    });

    Future<void> seedLink({
      required String id,
      required String taskId,
      required String eventId,
      TaskEventLinkStatus status = TaskEventLinkStatus.active,
    }) {
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
              status: Value<String>(status.name),
              canonicalSource: TaskEventCanonicalSource.task.name,
              createdAtUtc: _profileTime,
              updatedAtUtc: _profileTime,
            ),
          );
    }

    test(
      'zero Task IDs return an empty map and issue zero statements',
      () async {
        executor.clear();
        final contexts = await links.readContexts(const <String>[]);
        expect(contexts, isEmpty);
        expect(executor.statementCount, 0);
      },
    );

    test(
      'active links only, deduplicated and sorted, equals legacy readContext',
      () async {
        await seedLink(id: 'l1', taskId: 'task-a', eventId: 'event-2');
        await seedLink(id: 'l2', taskId: 'task-a', eventId: 'event-1');
        await seedLink(id: 'l3', taskId: 'task-a', eventId: 'event-1');
        await seedLink(
          id: 'l4',
          taskId: 'task-a',
          eventId: 'event-3',
          status: TaskEventLinkStatus.removed,
        );
        await seedLink(id: 'l5', taskId: 'task-b', eventId: 'event-9');

        final contexts = await links.readContexts(const <String>[
          'task-a',
          'task-b',
          'task-c',
        ]);
      expect(
        contexts['task-a']!.linkedEventIds,
        (await links.readContext('task-a')).linkedEventIds,
      );
        expect(contexts['task-a']!.linkedEventIds, <String>[
          'event-1',
          'event-2',
        ]);
      expect(
        contexts['task-b']!.linkedEventIds,
        (await links.readContext('task-b')).linkedEventIds,
      );
        // A Task with no links has no map entry (callers treat a missing entry
        // as an empty context).
        expect(contexts.containsKey('task-c'), isFalse);
      },
    );
  });
}
