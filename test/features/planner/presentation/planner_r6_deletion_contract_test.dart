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

final class _MutablePlannerRepository implements PlannerRepository {
  _MutablePlannerRepository(Map<PlannerDate, PlannerDay> initialDays)
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
    throw UnimplementedError('R6 deletion tests do not save Tasks');
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
    throw UnimplementedError('R6 deletion tests do not change Tasks');
  }

  @override
  Future<TaskHardDeleteOutcome> hardDeleteTask({
    required String profileId,
    required String taskId,
  }) async => TaskHardDeleteOutcome.notFound;
}

final class _ControlledCancelCalendarRepository
    implements CalendarEventRepository {
  final Completer<CalendarEventMutationOutcome> cancelCompleter =
      Completer<CalendarEventMutationOutcome>();
  CalendarEventOccurrence? canonicalOccurrence;

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
  }) async => canonicalOccurrence;

  @override
  Future<CalendarEventDraft> saveEvent({
    required String profileId,
    required CalendarEventDraft draft,
  }) {
    throw UnimplementedError('R6 deletion tests do not save Events');
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
    throw UnimplementedError('R6 deletion tests do not edit Events');
  }

  @override
  Future<CalendarEventMutationOutcome> cancelEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required CalendarEventEditScope scope,
    required String operationId,
  }) {
    return cancelCompleter.future;
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
    throw UnimplementedError('R6 deletion tests do not reschedule Events');
  }

  @override
  Future<CalendarEventMutationOutcome> duplicateEvent({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
    required String duplicateId,
    required String operationId,
  }) {
    throw UnimplementedError('R6 deletion tests do not duplicate Events');
  }
}

