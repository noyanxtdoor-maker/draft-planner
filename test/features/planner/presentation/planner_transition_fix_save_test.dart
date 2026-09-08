import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
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
    throw UnimplementedError('save tests do not save Tasks');
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
    throw UnimplementedError('save tests do not change Tasks');
  }

  @override
  Future<TaskHardDeleteOutcome> hardDeleteTask({
    required String profileId,
    required String taskId,
  }) async => TaskHardDeleteOutcome.notFound;
}

final class _ControlledCalendarRepository implements CalendarEventRepository {
  Completer<CalendarEventMutationOutcome>? editCompleter;
  Object? editError;

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
    throw UnimplementedError('save tests do not create Events');
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
    final error = editError;
    if (error != null) {
      return Future<CalendarEventMutationOutcome>.error(error);
    }
    final completer = editCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future<CalendarEventMutationOutcome>.value(
      CalendarEventMutationOutcome.changed,
    );
  }

  @override
  Future<CalendarEventMutationOutcome> cancelEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
  }) {
    throw UnimplementedError('save tests do not cancel Events');
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
    throw UnimplementedError('save tests do not reschedule Events');
  }

  @override
  Future<CalendarEventMutationOutcome> duplicateEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required String duplicateId,
    required String operationId,
  }) {
    throw UnimplementedError('save tests do not duplicate Events');
  }
}

CalendarEventDraft _draft({String? title}) {
  return CalendarEventDraft(
    id: _independentId,
    title: title ?? 'Edited Event',
    timing: CalendarEventTiming.timed,
    startDate: _today,
    requiresReport: false,
  );
}

