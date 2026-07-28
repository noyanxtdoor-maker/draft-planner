import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const profileId = '10000000-0000-4000-8000-000000000001';
  const taskId = '20000000-0000-4000-8000-000000000001';
  const eventId = '30000000-0000-4000-8000-000000000001';
  const linkId = '40000000-0000-4000-8000-000000000001';
  const date = PlannerDate(year: 2026, month: 8, day: 2);

  late AppDatabase database;
  late DriftTaskEventLinkRepository links;

  setUp(() async {
    database = openMemoryDatabase();
    links = DriftTaskEventLinkRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 1, 12)),
    );
    await _seed(database);
  });
  tearDown(() => database.close());

  test('AC-F-001..008,010,011,015,018: link is bidirectional, idempotent, '
      'factual, offline, and status-independent', () async {
    expect(await _create(links), TaskEventLinkMutationOutcome.changed);
    expect(await _create(links), TaskEventLinkMutationOutcome.unchanged);
    final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: date,
    );
    expect(
      await links.readLinkedTaskIds(
        eventId: eventId,
        occurrenceId: occurrenceId,
      ),
      <String>[taskId],
    );
    expect((await links.readContext(taskId)).linkedEventIds, <String>[eventId]);
    final view = (await links.readForTask(
      profileId: profileId,
      taskId: taskId,
    )).single;
    expect(view.link.canonicalRecordId, taskId);
    expect(view.link.scheduledPotentialExplanation, contains('nothing'));
    expect(
      (await database.select(database.plannerTasks).get()).single.status,
      'incomplete',
    );
    expect(
      (await database.select(database.calendarEvents).get()).single.status,
      'scheduled',
    );
    expect(
      await database.select(database.taskEventLinkHistory).get(),
      hasLength(1),
    );
  });

  test('AC-F-009,012,013: unlink is explicit and reversible without deleting '
      'Task or Event', () async {
    await _create(links);
    await links.removeLink(
      profileId: profileId,
      linkId: linkId,
      operationId: '50000000-0000-4000-8000-000000000002',
    );
    expect(await database.select(database.plannerTasks).get(), hasLength(1));
    expect(await database.select(database.calendarEvents).get(), hasLength(1));
    await links.createLink(
      profileId: profileId,
      draft: const TaskEventLinkDraft(
        id: linkId,
        taskId: taskId,
        eventId: eventId,
        scope: TaskEventLinkScope.series,
        canonicalSource: TaskEventCanonicalSource.event,
      ),
      operationId: '50000000-0000-4000-8000-000000000003',
    );
    final rows = await database.select(database.taskEventLinks).get();
    expect(rows, hasLength(1));
    expect(rows.single.status, 'active');
    expect(rows.single.canonicalSource, 'event');
    expect(
      await database.select(database.taskEventLinkHistory).get(),
      hasLength(3),
    );
  });

  test('AC-F-014 / OPD-2-002: occurrence override does not corrupt future '
      'series occurrences', () async {
    await _create(links);
    final first = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: date,
    );
    final later = CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: date.addDays(7),
    );
    await links.removeLink(
      profileId: profileId,
      linkId: linkId,
      operationId: '50000000-0000-4000-8000-000000000004',
      occurrenceOverrideId: first,
      occurrenceOverrideDate: date,
    );
    expect(
      await links.readLinkedTaskIds(eventId: eventId, occurrenceId: first),
      isEmpty,
    );
    expect(
      await links.readLinkedTaskIds(eventId: eventId, occurrenceId: later),
      <String>[taskId],
    );
  });

  test('AC-F-016,017: broken reference remains recoverable without title '
      'inference', () async {
    await _create(links);
    await (database.delete(
      database.calendarEvents,
    )..where((table) => table.id.equals(eventId))).go();
    final broken = (await links.readForTask(
      profileId: profileId,
      taskId: taskId,
    )).single;
    expect(broken.isBroken, isTrue);
    expect(broken.eventTitle, 'Missing Calendar Event');
    const replacementId = '30000000-0000-4000-8000-000000000002';
    await _insertEvent(database, replacementId);
    await links.repairLink(
      profileId: profileId,
      linkId: linkId,
      taskId: taskId,
      eventId: replacementId,
      operationId: '50000000-0000-4000-8000-000000000005',
    );
    final repaired = (await links.readForTask(
      profileId: profileId,
      taskId: taskId,
    )).single;
    expect(repaired.isBroken, isFalse);
    expect(repaired.link.eventId, replacementId);
  });

  test('BR-F-004,007,009,010: reschedule transfers occurrence context in the '
      'same transaction and preserves history', () async {
    await _create(links);
    final calendar = DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 1, 12)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      taskContextSource: links,
      linkContextTransfer: links,
    );
    const replacementId = '30000000-0000-4000-8000-000000000003';
    await calendar.rescheduleEvent(
      profileId: profileId,
      eventId: eventId,
      originalDate: date,
      scope: CalendarEventEditScope.occurrence,
      replacement: _draft(replacementId),
      operationId: '50000000-0000-4000-8000-000000000006',
    );
    expect(
      await links.readLinkedTaskIds(
        eventId: replacementId,
        occurrenceId: CalendarEventOccurrenceIdentity.forDate(
          eventId: replacementId,
          originalDate: date,
        ),
      ),
      <String>[taskId],
    );
    expect(
      await database.select(database.taskEventLinkHistory).get(),
      isNotEmpty,
    );
  });

  test('AC-F-018 / BR-F-010: failed create-from-task rolls back Event, link, '
      'and history together', () async {
    final failingLinks = DriftTaskEventLinkRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 1, 12)),
      writeGuard: const _FailingLinkWriteGuard(),
    );
    final coordinator = DriftTaskEventLinkCoordinator(
      database: database,
      calendarEvents: DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 1, 12)),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      ),
      links: failingLinks,
    );
    const newEventId = '30000000-0000-4000-8000-000000000004';
    await expectLater(
      coordinator.createEventFromTask(
        profileId: profileId,
        taskId: taskId,
        event: _draft(newEventId),
        linkId: '40000000-0000-4000-8000-000000000004',
        operationId: '50000000-0000-4000-8000-000000000007',
        canonicalSource: TaskEventCanonicalSource.task,
      ),
      throwsStateError,
    );
    expect(
      await (database.select(
        database.calendarEvents,
      )..where((table) => table.id.equals(newEventId))).get(),
      isEmpty,
    );
    expect(await database.select(database.taskEventLinks).get(), isEmpty);
    expect(await database.select(database.taskEventLinkHistory).get(), isEmpty);
  });
}