/// Drive a single-finger horizontal day swipe (negative `dx` = next day).
/// Pumps every frame so tests can assert a deleted Event never renders,
/// even for one frame, during the transition.
Future<void> _swipeDay(WidgetTester tester, {required double dx}) async {
  final viewport = tester.getRect(find.byKey(const Key('planner-day-scroll')));
  final gesture = await tester.startGesture(viewport.center, pointer: 1);
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    await gesture.moveBy(Offset(dx / steps, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpPlanner(
  WidgetTester tester, {
  required _MutablePlannerRepository plannerRepository,
  CalendarEventRepository? calendarEventRepository,
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
  testWidgets(
    'R6-07/R6-08: multi-target and series tombstones publish atomically, '
    'filter cached days, and clear only after canonical absence',
    (tester) async {
      final seriesToday = _event(eventId: _seriesId, date: _today);
      final seriesNext = _event(eventId: _seriesId, date: _next);
      final independent = _event(
        eventId: _independentId,
        date: _today,
        startMinute: 11 * 60,
      );
      final survivor = _event(
        eventId: _survivorId,
        date: _next,
        startMinute: 13 * 60,
      );
      final repository = _MutablePlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[seriesToday, independent]),
        _next: _day(_next, <PlannerCalendarItem>[seriesNext, survivor]),
      });
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
      );
      final planner = container.read(plannerControllerProvider.notifier);
      await planner.readDays(const <PlannerDate>[_next]);
      final initialRevision = container
          .read(plannerControllerProvider)
          .eventDeletionRevision;
      final published = <PlannerState>[];
      final subscription = container.listen<PlannerState>(
        plannerControllerProvider,
        (previous, next) {
          if (next.eventDeletionRevision > initialRevision) {
            published.add(next);
          }
        },
      );
      addTearDown(subscription.close);

      final targets = PlannerEventDeletionTargetSet(
        occurrenceIds: <String>{independent.id},
        seriesIds: const <String>{_seriesId},
      );
      planner.beginPendingEventDeletion(targets);

      expect(published, hasLength(1));
      expect(
        published.single.day!.timedEvents,
        isEmpty,
        reason: 'all current-day targets disappear in one publication',
      );
      final filteredNext = await planner.readDays(const <PlannerDate>[_next]);
      expect(filteredNext.single.timedEvents, <PlannerCalendarItem>[survivor]);

      final switchFuture = planner.selectDate(_next);
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        <PlannerCalendarItem>[survivor],
        reason: 'the cached first frame is filtered before the refresh returns',
      );
      await switchFuture;
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        <PlannerCalendarItem>[survivor],
      );

      repository.days[_today] = _day(_today, const <PlannerCalendarItem>[]);
      repository.days[_next] = _day(_next, <PlannerCalendarItem>[survivor]);
      expect(await planner.confirmPendingEventDeletion(targets), isTrue);

      expect(
        planner
            .filterPendingEventDeletions(
              _day(_today, <PlannerCalendarItem>[seriesToday, independent]),
            )
            .timedEvents,
        <PlannerCalendarItem>[seriesToday, independent],
        reason: 'tombstones clear only after canonical reads prove absence',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'R6-08: an older in-flight day read cannot republish a tombstoned series',
    (tester) async {
      final seriesToday = _event(eventId: _seriesId, date: _today);
      final seriesNext = _event(eventId: _seriesId, date: _next);
      final staleNext = _day(_next, <PlannerCalendarItem>[seriesNext]);
      final repository = _MutablePlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[seriesToday]),
        _next: staleNext,
      });
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
      );
      final planner = container.read(plannerControllerProvider.notifier);
      final delayed = Completer<PlannerDay>();
      repository.queueRead(_next, delayed.future);
      final staleRead = planner.readDays(const <PlannerDate>[_next]);

      final targets = PlannerEventDeletionTargetSet.series(_seriesId);
      planner.beginPendingEventDeletion(targets);
      delayed.complete(staleNext);
      final result = await staleRead;

      expect(result.single.timedEvents, isEmpty);
      final switchFuture = planner.selectDate(_next);
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        isEmpty,
        reason: 'the raw stale cache is filtered on the first switched frame',
      );
      await switchFuture;
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        isEmpty,
      );

      repository.days[_today] = _day(_today, const <PlannerCalendarItem>[]);
      repository.days[_next] = _day(_next, const <PlannerCalendarItem>[]);
      expect(await planner.confirmPendingEventDeletion(targets), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'R6-07: a repository cancellation failure rolls the tombstone back and '
    'restores the visible Event',
    (tester) async {
      final event = _event(eventId: _independentId, date: _today);
      final plannerRepository = _MutablePlannerRepository(
        <PlannerDate, PlannerDay>{
          _today: _day(_today, <PlannerCalendarItem>[event]),
        },
      );
      final calendarRepository = _ControlledCancelCalendarRepository();
      final container = await _pumpPlanner(
        tester,
        plannerRepository: plannerRepository,
        calendarEventRepository: calendarRepository,
      );

      final cancellation = container
          .read(calendarEventControllerProvider.notifier)
          .cancelEvent(
            eventId: _independentId,
            originalDate: _today,
            scope: CalendarEventEditScope.occurrence,
            operationId: '44444444-dddd-4ddd-8ddd-444444444444',
          );
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        isEmpty,
        reason: 'the target hides before repository completion',
      );

      calendarRepository.cancelCompleter.completeError(
        StateError('controlled cancellation failure'),
      );
      expect(await cancellation, CalendarEventCancellationResult.notDeleted);
      expect(
        container.read(plannerControllerProvider).day!.timedEvents,
        <PlannerCalendarItem>[event],
        reason: 'failure removes the tombstone and restores canonical data',
      );
      expect(
        container.read(calendarEventControllerProvider),
        'Event was not deleted. Try again.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed deletion is confirmed by canonical reread when Planner refresh '
    'is stale, without offering a destructive retry',
    (tester) async {
      final event = _event(eventId: _independentId, date: _today);
      final plannerRepository = _MutablePlannerRepository(
        <PlannerDate, PlannerDay>{
          _today: _day(_today, <PlannerCalendarItem>[event]),
        },
      );
      final calendarRepository = _ControlledCancelCalendarRepository()
        ..canonicalOccurrence = CalendarEventOccurrence(
          id: event.id,
          eventId: _independentId,
          profileId: 'profile-1',
          title: 'Cancelled',
          timing: CalendarEventTiming.timed,
          originalDate: _today,
          displayDate: _today,
          status: CalendarEventStatus.cancelled,
          requiresReport: false,
          recurrence: const CalendarRecurrenceRule(),
        );
      final container = await _pumpPlanner(
        tester,
        plannerRepository: plannerRepository,
        calendarEventRepository: calendarRepository,
      );

      final cancellation = container
          .read(calendarEventControllerProvider.notifier)
          .cancelEvent(
            eventId: _independentId,
            originalDate: _today,
            scope: CalendarEventEditScope.occurrence,
            operationId: '55555555-dddd-4ddd-8ddd-555555555555',
          );
      calendarRepository.cancelCompleter.complete(
        CalendarEventMutationOutcome.changed,
      );

      expect(
        await cancellation,
        CalendarEventCancellationResult.deletedAwaitingPlannerRefresh,
      );
      expect(container.read(calendarEventControllerProvider), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'committed deletion with an unavailable canonical reread is uncertain, '
    'not a safe destructive retry',
    (tester) async {
      final event = _event(eventId: _independentId, date: _today);
      final plannerRepository = _MutablePlannerRepository(
        <PlannerDate, PlannerDay>{
          _today: _day(_today, <PlannerCalendarItem>[event]),
        },
      );
      final calendarRepository = _ControlledCancelCalendarRepository();
      final container = await _pumpPlanner(
        tester,
        plannerRepository: plannerRepository,
        calendarEventRepository: calendarRepository,
      );

      final cancellation = container
          .read(calendarEventControllerProvider.notifier)
          .cancelEvent(
            eventId: _independentId,
            originalDate: _today,
            scope: CalendarEventEditScope.occurrence,
            operationId: '66666666-dddd-4ddd-8ddd-666666666666',
          );
      calendarRepository.cancelCompleter.complete(
        CalendarEventMutationOutcome.changed,
      );

      expect(
        await cancellation,
        CalendarEventCancellationResult.deletionStateUncertain,
      );
      expect(container.read(calendarEventControllerProvider), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'R7-07: delete then swipe away/back never renders the deleted Event, '
    'not even for one frame, before or after canonical confirmation',
    (tester) async {
      final seriesToday = _event(eventId: _seriesId, date: _today);
      final seriesNext = _event(eventId: _seriesId, date: _next);
      final repository = _MutablePlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[seriesToday]),
        _next: _day(_next, <PlannerCalendarItem>[seriesNext]),
      });
      await _pumpPlanner(tester, plannerRepository: repository);

      Finder blockOn(PlannerDate date) => find.byKey(
        Key(
          'planner-timed-event-'
          '${CalendarEventOccurrenceIdentity.forDate(eventId: _seriesId, originalDate: date)}',
        ),
      );

      expect(blockOn(_today), findsOneWidget);
      final planner = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      ).read(plannerControllerProvider.notifier);
      planner.beginPendingEventDeletion(
        PlannerEventDeletionTargetSet.series(_seriesId),
      );
      await tester.pump();
      expect(
        blockOn(_today),
        findsNothing,
        reason: 'the target disappears on the very first tombstone frame',
      );

      // Swipe to the next day and back, asserting after every single frame
      // that neither occurrence ever paints.
      final viewport = tester.getRect(
        find.byKey(const Key('planner-day-scroll')),
      );
      final gesture = await tester.startGesture(viewport.center, pointer: 1);
      for (var i = 1; i <= 10; i++) {
        await gesture.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          blockOn(_today).evaluate().isEmpty &&
              blockOn(_next).evaluate().isEmpty,
          isTrue,
          reason: 'no deleted occurrence may paint during the away swipe',
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        blockOn(_today).evaluate().isEmpty && blockOn(_next).evaluate().isEmpty,
        isTrue,
        reason: 'deleted occurrence absent after settling on the next day',
      );

      final back = await tester.startGesture(viewport.center, pointer: 1);
      for (var i = 1; i <= 10; i++) {
        await back.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          blockOn(_today).evaluate().isEmpty &&
              blockOn(_next).evaluate().isEmpty,
          isTrue,
          reason: 'no deleted occurrence may paint during the back swipe',
        );
      }
      await back.up();
      await tester.pumpAndSettle();
      expect(blockOn(_today), findsNothing);

      // Canonical confirmation: repository rows disappear, tombstones clear.
      repository.days[_today] = _day(_today, const <PlannerCalendarItem>[]);
      repository.days[_next] = _day(_next, const <PlannerCalendarItem>[]);
      expect(
        await planner.confirmPendingEventDeletion(
          PlannerEventDeletionTargetSet.series(_seriesId),
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(blockOn(_today), findsNothing);

      // Post-confirm: swipe away/back again — the target must stay gone.
      await _swipeDay(tester, dx: -300);
      expect(blockOn(_next), findsNothing);
      await _swipeDay(tester, dx: 300);
      expect(blockOn(_today), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'R7-07: a stale in-flight adjacent preview future completing after '
    'delete is rejected and cannot paint the tombstoned target',
    (tester) async {
      final seriesToday = _event(eventId: _seriesId, date: _today);
      final staleNext = _day(_next, <PlannerCalendarItem>[
        _event(eventId: _seriesId, date: _next),
      ]);
      final repository = _MutablePlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[seriesToday]),
        _next: _day(_next, const <PlannerCalendarItem>[]),
      });
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
      );
      final planner = container.read(plannerControllerProvider.notifier);
      final blockOnNext = find.byKey(
        Key(
          'planner-timed-event-'
          '${CalendarEventOccurrenceIdentity.forDate(eventId: _seriesId, originalDate: _next)}',
        ),
      );

      // Force a fresh preview window whose adjacent-day read is delayed.
      final delayed = Completer<PlannerDay>();
      repository.queueRead(_next, delayed.future);
      await planner.refresh();
      await tester.pump();
      // The preview load for the new window is now in flight and blocked on
      // the queued read. Delete while it hangs.
      planner.beginPendingEventDeletion(
        PlannerEventDeletionTargetSet.series(_seriesId),
      );
      await tester.pump();
      // The stale future completes AFTER the deletion revision advanced.
      delayed.complete(staleNext);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        blockOnNext.evaluate().isEmpty,
        isTrue,
        reason: 'an older in-flight preview must never paint the target',
      );
      repository.days[_today] = _day(_today, const <PlannerCalendarItem>[]);
      repository.days[_next] = _day(_next, const <PlannerCalendarItem>[]);
      expect(
        await planner.confirmPendingEventDeletion(
          PlannerEventDeletionTargetSet.series(_seriesId),
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(blockOnNext, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'R7-08: an identical canonical refresh publishes no geometry mutation '
    'and no visible catch-up on the selected day',
    (tester) async {
      final event = _event(eventId: _independentId, date: _today);
      final repository = _MutablePlannerRepository(<PlannerDate, PlannerDay>{
        _today: _day(_today, <PlannerCalendarItem>[event]),
      });
      final container = await _pumpPlanner(
        tester,
        plannerRepository: repository,
      );
      final planner = container.read(plannerControllerProvider.notifier);
      final block = find.byKey(
        Key(
          'planner-timed-event-'
          '${CalendarEventOccurrenceIdentity.forDate(eventId: _independentId, originalDate: _today)}',
        ),
      );
      final before = tester.getRect(block);
      final readsBefore = repository.readCounts[_today] ?? 0;

      // Semantically identical canonical refresh: same rows, same layout.
      await planner.refresh();
      await tester.pumpAndSettle();
      await planner.refresh();
      await tester.pumpAndSettle();

      final after = tester.getRect(block);
      expect(
        after,
        before,
        reason: 'identical data must not move/resize the rendered block',
      );
      expect(
        repository.readCounts[_today]!,
        greaterThan(readsBefore),
        reason: 'the refresh actually re-reads canonical rows',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