Future<ProviderContainer> _pumpPlanner(
  WidgetTester tester, {
  required _RecordingPlannerRepository plannerRepository,
  required _ControlledCalendarRepository calendarEventRepository,
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
      calendarEventRepository: calendarEventRepository,
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

void main() {
  testWidgets('normal Edit save completes its durable result while the Planner '
      'refresh is still pending', (tester) async {
    try {
      final event = _event(eventId: _independentId, date: _today);
      final repository = _RecordingPlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[event]),
      });
      final calendarRepository = _ControlledCalendarRepository();
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
        calendarEventRepository: calendarRepository,
      );
      final controller = container.read(
        calendarEventControllerProvider.notifier,
      );

      // Hold the selected-day canonical refresh so we can observe the save
      // completing BEFORE it.
      final heldRefresh = Completer<PlannerDay>();
      repository.queueRead(_today, heldRefresh.future);
      final readsBefore = repository.readCounts[_today] ?? 0;

      var completed = false;
      final edit = controller.editEvent(
        eventId: _independentId,
        originalDate: _today,
        scope: CalendarEventEditScope.occurrence,
        draft: _draft(title: 'Edited Event'),
        operationId: '44444444-dddd-4ddd-8ddd-444444444444',
        awaitPlannerRefresh: false,
      );
      unawaited(edit.then((value) => completed = value));
      await tester.pump();

      expect(
        completed,
        isTrue,
        reason: 'the durable write must not wait on the background refresh',
      );
      expect(
        repository.readCounts[_today] ?? 0,
        readsBefore + 1,
        reason:
            'the background refresh was issued (held read consumed) but '
            'is still in flight',
      );
      expect(container.read(calendarEventControllerProvider), isNull);

      // Completing the refresh converges the Planner on the edited day.
      final edited = _day(_today, <PlannerCalendarItem>[event]);
      repository.days[_today] = edited;
      heldRefresh.complete(edited);
      await tester.pumpAndSettle();
      expect(await edit, isTrue);
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        <PlannerCalendarItem>[event],
        reason: 'the background refresh still updates the Planner',
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'default Edit semantics still await the Planner refresh before the '
    'mutation completes',
    (tester) async {
      try {
        final event = _event(eventId: _independentId, date: _today);
        final repository = _RecordingPlannerRepository(
          <PlannerDate, PlannerDay>{
            _today: _day(_today, <PlannerCalendarItem>[event]),
          },
        );
        final calendarRepository = _ControlledCalendarRepository();
        final container = await _pumpPlanner(
          tester,
          plannerRepository: repository,
          calendarEventRepository: calendarRepository,
        );
        final controller = container.read(
          calendarEventControllerProvider.notifier,
        );

        final heldRefresh = Completer<PlannerDay>();
        repository.queueRead(_today, heldRefresh.future);

        var completed = false;
        final edit = controller.editEvent(
          eventId: _independentId,
          originalDate: _today,
          scope: CalendarEventEditScope.occurrence,
          draft: _draft(title: 'Edited Event'),
          operationId: '44444444-dddd-4ddd-8ddd-444444444444',
        );
        unawaited(edit.then((value) => completed = value));
        await tester.pump();

        expect(
          completed,
          isFalse,
          reason: 'default callers keep the awaited refresh semantics',
        );
        final edited = _day(_today, <PlannerCalendarItem>[event]);
        repository.days[_today] = edited;
        heldRefresh.complete(edited);
        await tester.pumpAndSettle();
        expect(await edit, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('a failed durable Edit still reports failure and never looks '
      'successful', (tester) async {
    try {
      final event = _event(eventId: _independentId, date: _today);
      final repository = _RecordingPlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[event]),
      });
      final calendarRepository = _ControlledCalendarRepository()
        ..editError = const CalendarEventValidationException(
          'controlled validation failure',
        );
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
        calendarEventRepository: calendarRepository,
      );
      final controller = container.read(
        calendarEventControllerProvider.notifier,
      );
      final readsBefore = repository.readCounts[_today] ?? 0;

      final saved = await controller.editEvent(
        eventId: _independentId,
        originalDate: _today,
        scope: CalendarEventEditScope.occurrence,
        draft: _draft(title: 'Edited Event'),
        operationId: '44444444-dddd-4ddd-8ddd-444444444444',
        awaitPlannerRefresh: false,
      );
      expect(saved, isFalse);
      expect(
        container.read(calendarEventControllerProvider),
        'controlled validation failure',
      );
      expect(
        repository.readCounts[_today] ?? 0,
        readsBefore,
        reason: 'a failed write must not trigger a Planner refresh',
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('thisAndFuture hides the clicked occurrence but keeps broad '
      'confirmation', (tester) async {
    try {
      final seriesNext = _event(eventId: _seriesId, date: _next);
      final survivorFar = _event(eventId: _survivorId, date: _far);
      final repository = _RecordingPlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, const <PlannerCalendarItem>[]),
        _next: _day(_next, <PlannerCalendarItem>[seriesNext]),
        _far: _day(_far, <PlannerCalendarItem>[survivorFar]),
      });
      final calendarRepository = _ControlledCalendarRepository();
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
        calendarEventRepository: calendarRepository,
      );
      final planner = container.read(plannerControllerProvider.notifier);
      await planner.readDays(const <PlannerDate>[_next, _far]);
      await tester.pumpAndSettle();
      final before = Map<PlannerDate, int>.of(repository.readCounts);

      final targets = PlannerEventDeletionTargetSet.thisAndFuture(
        eventId: _seriesId,
        originalDate: _next,
      );
      expect(
        targets.occurrenceIds,
        contains(
          CalendarEventOccurrenceIdentity.forDate(
            eventId: _seriesId,
            originalDate: _next,
          ),
        ),
        reason: 'thisAndFuture still hides the clicked occurrence',
      );
      expect(
        targets.confirmAllCachedDays,
        isTrue,
        reason: 'thisAndFuture must never narrow its confirmation',
      );
      planner.beginPendingEventDeletion(targets);
      repository.days[_next] = _day(_next, const <PlannerCalendarItem>[]);
      expect(await planner.confirmPendingEventDeletion(targets), isTrue);

      final after = repository.readCounts;
      expect(
        (after[_next] ?? 0) - (before[_next] ?? 0),
        1,
        reason: 'thisAndFuture re-reads the original date',
      );
      expect(
        (after[_far] ?? 0) - (before[_far] ?? 0),
        1,
        reason: 'thisAndFuture keeps the broad cached-day read set',
      );
      expect(
        (after[_today] ?? 0) - (before[_today] ?? 0),
        1,
        reason: 'thisAndFuture keeps the selected-day read',
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
