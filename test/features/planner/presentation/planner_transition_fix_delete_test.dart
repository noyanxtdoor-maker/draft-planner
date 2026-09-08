import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../../../support/test_dependencies.dart';

const _today = PlannerDate(year: 2026, month: 8, day: 11);
const _next = PlannerDate(year: 2026, month: 8, day: 12);
const _far = PlannerDate(year: 2026, month: 8, day: 25);
const _seriesId = '11111111-aaaa-4aaa-8aaa-111111111111';
const _independentId = '22222222-bbbb-4bbb-8bbb-222222222222';
const _survivorId = '33333333-cccc-4ccc-8ccc-333333333333';

PlannerCalendarItem _event({
  required String eventId,
  required PlannerDate date,
  int startMinute = 9 * 60,
}) {
  return PlannerCalendarItem(
    id: CalendarEventOccurrenceIdentity.forDate(
      eventId: eventId,
      originalDate: date,
    ),
    eventId: eventId,
    originalDate: date,
    title: 'Event $eventId',
    date: date,
    timing: PlannerEventTiming.timed,
    state: PlannerEventState.scheduled,
    requiresReport: false,
    hasOutcomeReport: false,
    startLocal: DateTime(
      date.year,
      date.month,
      date.day,
      startMinute ~/ 60,
      startMinute % 60,
    ),
    endLocal: DateTime(
      date.year,
      date.month,
      date.day,
      (startMinute + 60) ~/ 60,
      (startMinute + 60) % 60,
    ),
    isRecurring: eventId == _seriesId,
  );
}

PlannerDay _day(PlannerDate date, Iterable<PlannerCalendarItem> events) {
  return PlannerDay(
    selectedDate: date,
    allDayEvents: const <PlannerCalendarItem>[],
    timedEvents: events.toList(growable: false),
    tasks: const <PlannerTask>[],
    overdueTasks: const <PlannerTask>[],
    completedTasks: const <PlannerTask>[],
    awaitingReportEvents: const <PlannerCalendarItem>[],
    changes: const <PlannerChangeItem>[],
  );
}

/// Records every canonical [readDay] per date so tests can assert the EXACT
/// date set a deletion confirmation re-reads — not just call counts.
final class _RecordingPlannerRepository implements PlannerRepository {
  _RecordingPlannerRepository(Map<PlannerDate, PlannerDay> initialDays)
    : days = <PlannerDate, PlannerDay>{...initialDays};

  final Map<PlannerDate, PlannerDay> days;
  final Map<PlannerDate, List<Future<PlannerDay>>> _queuedReads =
      <PlannerDate, List<Future<PlannerDay>>>{};
  final Map<PlannerDate, int> readCounts = <PlannerDate, int>{};

  void queueRead(PlannerDate date, Future<PlannerDay> read) {
    _queuedReads.putIfAbsent(date, () => <Future<PlannerDay>>[]).add(read);
  }

  @override
  Future<PlannerDay> readDay({
    required String profileId,
    required PlannerDate selectedDate,
    required PlannerDate today,
  }) {
    readCounts[selectedDate] = (readCounts[selectedDate] ?? 0) + 1;
    final queued = _queuedReads[selectedDate];
    if (queued != null && queued.isNotEmpty) {
      return queued.removeAt(0);
    }
    return Future<PlannerDay>.value(
      days[selectedDate] ?? _day(selectedDate, const <PlannerCalendarItem>[]),
    );
  }

  @override
  Future<PlannerTask?> readTask({
    required String profileId,
    required String taskId,
  }) async => null;

  @override
  Future<PlannerTask> saveTask({
    required String profileId,
    required PlannerTaskDraft draft,
    bool confirmLinkedTypeTransfer = false,
  }) {
    throw UnimplementedError('delete tests do not save Tasks');
  }

  @override
  Future<TaskStatusChangeOutcome> changeTaskStatus({
    required String profileId,
    required String taskId,
    required PlannerTaskStatus target,
    required String operationId,
    String? reason,
    bool confirmLinkedTypeTransfer = false,
  }) {
    throw UnimplementedError('delete tests do not change Tasks');
  }

  @override
  Future<TaskHardDeleteOutcome> hardDeleteTask({
    required String profileId,
    required String taskId,
  }) async => TaskHardDeleteOutcome.notFound;
}

