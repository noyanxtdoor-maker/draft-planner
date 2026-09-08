// S1B — cache contract tests (pack 22 matrix).
//
// These tests drive the real PlannerController through a bare
// ProviderContainer (no widget tree, so no preview-read noise) with a
// counting PlannerRepository wrapper. The controller's cache-first readDays,
// rolling prefetch, cached pager promotion, and in-flight coalescing are
// verified against observable repository read counts and state publications.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

import '../../../support/test_dependencies.dart';

const PlannerDate _today = PlannerDate(year: 2026, month: 7, day: 27);
const String _displayTimeZoneId = 'Asia/Manila';
const String _profileId = '11111111-1111-4111-8111-111111111111';

PlannerDate _at(int offset) => _today.addDays(offset);

CalendarEventDraft _timedDraft({
  required String id,
  required PlannerDate date,
  required int startMinute,
  required int endMinute,
}) {
  return CalendarEventDraft(
    id: id,
    title: 'S1B Cache Fixture',
    timing: CalendarEventTiming.timed,
    startDate: date,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
  );
}

/// Delegating [PlannerRepository] that counts every `readDay` call per date
/// and can gate or fail individual dates on demand.
final class _CountingPlannerRepository implements PlannerRepository {
  _CountingPlannerRepository(this._inner);

  final PlannerRepository _inner;
  final Map<PlannerDate, int> _readCounts = <PlannerDate, int>{};
  final Map<PlannerDate, Completer<void>> _gates =
      <PlannerDate, Completer<void>>{};
  final Set<PlannerDate> _failDates = <PlannerDate>{};

  int readsFor(PlannerDate date) => _readCounts[date] ?? 0;

  void gate(PlannerDate date) {
    _gates[date] = Completer<void>();
  }

  void releaseGate(PlannerDate date) {
    _gates.remove(date)?.complete();
  }

  void failNext(PlannerDate date) {
    _failDates.add(date);
  }

  @override
  Future<PlannerDay> readDay({
    required String profileId,
    required PlannerDate selectedDate,
    required PlannerDate today,
  }) {
    _readCounts[selectedDate] = (_readCounts[selectedDate] ?? 0) + 1;
    final gate = _gates[selectedDate];
    if (gate != null) {
      return gate.future.then(
        (_) => _inner.readDay(
          profileId: profileId,
          selectedDate: selectedDate,
          today: today,
        ),
      );
    }
    if (_failDates.contains(selectedDate)) {
      return Future<PlannerDay>.error(
        StateError('Injected read failure for $selectedDate'),
      );
    }
    return _inner.readDay(
      profileId: profileId,
      selectedDate: selectedDate,
      today: today,
    );
  }

  @override
  Future<PlannerTask?> readTask({
    required String profileId,
    required String taskId,
  }) {
    return _inner.readTask(profileId: profileId, taskId: taskId);
  }

  @override
  Future<PlannerTask> saveTask({
    required String profileId,
    required PlannerTaskDraft draft,
    bool confirmLinkedTypeTransfer = false,
  }) {
    return _inner.saveTask(
      profileId: profileId,
      draft: draft,
      confirmLinkedTypeTransfer: confirmLinkedTypeTransfer,
    );
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
    return _inner.changeTaskStatus(
      profileId: profileId,
      taskId: taskId,
      target: target,
      operationId: operationId,
      reason: reason,
      confirmLinkedTypeTransfer: confirmLinkedTypeTransfer,
    );
  }

  @override
  Future<TaskHardDeleteOutcome> hardDeleteTask({
    required String profileId,
    required String taskId,
  }) => _inner.hardDeleteTask(profileId: profileId, taskId: taskId);
}

/// Builds a real Drift planner repository (with the real calendar source, so
/// seeded Events are visible) plus the calendar repository used to seed data.
({DriftPlannerRepository planner, DriftCalendarEventRepository calendar})
_buildRepositories(AppDatabase database) {
  final timeZones = IanaCalendarEventTimeZones(
    displayTimeZoneId: _displayTimeZoneId,
  );
  final linkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final outcomeReportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final calendarRepository = DriftCalendarEventRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    timeZones: timeZones,
    taskContextSource: linkRepository,
    linkContextTransfer: linkRepository,
    reportSource: outcomeReportingRepository,
  );
  final plannerRepository = DriftPlannerRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    calendarSource: calendarRepository,
    taskContextSource: linkRepository,
    historicalEffectReader: outcomeReportingRepository,
  );
  return (planner: plannerRepository, calendar: calendarRepository);
}