Future<void> _seed(AppDatabase database) async {
  final now = DateTime.utc(2026, 8, 1);
  await database
      .into(database.localProfiles)
      .insert(
        LocalProfilesCompanion.insert(
          id: '10000000-0000-4000-8000-000000000001',
          localName: 'Local Profile',
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await database
      .into(database.plannerTasks)
      .insert(
        PlannerTasksCompanion.insert(
          id: '20000000-0000-4000-8000-000000000001',
          profileId: '10000000-0000-4000-8000-000000000001',
          title: 'Prepare visit',
          dueDate: const Value<String>('2026-08-02'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
  await _insertEvent(database, '30000000-0000-4000-8000-000000000001');
}

Future<void> _insertEvent(AppDatabase database, String id) {
  final now = DateTime.utc(2026, 8, 1);
  return database
      .into(database.calendarEvents)
      .insert(
        CalendarEventsCompanion.insert(
          id: id,
          profileId: '10000000-0000-4000-8000-000000000001',
          title: 'Visit',
          timing: CalendarEventTiming.allDay.name,
          startDate: '2026-08-02',
          recurrenceFrequency: const Value<String>('weekly'),
          createdAtUtc: now,
          updatedAtUtc: now,
        ),
      );
}

CalendarEventDraft _draft(String id) => CalendarEventDraft(
  id: id,
  title: 'Replacement',
  timing: CalendarEventTiming.allDay,
  startDate: const PlannerDate(year: 2026, month: 8, day: 2),
  requiresReport: false,
);

Future<TaskEventLinkMutationOutcome> _create(
  DriftTaskEventLinkRepository links,
) {
  return links.createLink(
    profileId: '10000000-0000-4000-8000-000000000001',
    draft: const TaskEventLinkDraft(
      id: '40000000-0000-4000-8000-000000000001',
      taskId: '20000000-0000-4000-8000-000000000001',
      eventId: '30000000-0000-4000-8000-000000000001',
      scope: TaskEventLinkScope.series,
      canonicalSource: TaskEventCanonicalSource.task,
    ),
    operationId: '50000000-0000-4000-8000-000000000001',
  );
}

final class _FailingLinkWriteGuard implements TaskEventLinkWriteGuard {
  const _FailingLinkWriteGuard();

  @override
  Future<void> beforeCommit() async {
    throw StateError('Injected Task-Event link failure');
  }
}
