import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:uuid/uuid.dart';

import '../../../support/test_dependencies.dart';

const _eventId = '11111111-1111-4111-8111-111111111111';
const _replacementId = '33333333-3333-4333-8333-333333333333';
const _operationId = '22222222-2222-4222-8222-222222222222';
const _secondOperationId = '44444444-4444-4444-8444-444444444444';
const _start = PlannerDate(year: 2026, month: 1, day: 31);

void main() {
  late AppDatabase database;
  late String profileId;
  late IanaCalendarEventTimeZones timeZones;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(
      database: database,
    ).completeOnboarding()).id;
    timeZones = IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila');
  });

  tearDown(() => database.close());

  DriftCalendarEventRepository buildRepository({
    CalendarEventReportSource reportSource =
        const EmptyCalendarEventReportSource(),
    CalendarEventTaskContextSource taskSource =
        const EmptyCalendarEventTaskContextSource(),
    CalendarEventWriteGuard writeGuard = const AllowCalendarEventWrites(),
  }) {
    return DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 2, 2, 12)),
      timeZones: timeZones,
      reportSource: reportSource,
      taskContextSource: taskSource,
      writeGuard: writeGuard,
    );
  }

  test(
    'AC-E-001..010,014,020: offline all-day recurrence stays date-only',
    () async {
      final repository = buildRepository();
      final saved = await repository.saveEvent(
        profileId: profileId,
        draft: _allDayDraft(),
      );

      final february = await repository.readDay(
        profileId: profileId,
        date: const PlannerDate(year: 2026, month: 2, day: 28),
      );

      expect(saved.title, 'Month-end visit');
      expect(february, hasLength(1));
      expect(february.single.timing, PlannerEventTiming.allDay);
      expect(february.single.date.iso8601, '2026-02-28');
      expect(february.single.startUtc, isNull);
      expect(february.single.timeZoneId, isNull);
      expect(february.single.locationText, 'Typed local location');
    },
  );

  test(
    'AC-E-011,012,020: timed event retains origin IANA zone and converts',
    () async {
      final repository = buildRepository();
      await repository.saveEvent(
        profileId: profileId,
        draft: const CalendarEventDraft(
          id: _eventId,
          title: 'Origin-zone meeting',
          timing: CalendarEventTiming.timed,
          startDate: PlannerDate(year: 2026, month: 7, day: 28),
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          timeZoneId: 'America/New_York',
          requiresReport: false,
        ),
      );

      final occurrence = await repository.readOccurrence(
        profileId: profileId,
        eventId: _eventId,
        originalDate: const PlannerDate(year: 2026, month: 7, day: 28),
      );

      expect(occurrence!.timeZoneId, 'America/New_York');
      expect(occurrence.displayTimeZoneId, 'Asia/Manila');
      expect(occurrence.startUtc, DateTime.utc(2026, 7, 28, 13));
      expect(occurrence.startDisplay, DateTime(2026, 7, 28, 21));
    },
  );

  test(
    'AC-E-013,015,016,019,024: cancellation is scoped and retry-idempotent',
    () async {
      final repository = buildRepository();
      await repository.saveEvent(profileId: profileId, draft: _allDayDraft());

      final first = await repository.cancelEvent(
        profileId: profileId,
        eventId: _eventId,
        originalDate: const PlannerDate(year: 2026, month: 2, day: 28),
        scope: CalendarEventEditScope.occurrence,
        operationId: _operationId,
      );
      final retry = await repository.cancelEvent(
        profileId: profileId,
        eventId: _eventId,
        originalDate: const PlannerDate(year: 2026, month: 2, day: 28),
        scope: CalendarEventEditScope.occurrence,
        operationId: _operationId,
      );
      final occurrence = await repository.readOccurrence(
        profileId: profileId,
        eventId: _eventId,
        originalDate: const PlannerDate(year: 2026, month: 2, day: 28),
      );
      final exceptions = await database
          .select(database.calendarEventExceptions)
          .get();

      expect(first, CalendarEventMutationOutcome.changed);
      expect(retry, CalendarEventMutationOutcome.unchanged);
      expect(occurrence!.status, CalendarEventStatus.cancelled);
      expect(exceptions, hasLength(1));
      expect(Uuid.isValidUUID(fromString: exceptions.single.id), isTrue);
    },
  );

  test(
    'AC-E-015,016,022: reschedule preserves original and replacement link',
    () async {
      final repository = buildRepository();
      await repository.saveEvent(profileId: profileId, draft: _allDayDraft());

      await repository.rescheduleEvent(
        profileId: profileId,
        eventId: _eventId,
        originalDate: _start,
        scope: CalendarEventEditScope.occurrence,
        replacement: const CalendarEventDraft(
          id: _replacementId,
          title: 'Replacement',
          timing: CalendarEventTiming.allDay,
          startDate: PlannerDate(year: 2026, month: 2, day: 1),
          requiresReport: false,
        ),
        operationId: _operationId,
      );

      final original = await repository.readOccurrence(
        profileId: profileId,
        eventId: _eventId,
        originalDate: _start,
      );
      final replacement = await repository.readOccurrence(
        profileId: profileId,
        eventId: _replacementId,
        originalDate: const PlannerDate(year: 2026, month: 2, day: 1),
      );

      expect(original!.status, CalendarEventStatus.rescheduled);
      expect(original.replacementEventId, _replacementId);
      expect(replacement!.title, 'Replacement');
    },
  );

  test(
    'AC-E-017,018,021,023: reports are factual and reported history is immutable',
    () async {
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: _eventId,
        originalDate: _start,
      );
      final reports = _MemoryReportSource(<CalendarEventReportSnapshot>[
        CalendarEventReportSnapshot(
          occurrenceId: occurrenceId,
          originalDate: _start,
          status: CalendarEventStatus.partiallyCompleted,
        ),
      ]);
      final repository = buildRepository(
        reportSource: reports,
        taskSource: const _TaskLinks(<String>['task-one']),
      );
      await repository.saveEvent(profileId: profileId, draft: _allDayDraft());

      final occurrence = await repository.readOccurrence(
        profileId: profileId,
        eventId: _eventId,
        originalDate: _start,
      );
      expect(occurrence!.status, CalendarEventStatus.partiallyCompleted);
      expect(occurrence.linkedTaskIds, <String>['task-one']);

      await expectLater(
        repository.editEvent(
          profileId: profileId,
          eventId: _eventId,
          originalDate: _start,
          scope: CalendarEventEditScope.series,
          draft: _allDayDraft(title: 'Must not overwrite history'),
          operationId: _secondOperationId,
        ),
        throwsA(isA<CalendarEventValidationException>()),
      );
    },
  );

  test(
    'AC-E-015,023: series cancellation preserves an earlier report snapshot',
    () async {
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: _eventId,
        originalDate: _start,
      );
      final repository = buildRepository(
        reportSource: _MemoryReportSource(<CalendarEventReportSnapshot>[
          CalendarEventReportSnapshot(
            occurrenceId: occurrenceId,
            originalDate: _start,
            status: CalendarEventStatus.completedHappened,
          ),
        ]),
      );
      await repository.saveEvent(profileId: profileId, draft: _allDayDraft());

      await repository.cancelEvent(
        profileId: profileId,
        eventId: _eventId,
        originalDate: const PlannerDate(year: 2026, month: 2, day: 28),
        scope: CalendarEventEditScope.series,
        operationId: _secondOperationId,
      );

      final reported = await repository.readOccurrence(
        profileId: profileId,
        eventId: _eventId,
        originalDate: _start,
      );
      final cancelled = await repository.readOccurrence(
        profileId: profileId,
        eventId: _eventId,
        originalDate: const PlannerDate(year: 2026, month: 2, day: 28),
      );

      expect(reported!.status, CalendarEventStatus.completedHappened);
      expect(cancelled!.status, CalendarEventStatus.cancelled);
    },
  );

  test(
    'AC-E-024 / BR-E-010: injected failure rolls back the full mutation',
    () async {
      final repository = buildRepository(
        writeGuard: const _FailingWriteGuard(),
      );

      await expectLater(
        repository.saveEvent(profileId: profileId, draft: _allDayDraft()),
        throwsA(isA<StateError>()),
      );

      expect(await database.select(database.calendarEvents).get(), isEmpty);
    },
  );

  test(
    'VS08-OWNER: backup identity and provenance survive an ordinary edit',
    () async {
      final repository = buildRepository();
      await repository.saveEvent(
        profileId: profileId,
        draft: const CalendarEventDraft(
          id: _eventId,
          title: 'Backup visit',
          timing: CalendarEventTiming.allDay,
          startDate: _start,
          requiresReport: false,
          isBackupAppointment: true,
          backupForEventId: _replacementId,
          backupRelationshipProvenance: 'user-classified',
        ),
      );
      final existing = await repository.readEventDraft(
        profileId: profileId,
        eventId: _eventId,
      );
      await repository.editEvent(
        profileId: profileId,
        eventId: _eventId,
        originalDate: _start,
        scope: CalendarEventEditScope.series,
        draft: existing!.copyWith(title: 'Edited backup visit'),
        operationId: _operationId,
      );

      final row = (await database.select(database.calendarEvents).get()).single;
      expect(row.isBackupAppointment, isTrue);
      expect(row.backupForEventId, _replacementId);
      expect(row.backupRelationshipProvenance, 'user-classified');

      final normalized = existing
          .copyWith(isBackupAppointment: false)
          .normalized();
      expect(normalized.backupForEventId, isNull);
      expect(normalized.backupRelationshipProvenance, isNull);
    },
  );
}