/// Builds a bare container with a ready startup profile and the counting
/// planner repository, then waits for the initial load + rolling prefetch.
Future<
  ({
    ProviderContainer container,
    PlannerController planner,
    _CountingPlannerRepository repository,
    DriftCalendarEventRepository calendar,
  })
>
_buildHarness() async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
  final startup = buildTestRepository(database: database);
  await startup.completeOnboarding();
  final repos = _buildRepositories(database);
  final repository = _CountingPlannerRepository(repos.planner);
  final container = ProviderContainer(
    overrides: [
      diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
      startupRepositoryProvider.overrideWithValue(startup),
      plannerRepositoryProvider.overrideWithValue(repository),
      plannerDateSourceProvider.overrideWithValue(
        const FixedPlannerDateSource(_today),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Resolve startup, then build the planner controller (fires the initial
  // load + rolling prefetch of the ±3 runway).
  container.read(startupControllerProvider);
  for (var attempt = 0; attempt < 50; attempt++) {
    if (container.read(startupControllerProvider) is StartupReady) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(container.read(startupControllerProvider), isA<StartupReady>());
  final planner = container.read(plannerControllerProvider.notifier);
  await _settle();
  return (
    container: container,
    planner: planner,
    repository: repository,
    calendar: repos.calendar,
  );
}

/// Lets microtask/event-loop futures (drift reads, prefetch, background
/// canonical refresh) run to completion in a plain (non-fake-async) test.
Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

void main() {
  group('S1B cache contract — readDays', () {
    test('all cache hits resolve with zero repository reads', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      // Initial load + prefetch already cached _today (exactly one read).
      expect(repository.readsFor(_today), 1);
      final first = await planner.readDays(<PlannerDate>[_today]);
      expect(first.single.selectedDate, _today);
      final readsAfterFirstHit = repository.readsFor(_today);
      await planner.readDays(<PlannerDate>[_today]);
      expect(
        repository.readsFor(_today),
        readsAfterFirstHit,
        reason: 'an all-cache-hit request must cost zero repository reads',
      );
    });

    test('a single miss performs exactly one repository read', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      // _at(10) is far outside the prefetch runway, so it is a true miss.
      final days = await planner.readDays(<PlannerDate>[_at(10)]);
      expect(days.single.selectedDate, _at(10));
      expect(repository.readsFor(_at(10)), 1);

      final daysAgain = await planner.readDays(<PlannerDate>[_at(10)]);
      expect(daysAgain.single.selectedDate, _at(10));
      expect(
        repository.readsFor(_at(10)),
        1,
        reason: 'the second request is served from the cache',
      );
    });

    test('a mixed hit/miss request reads only the missing date', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      final days = await planner.readDays(<PlannerDate>[_today, _at(10)]);
      expect(days.map((day) => day.selectedDate), <PlannerDate>[
        _today,
        _at(10),
      ]);
      expect(repository.readsFor(_today), 1, reason: 'hit — no new read');
      expect(repository.readsFor(_at(10)), 1, reason: 'miss — one read');
    });

    test('duplicate requested dates share one read and resolve '
        'deterministically', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      final days = await planner.readDays(<PlannerDate>[_at(10), _at(10)]);
      expect(days, hasLength(2));
      expect(days.every((day) => day.selectedDate == _at(10)), isTrue);
      expect(
        repository.readsFor(_at(10)),
        1,
        reason: 'duplicate dates in one request must share a single read',
      );
    });

    test('results preserve the exact request order', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;

      final days = await planner.readDays(<PlannerDate>[
        _at(10),
        _today,
        _at(9),
        _at(11),
      ]);
      expect(days.map((day) => day.selectedDate), <PlannerDate>[
        _at(10),
        _today,
        _at(9),
        _at(11),
      ]);
    });

    test(
      'a cache invalidation forces a fresh read of every cached date',
      () async {
        final harness = await _buildHarness();
        final planner = harness.planner;
        final repository = harness.repository;

        // Cache a far date canonically (outside the prefetch runway).
        await planner.readDays(<PlannerDate>[_at(10)]);
        expect(repository.readsFor(_at(10)), 1);

        // Invalidate the whole cache (a refresh path).
        await planner.refresh();
        expect(
          repository.readsFor(_today),
          2,
          reason: 'refresh re-reads today',
        );

        // The invalidated far date must be re-read, never adopted stale.
        await planner.readDays(<PlannerDate>[_at(10)]);
        expect(
          repository.readsFor(_at(10)),
          2,
          reason:
              'the invalidated date must be re-read, not served from a '
              'stale cache entry',
        );
      },
    );

    test(
      'active pending deletions are filtered from readDays results',
      () async {
        final harness = await _buildHarness();
        final planner = harness.planner;
        final calendar = harness.calendar;

        const eventId = '22222222-2222-4222-8222-222222222222';
        await calendar.saveEvent(
          profileId: _profileId,
          draft: _timedDraft(
            id: eventId,
            date: _at(10),
            startMinute: 9 * 60,
            endMinute: 10 * 60,
          ),
        );

        // Cache the populated day.
        final days = await planner.readDays(<PlannerDate>[_at(10)]);
        expect(days.single.timedEvents, hasLength(1));

        // A pending deletion must hide the target from cached readDays results.
        // Tombstones are keyed by the deterministic PlannerCalendarItem id, not
        // the draft id.
        final visibleItem = days.single.timedEvents.single;
        planner.beginPendingEventDeletion(
          PlannerEventDeletionTargetSet(
            occurrenceIds: <String>{visibleItem.id},
          ),
        );
        final filtered = await planner.readDays(<PlannerDate>[_at(10)]);
        expect(filtered.single.timedEvents, isEmpty);
      },
    );

    test('the canonical cache stays bounded and evicts oldest entries '
        '(15-day bound)', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      for (var offset = 0; offset < 20; offset++) {
        await planner.readDays(<PlannerDate>[_at(offset)]);
      }
      // Exactly the protected today + the newest 14 (15 total) survive.
      expect(
        planner.cachedDay(_today),
        isNotNull,
        reason: 'today is protected from eviction',
      );
      expect(
        repository.readsFor(_today),
        1,
        reason: 'today stayed cached across all 20 reads',
      );
      expect(
        planner.cachedDay(_at(4)),
        isNull,
        reason: '_at(4) was evicted past the 15-entry bound',
      );
      expect(
        planner.cachedDay(_at(6)),
        isNotNull,
        reason: '_at(6) is still inside the 15-entry window',
      );
      expect(
        repository.readsFor(_at(6)),
        1,
        reason: '_at(6) stayed resident — no re-read needed',
      );
      // Re-reading a resident date is free (before any further eviction).
      await planner.readDays(<PlannerDate>[_at(6)]);
      expect(repository.readsFor(_at(6)), 1);
      // Re-reading an evicted date costs one fresh repository read.
      await planner.readDays(<PlannerDate>[_at(4)]);
      expect(repository.readsFor(_at(4)), 2);
    });
  });

  group('S1B cache contract — rolling prefetch runway', () {
    test('a cached pager commit warms only the new edge misses', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;
      final container = harness.container;

      // The initial load warmed _at(-3).._at(3). Commit three days forward:
      // the runway re-centers and fetches only the genuinely new edges.
      expect(repository.readsFor(_at(4)), 0, reason: 'pre-commit sanity');
      await planner.moveDaysForPager(3);
      await _settle();
      expect(container.read(plannerControllerProvider).selectedDate, _at(3));
      for (final offset in const <int>[4, 5, 6]) {
        expect(
          repository.readsFor(_at(offset)),
          1,
          reason: 'prefetch fetches only the new edge miss $_at($offset)',
        );
      }
      expect(
        repository.readsFor(_at(2)),
        1,
        reason: 'an already-warm date is never re-read by the prefetch',
      );
      expect(
        repository.readsFor(_at(7)),
        0,
        reason: 'the date beyond the new runway edge is not fetched',
      );
    });

    test('prefetch failure is silent and non-destructive', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;
      final container = harness.container;

      repository.failNext(_at(4));
      await planner.moveDaysForPager(3);
      await _settle();
      expect(container.read(plannerControllerProvider).selectedDate, _at(3));
      expect(
        container.read(plannerControllerProvider).status,
        PlannerLoadStatus.ready,
      );
      expect(
        planner.cachedDay(_at(3)),
        isNotNull,
        reason: 'the committed day stays authoritative after a prefetch miss',
      );
      expect(
        planner.cachedDay(_at(4)),
        isNull,
        reason: 'the failed prefetch date is simply not cached',
      );
    });

    test('a stale background refresh can never restore an old date', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final container = harness.container;

      // Two immediate cached commits: the first handoff's background refresh
      // must not restore _at(1) after the second commit lands on _at(2).
      await planner.moveDaysForPager(1);
      await planner.moveDaysForPager(1);
      await _settle();
      expect(container.read(plannerControllerProvider).selectedDate, _at(2));
    });

    test('runway rolls forward and reverse around the selected date', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;
      final container = harness.container;

      await planner.moveDaysForPager(3);
      await _settle();
      expect(
        planner.cachedDay(_at(6)),
        isNotNull,
        reason: 'forward roll warms the newest edge',
      );

      // Four days back re-centers the runway around _at(-1) and warms the
      // only genuinely new edge (_at(-4)).
      await planner.moveDaysForPager(-4);
      await _settle();
      expect(container.read(plannerControllerProvider).selectedDate, _at(-1));
      expect(
        planner.cachedDay(_at(-4)),
        isNotNull,
        reason: 'reverse roll warms the oldest new edge',
      );
      expect(
        repository.readsFor(_at(-5)),
        0,
        reason: 'the date beyond the reverse runway edge is not fetched',
      );
    });
  });

  group('S1B cache contract — cached pager promotion', () {
    test('a cache hit publishes the exact day with no loading blank and no '
        'visible republish when canonical data is unchanged', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;
      final container = harness.container;

      final published = <PlannerState>[];
      final subscription = container.listen<PlannerState>(
        plannerControllerProvider,
        (previous, next) => published.add(next),
      );
      addTearDown(subscription.close);

      await planner.moveDaysForPager(1);
      await _settle();

      expect(
        published,
        hasLength(1),
        reason:
            'cached handoff publishes once; the equal background '
            'refresh must not produce a second visible revision',
      );
      final state = published.single;
      expect(state.status, PlannerLoadStatus.ready);
      expect(state.selectedDate, _at(1));
      expect(
        state.day!.selectedDate,
        _at(1),
        reason: 'the cached exact day is published, never a blank page',
      );
      expect(
        repository.readsFor(_at(1)),
        2,
        reason: 'initial prefetch + one background canonical refresh',
      );
    });

    test('a changed background canonical result becomes one coherent update '
        'after the cached handoff', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final container = harness.container;
      final calendar = harness.calendar;

      // Mutate the underlying data for _at(1) AFTER the initial prefetch
      // cached it as an empty day, so the background canonical refresh
      // diverges from the cached snapshot.
      const changedEventId = '33333333-3333-4333-8333-333333333333';
      await calendar.saveEvent(
        profileId: _profileId,
        draft: _timedDraft(
          id: changedEventId,
          date: _at(1),
          startMinute: 9 * 60,
          endMinute: 10 * 60,
        ),
      );

      final published = <PlannerState>[];
      final subscription = container.listen<PlannerState>(
        plannerControllerProvider,
        (previous, next) => published.add(next),
      );
      addTearDown(subscription.close);

      await planner.moveDaysForPager(1);
      await _settle();

      expect(
        published,
        hasLength(2),
        reason: 'cached handoff publish + one coherent changed-data update',
      );
      expect(published.first.day!.timedEvents, isEmpty);
      expect(published.last.day!.timedEvents, hasLength(1));
      expect(published.last.day!.timedEvents.single.eventId, changedEventId);
      expect(published.last.status, PlannerLoadStatus.ready);
      expect(published.last.selectedDate, _at(1));
    });
  });

  group('S1B cache contract — in-flight coalescing', () {
    test('concurrent reads of one missing date share a single repository '
        'read and the entry is removed on completion', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      final first = planner.readDays(<PlannerDate>[_at(10)]);
      final second = planner.readDays(<PlannerDate>[_at(10)]);
      final results = await Future.wait(<Future<List<PlannerDay>>>[
        first,
        second,
      ]);
      expect(repository.readsFor(_at(10)), 1);
      expect(results[0].single.selectedDate, _at(10));
      expect(results[1].single.selectedDate, _at(10));

      // The in-flight entry removed itself: a later request is a cache hit,
      // not a shared stale future.
      await planner.readDays(<PlannerDate>[_at(10)]);
      expect(
        repository.readsFor(_at(10)),
        1,
        reason: 'post-completion requests resolve from the cache',
      );
    });

    test('a read in flight across a cache invalidation is never adopted — '
        'the request retries under the newest revision', () async {
      final harness = await _buildHarness();
      final planner = harness.planner;
      final repository = harness.repository;

      // _at(10) sits far outside the ±3 prefetch runway, so the invalidation
      // below cannot accidentally warm it.
      repository.gate(_at(10));
      final pending = planner.readDays(<PlannerDate>[_at(10)]);
      expect(repository.readsFor(_at(10)), 1);

      // Invalidate the cache while the read is still in flight.
      await planner.refresh();

      // Release the stale read; the request must detect the revision change
      // and re-read under the newest revision instead of adopting the stale
      // in-flight result.
      repository.releaseGate(_at(10));
      final result = await pending;
      expect(repository.readsFor(_at(10)), 2);
      expect(result.single.selectedDate, _at(10));
      expect(
        planner.cachedDay(_at(10)),
        isNotNull,
        reason: 'the fresh post-invalidation day is cached',
      );
    });
  });
}