final class _UnusedCalendarRepository implements CalendarEventRepository {
  @override
  String get displayTimeZoneId => 'Asia/Manila';

  @override
  bool isValidTimeZone(String timeZoneId) => true;

  @override
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  }) async => const <PlannerCalendarItem>[];

  @override
  Future<CalendarEventDraft?> readEventDraft({
    required String profileId,
    required String eventId,
  }) async => null;

  @override
  Future<CalendarEventOccurrence?> readOccurrence({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
  }) async => null;

  @override
  Future<CalendarEventDraft> saveEvent({
    required String profileId,
    required CalendarEventDraft draft,
  }) {
    throw UnimplementedError('delete tests do not save Events');
  }

  @override
  Future<CalendarEventMutationOutcome> editEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft draft,
    required String operationId,
  }) {
    throw UnimplementedError('delete tests do not edit Events');
  }

  @override
  Future<CalendarEventMutationOutcome> cancelEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
  }) {
    throw UnimplementedError('delete tests cancel through the Planner path');
  }

  @override
  Future<CalendarEventMutationOutcome> rescheduleEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required CalendarEventDraft replacement,
    required String operationId,
  }) {
    throw UnimplementedError('delete tests do not reschedule Events');
  }

  @override
  Future<CalendarEventMutationOutcome> duplicateEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required String duplicateId,
    required String operationId,
  }) {
    throw UnimplementedError('delete tests do not duplicate Events');
  }
}

Future<ProviderContainer> _pumpPlanner(
  WidgetTester tester, {
  required _RecordingPlannerRepository plannerRepository,
}) async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();
  tester.view.physicalSize = const Size(862, 1824);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
      plannerRepository: plannerRepository,
      calendarEventRepository: _UnusedCalendarRepository(),
      plannerDateSource: const FixedPlannerDateSource(_today),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp).first),
  );
}

Map<PlannerDate, int> _snapshot(_RecordingPlannerRepository repository) {
  return Map<PlannerDate, int>.of(repository.readCounts);
}