CalendarEventDraft _allDayDraft({String title = 'Month-end visit'}) {
  return CalendarEventDraft(
    id: _eventId,
    title: title,
    timing: CalendarEventTiming.allDay,
    startDate: _start,
    locationText: 'Typed local location',
    requiresReport: true,
    recurrence: const CalendarRecurrenceRule(
      frequency: CalendarRecurrenceFrequency.monthly,
    ),
  );
}

final class _MemoryReportSource implements CalendarEventReportSource {
  const _MemoryReportSource(this.reports);

  final List<CalendarEventReportSnapshot> reports;

  @override
  Future<List<CalendarEventReportSnapshot>> readSeriesReports(
    String eventId,
  ) async {
    return eventId == _eventId
        ? reports
        : const <CalendarEventReportSnapshot>[];
  }
}

final class _TaskLinks implements CalendarEventTaskContextSource {
  const _TaskLinks(this.ids);

  final List<String> ids;

  @override
  Future<List<String>> readLinkedTaskIds({
    required String eventId,
    required String occurrenceId,
  }) async => ids;
}

final class _FailingWriteGuard implements CalendarEventWriteGuard {
  const _FailingWriteGuard();

  @override
  Future<void> beforeCommit() async {
    throw StateError('Injected Calendar Event write failure');
  }
}