void main() {
  testWidgets(
    'occurrence confirmation re-reads exactly the original date, not every '
    'cached day',
    (tester) async {
      try {
        final seriesNext = _event(eventId: _seriesId, date: _next);
        final survivorFar = _event(eventId: _survivorId, date: _far);
        final repository = _RecordingPlannerRepository(
          <PlannerDate, PlannerDay>{
            _today: _day(_today, const <PlannerCalendarItem>[]),
            _next: _day(_next, <PlannerCalendarItem>[seriesNext]),
            _far: _day(_far, <PlannerCalendarItem>[survivorFar]),
          },
        );
        final container = await _pumpPlanner(
          tester,
          plannerRepository: repository,
        );
        final planner = container.read(plannerControllerProvider.notifier);

        // Seed the canonical cache with two extra days so the OLD broad
        // confirmation would have to re-read them.
        await planner.readDays(const <PlannerDate>[_next, _far]);
        await tester.pumpAndSettle();
        final before = _snapshot(repository);

        final targets = PlannerEventDeletionTargetSet.occurrence(
          eventId: _seriesId,
          originalDate: _next,
        );
        planner.beginPendingEventDeletion(targets);
        // The occurrence's own day no longer contains it.
        repository.days[_next] = _day(_next, const <PlannerCalendarItem>[]);
        expect(await planner.confirmPendingEventDeletion(targets), isTrue);

        final after = repository.readCounts;
        expect(
          (after[_next] ?? 0) - (before[_next] ?? 0),
          1,
          reason: 'the confirmation re-reads the original date exactly once',
        );
        expect(
          (after[_far] ?? 0) - (before[_far] ?? 0),
          0,
          reason:
              'an occurrence confirmation must NOT re-read every cached day',
        );
        expect(
          (after[_today] ?? 0) - (before[_today] ?? 0),
          0,
          reason:
              'an occurrence confirmation must NOT re-read the selected day',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'a still-visible occurrence on the narrow original date still rolls back '
    'the tombstone',
    (tester) async {
      try {
        final seriesNext = _event(eventId: _seriesId, date: _next);
        final repository = _RecordingPlannerRepository(
          <PlannerDate, PlannerDay>{
            _today: _day(_today, const <PlannerCalendarItem>[]),
            _next: _day(_next, <PlannerCalendarItem>[seriesNext]),
          },
        );
        final container = await _pumpPlanner(
          tester,
          plannerRepository: repository,
        );
        final planner = container.read(plannerControllerProvider.notifier);
        await planner.readDays(const <PlannerDate>[_next]);
        await tester.pumpAndSettle();

        final targets = PlannerEventDeletionTargetSet.occurrence(
          eventId: _seriesId,
          originalDate: _next,
        );
        planner.beginPendingEventDeletion(targets);
        // The day still contains the target: canonical absence is NOT proven.
        expect(await planner.confirmPendingEventDeletion(targets), isFalse);
        expect(
          planner.isPendingEventDeletion(seriesNext),
          isFalse,
          reason: 'the tombstone rolls back when the target is still visible',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'legacy/manual target constructors keep the OLD broad confirmation read '
    'set',
    (tester) async {
      try {
        final independentNext = _event(eventId: _independentId, date: _next);
        final survivorFar = _event(eventId: _survivorId, date: _far);
        final repository = _RecordingPlannerRepository(
          <PlannerDate, PlannerDay>{
            _today: _day(_today, const <PlannerCalendarItem>[]),
            _next: _day(_next, <PlannerCalendarItem>[independentNext]),
            _far: _day(_far, <PlannerCalendarItem>[survivorFar]),
          },
        );
        final container = await _pumpPlanner(
          tester,
          plannerRepository: repository,
        );
        final planner = container.read(plannerControllerProvider.notifier);
        await planner.readDays(const <PlannerDate>[_next, _far]);
        await tester.pumpAndSettle();
        final before = _snapshot(repository);

        final targets = PlannerEventDeletionTargetSet(
          occurrenceIds: <String>{independentNext.id},
        );
        planner.beginPendingEventDeletion(targets);
        repository.days[_next] = _day(_next, const <PlannerCalendarItem>[]);
        expect(await planner.confirmPendingEventDeletion(targets), isTrue);

        final after = repository.readCounts;
        expect(
          (after[_next] ?? 0) - (before[_next] ?? 0),
          1,
          reason: 'the original date is re-read',
        );
        expect(
          (after[_far] ?? 0) - (before[_far] ?? 0),
          1,
          reason: 'manual occurrenceIds targets keep broad confirmation',
        );
        expect(
          (after[_today] ?? 0) - (before[_today] ?? 0),
          1,
          reason: 'manual occurrenceIds targets keep the selected-day read',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'series confirmation stays broad across the selected day and every '
    'cached day',
    (tester) async {
      try {
        final seriesToday = _event(eventId: _seriesId, date: _today);
        final seriesFar = _event(eventId: _seriesId, date: _far);
        final repository = _RecordingPlannerRepository(
          <PlannerDate, PlannerDay>{
            _today: _day(_today, <PlannerCalendarItem>[seriesToday]),
            _next: _day(_next, const <PlannerCalendarItem>[]),
            _far: _day(_far, <PlannerCalendarItem>[seriesFar]),
          },
        );
        final container = await _pumpPlanner(
          tester,
          plannerRepository: repository,
        );
        final planner = container.read(plannerControllerProvider.notifier);
        await planner.readDays(const <PlannerDate>[_next, _far]);
        await tester.pumpAndSettle();
        final before = _snapshot(repository);

        final targets = PlannerEventDeletionTargetSet.series(_seriesId);
        planner.beginPendingEventDeletion(targets);
        repository.days[_today] = _day(_today, const <PlannerCalendarItem>[]);
        repository.days[_far] = _day(_far, const <PlannerCalendarItem>[]);
        expect(await planner.confirmPendingEventDeletion(targets), isTrue);

        final after = repository.readCounts;
        expect(
          (after[_today] ?? 0) - (before[_today] ?? 0),
          1,
          reason: 'series confirmation re-reads the selected day',
        );
        expect(
          (after[_next] ?? 0) - (before[_next] ?? 0),
          1,
          reason: 'series confirmation re-reads every cached day',
        );
        expect(
          (after[_far] ?? 0) - (before[_far] ?? 0),
          1,
          reason: 'series confirmation re-reads every cached day',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
