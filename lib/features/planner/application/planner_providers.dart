import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  throw StateError('PlannerRepository must be overridden at the app root');
});

final plannerDateSourceProvider = Provider<PlannerDateSource>((ref) {
  return const SystemPlannerDateSource();
});

final plannerIdentifierSourceProvider = Provider<IdentifierSource>((ref) {
  return const UuidIdentifierSource();
});

enum PlannerLoadStatus { loading, ready, failure }

/// Transient identities hidden while one or more Calendar Event deletions are
/// being reconciled with canonical Planner reads.
///
/// Occurrence deletion is keyed by the deterministic occurrence ID used by
/// [PlannerCalendarItem.id]. Entire-series deletion is keyed by the canonical
/// Calendar Event ID carried by [PlannerCalendarItem.eventId]. This value is
/// intentionally application-memory only; it is never persisted.
final class PlannerEventDeletionTargetSet {
  PlannerEventDeletionTargetSet({
    Iterable<String> occurrenceIds = const <String>[],
    Iterable<String> seriesIds = const <String>[],
  }) : occurrenceIds = Set<String>.unmodifiable(
         occurrenceIds.where((id) => id.trim().isNotEmpty),
       ),
       seriesIds = Set<String>.unmodifiable(
         seriesIds.where((id) => id.trim().isNotEmpty),
       );

  factory PlannerEventDeletionTargetSet.occurrence({
    required String eventId,
    required PlannerDate originalDate,
  }) {
    return PlannerEventDeletionTargetSet(
      occurrenceIds: <String>{
        CalendarEventOccurrenceIdentity.forDate(
          eventId: eventId,
          originalDate: originalDate,
        ),
      },
    );
  }

  factory PlannerEventDeletionTargetSet.series(String eventId) {
    return PlannerEventDeletionTargetSet(seriesIds: <String>{eventId});
  }

  final Set<String> occurrenceIds;
  final Set<String> seriesIds;

  bool get isEmpty => occurrenceIds.isEmpty && seriesIds.isEmpty;

  bool hides(PlannerCalendarItem event) {
    return occurrenceIds.contains(event.id) ||
        (event.eventId != null && seriesIds.contains(event.eventId));
  }
}

final class PlannerState {
  const PlannerState({
    required this.status,
    required this.selectedDate,
    required this.historicalItemsExpanded,
    this.eventDeletionRevision = 0,
    this.day,
    this.message,
  });

  final PlannerLoadStatus status;
  final PlannerDate selectedDate;
  final PlannerDay? day;
  final bool historicalItemsExpanded;
  final int eventDeletionRevision;
  final String? message;

  PlannerState copyWith({
    PlannerLoadStatus? status,
    PlannerDate? selectedDate,
    PlannerDay? day,
    bool clearDay = false,
    bool? historicalItemsExpanded,
    int? eventDeletionRevision,
    String? message,
    bool clearMessage = false,
  }) {
    return PlannerState(
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      day: clearDay ? null : day ?? this.day,
      historicalItemsExpanded:
          historicalItemsExpanded ?? this.historicalItemsExpanded,
      eventDeletionRevision:
          eventDeletionRevision ?? this.eventDeletionRevision,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final plannerControllerProvider =
    NotifierProvider<PlannerController, PlannerState>(PlannerController.new);

final class PlannerController extends Notifier<PlannerState> {
  static const int _dayCacheLimit = 15;
  int _loadGeneration = 0;
  int _dayCacheRevision = 0;
  final Map<PlannerDate, PlannerDay> _dayCache = <PlannerDate, PlannerDay>{};
  final Map<String, int> _pendingOccurrenceDeletionCounts = <String, int>{};
  final Map<String, int> _pendingSeriesDeletionCounts = <String, int>{};
  PlannerDay? _selectedCanonicalDay;

  PlannerRepository get _repository => ref.read(plannerRepositoryProvider);
  PlannerDateSource get _dateSource => ref.read(plannerDateSourceProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Planner requires a ready Local Profile');
    }
    return startup.profile.id;
  }

  @override
  PlannerState build() {
    ref.onDispose(() => _loadGeneration++);
    final today = _dateSource.today();
    unawaited(Future<void>.microtask(() => _load(today)));
    return PlannerState(
      status: PlannerLoadStatus.loading,
      selectedDate: today,
      historicalItemsExpanded: true,
    );
  }

  Future<void> selectDate(PlannerDate date) {
    if (date == state.selectedDate) {
      // Same-date refresh (Event save, report submit, Task link): reload in
      // place while keeping the visible schedule (no spinner flash).
      return _load(date, invalidateCache: true);
    }
    // R5-04/R5-06: direct selection publishes the target date immediately.
    // If that exact day was already read canonically in this controller
    // session, publish date + matching PlannerDay atomically on the first
    // frame, then refresh it from Drift. Otherwise clear the old day so an
    // old-date Event can never paint under the new date while the read runs.
    return _load(date, publishDateImmediately: true);
  }

  /// Loads the adjacent day before publishing the new selected-date state.
  ///
  /// The interactive pager keeps the destination page exposed until this
  /// future completes. Publishing `selectedDate` first would pair the new
  /// page key with the previous day's [PlannerDay] for one or more frames,
  /// which is the stale-schedule flash this route must avoid.
  Future<void> moveDays(int days) async {
    final date = state.selectedDate.addDays(days);
    await _load(date, rethrowOnFailure: true);
  }

  /// Refresh the currently selected Planner day without changing
  /// [PlannerState.selectedDate]. The same repository read used by
  /// date navigation runs in place, so the screen receives a fresh
  /// [PlannerState.day] and any signature derived from the
  /// selected-day content bumps naturally. Adjacent preview
  /// caches that compose their cache key from that signature will
  /// then refetch on the next build without a manual
  /// selected-date round trip.
  Future<void> refresh() => _load(state.selectedDate, invalidateCache: true);

  Future<List<PlannerDay>> readDays(Iterable<PlannerDate> dates) async {
    final requestedDates = dates.toList(growable: false);
    final cacheRevision = _dayCacheRevision;
    final days = await Future.wait(
      requestedDates.map(
        (date) => _repository.readDay(
          profileId: _profileId,
          selectedDate: date,
          today: _dateSource.today(),
        ),
      ),
    );
    // An Event/Task mutation may invalidate the cache while this adjacent-day
    // preview read is in flight. Never let that older result repopulate it.
    if (cacheRevision != _dayCacheRevision) {
      // A pending-deletion transition or mutation invalidated this read while
      // it was in flight. Re-read under the newest revision instead of
      // returning stale rows to a pager FutureBuilder that could paint them.
      return readDays(requestedDates);
    }
    for (final day in days) {
      _cacheDay(day);
    }
    return <PlannerDay>[
      for (final day in days) filterPendingEventDeletions(day),
    ];
  }

  /// Atomically publishes the complete Event target set as pending deletion.
  /// Every currently visible PlannerDay is immediately filtered in one state
  /// update; canonical repository work may then run serially without exposing
  /// intermediate Event-by-Event disappearance.
  void beginPendingEventDeletion(PlannerEventDeletionTargetSet targets) {
    if (targets.isEmpty) {
      return;
    }
    _incrementCounts(_pendingOccurrenceDeletionCounts, targets.occurrenceIds);
    _incrementCounts(_pendingSeriesDeletionCounts, targets.seriesIds);
    _publishEventDeletionRevision();
  }

  /// Rolls back only [targets], preserving any overlapping deletion owned by
  /// another active operation through reference counts.
  void rollbackPendingEventDeletion(PlannerEventDeletionTargetSet targets) {
    if (targets.isEmpty) {
      return;
    }
    _decrementCounts(_pendingOccurrenceDeletionCounts, targets.occurrenceIds);
    _decrementCounts(_pendingSeriesDeletionCounts, targets.seriesIds);
    _publishEventDeletionRevision();
  }

  /// Refreshes every currently selected/cached canonical day while [targets]
  /// remain filtered. The tombstones are removed only after those canonical
  /// reads confirm that no target is still a visible Calendar Event.
  ///
  /// A failed read or a still-present target is treated as a failed deletion:
  /// the tombstones are rolled back so data is never silently hidden.
  Future<bool> confirmPendingEventDeletion(
    PlannerEventDeletionTargetSet targets,
  ) async {
    if (targets.isEmpty) {
      return true;
    }
    final dates = <PlannerDate>{state.selectedDate, ..._dayCache.keys};
    final refreshRevision = ++_dayCacheRevision;
    _loadGeneration += 1;
    try {
      final days = await Future.wait(
        dates.map(
          (date) => _repository.readDay(
            profileId: _profileId,
            selectedDate: date,
            today: _dateSource.today(),
          ),
        ),
      );
      if (refreshRevision != _dayCacheRevision) {
        // Another data transition won while these reads were in flight. Keep
        // the tombstones active and retry against the newest canonical view.
        return confirmPendingEventDeletion(targets);
      }
      final targetStillVisible = days.any(
        (day) => <PlannerCalendarItem>[
          ...day.allDayEvents,
          ...day.timedEvents,
          ...day.awaitingReportEvents,
        ].any(targets.hides),
      );
      if (targetStillVisible) {
        rollbackPendingEventDeletion(targets);
        return false;
      }
      for (final day in days) {
        _cacheDay(day);
        if (day.selectedDate == state.selectedDate) {
          _selectedCanonicalDay = day;
        }
      }
      _decrementCounts(_pendingOccurrenceDeletionCounts, targets.occurrenceIds);
      _decrementCounts(_pendingSeriesDeletionCounts, targets.seriesIds);
      _publishEventDeletionRevision();
      return true;
    } on Object {
      rollbackPendingEventDeletion(targets);
      return false;
    }
  }

  /// Applies the active transient deletion identities to every Event-bearing
  /// PlannerDay list. Task lists and historical change records are preserved.
  PlannerDay filterPendingEventDeletions(PlannerDay day) {
    if (_pendingOccurrenceDeletionCounts.isEmpty &&
        _pendingSeriesDeletionCounts.isEmpty) {
      return day;
    }
    final allDayEvents = day.allDayEvents
        .where((event) => !_isPendingEventDeletion(event))
        .toList(growable: false);
    final timedEvents = day.timedEvents
        .where((event) => !_isPendingEventDeletion(event))
        .toList(growable: false);
    final awaitingReportEvents = day.awaitingReportEvents
        .where((event) => !_isPendingEventDeletion(event))
        .toList(growable: false);
    if (allDayEvents.length == day.allDayEvents.length &&
        timedEvents.length == day.timedEvents.length &&
        awaitingReportEvents.length == day.awaitingReportEvents.length) {
      return day;
    }
    return PlannerDay(
      selectedDate: day.selectedDate,
      allDayEvents: allDayEvents,
      timedEvents: timedEvents,
      tasks: day.tasks,
      overdueTasks: day.overdueTasks,
      completedTasks: day.completedTasks,
      awaitingReportEvents: awaitingReportEvents,
      changes: day.changes,
    );
  }

  void toggleHistoricalItems() {
    state = state.copyWith(
      historicalItemsExpanded: !state.historicalItemsExpanded,
    );
  }

  Future<PlannerTask?> readTask(String taskId) {
    return _repository.readTask(profileId: _profileId, taskId: taskId);
  }

  Future<bool> saveTask(
    PlannerTaskDraft draft, {
    bool confirmLinkedTypeTransfer = false,
  }) async {
    try {
      await _repository.saveTask(
        profileId: _profileId,
        draft: draft,
        confirmLinkedTypeTransfer: confirmLinkedTypeTransfer,
      );
      await _load(state.selectedDate, invalidateCache: true);
      return true;
    } on PlannerTaskValidationException catch (error) {
      state = state.copyWith(message: error.message);
      return false;
    } on Object {
      state = state.copyWith(
        message:
            'Task could not be saved. Your input remains available to retry.',
      );
      return false;
    }
  }

  Future<TaskStatusChangeOutcome> changeStatus({
    required String taskId,
    required PlannerTaskStatus target,
    required String operationId,
    String? reason,
    bool confirmLinkedTypeTransfer = false,
  }) async {
    try {
      final outcome = await _repository.changeTaskStatus(
        profileId: _profileId,
        taskId: taskId,
        target: target,
        operationId: operationId,
        reason: reason,
        confirmLinkedTypeTransfer: confirmLinkedTypeTransfer,
      );
      await _load(state.selectedDate, invalidateCache: true);
      state = state.copyWith(
        message: switch (outcome) {
          TaskStatusChangeOutcome.reportRequired =>
            'This Task stays Incomplete until its required report and '
                'completion can save together.',
          TaskStatusChangeOutcome.correctionRequired =>
            'This status has historical effects and must use a correction.',
          TaskStatusChangeOutcome.changed ||
          TaskStatusChangeOutcome.unchanged => null,
        },
        clearMessage:
            outcome == TaskStatusChangeOutcome.changed ||
            outcome == TaskStatusChangeOutcome.unchanged,
      );
      return outcome;
    } on Object {
      state = state.copyWith(
        message: 'Task status was not changed. You can safely retry.',
      );
      return TaskStatusChangeOutcome.unchanged;
    }
  }

  void clearMessage() {
    state = state.copyWith(clearMessage: true);
  }

  /// Read the requested day before publishing it as the selected page.
  ///
  /// Navigation can issue another read before this one completes. The
  /// generation guard makes the newest request authoritative, so a slower
  /// earlier result cannot restore an old date or schedule after a newer
  /// selection has already completed.
  Future<void> _load(
    PlannerDate date, {
    bool rethrowOnFailure = false,
    bool publishDateImmediately = false,
    bool invalidateCache = false,
  }) async {
    if (invalidateCache) {
      _invalidateDayCache();
    }
    final generation = ++_loadGeneration;
    final cached = _dayCache[date];
    if (cached != null) {
      // Reinsert to make the bounded insertion-ordered map act as a tiny LRU.
      _dayCache.remove(date);
      _dayCache[date] = cached;
      _selectedCanonicalDay = cached;
      state = state.copyWith(
        status: PlannerLoadStatus.ready,
        selectedDate: date,
        day: filterPendingEventDeletions(cached),
        clearMessage: true,
      );
    } else if (publishDateImmediately) {
      _selectedCanonicalDay = null;
      state = state.copyWith(
        status: PlannerLoadStatus.loading,
        selectedDate: date,
        clearDay: true,
        clearMessage: true,
      );
    } else {
      state = state.copyWith(
        status: PlannerLoadStatus.loading,
        clearMessage: true,
      );
    }
    await _loadDay(date, generation, rethrowOnFailure: rethrowOnFailure);
  }

  Future<void> _loadDay(
    PlannerDate date,
    int generation, {
    bool rethrowOnFailure = false,
  }) async {
    try {
      final day = await _repository.readDay(
        profileId: _profileId,
        selectedDate: date,
        today: _dateSource.today(),
      );
      if (generation != _loadGeneration) {
        return;
      }
      _cacheDay(day);
      _selectedCanonicalDay = day;
      state = state.copyWith(
        status: PlannerLoadStatus.ready,
        selectedDate: date,
        day: filterPendingEventDeletions(day),
        clearMessage: true,
      );
    } on Object {
      if (generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(
        status: PlannerLoadStatus.failure,
        message: 'Planner data could not be opened. Retry without data loss.',
      );
      if (rethrowOnFailure) {
        rethrow;
      }
    }
  }

  void _invalidateDayCache() {
    _dayCacheRevision += 1;
    _dayCache.clear();
  }

  void _cacheDay(PlannerDay day) {
    _dayCache.remove(day.selectedDate);
    _dayCache[day.selectedDate] = day;
    final today = _dateSource.today();
    while (_dayCache.length > _dayCacheLimit) {
      final eviction = _dayCache.keys.firstWhere(
        (date) => date != today,
        orElse: () => _dayCache.keys.first,
      );
      _dayCache.remove(eviction);
    }
  }

  bool _isPendingEventDeletion(PlannerCalendarItem event) {
    return _pendingOccurrenceDeletionCounts.containsKey(event.id) ||
        (event.eventId != null &&
            _pendingSeriesDeletionCounts.containsKey(event.eventId));
  }

  /// R7-07 RENDER FILTER LAW: public render-time predicate. The final
  /// render input filters active tombstones even if a day snapshot produced
  /// before the deletion somehow survives in memory — defense in depth on
  /// top of the monotonic [PlannerState.eventDeletionRevision] gate.
  bool isPendingEventDeletion(PlannerCalendarItem event) {
    return _isPendingEventDeletion(event);
  }

  void _publishEventDeletionRevision() {
    _loadGeneration += 1;
    _dayCacheRevision += 1;
    final canonical = _selectedCanonicalDay?.selectedDate == state.selectedDate
        ? _selectedCanonicalDay
        : _dayCache[state.selectedDate];
    state = state.copyWith(
      day: canonical == null ? null : filterPendingEventDeletions(canonical),
      clearDay: canonical == null && state.day == null,
      eventDeletionRevision: state.eventDeletionRevision + 1,
    );
  }

  static void _incrementCounts(Map<String, int> counts, Iterable<String> ids) {
    for (final id in ids) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }

  static void _decrementCounts(Map<String, int> counts, Iterable<String> ids) {
    for (final id in ids) {
      final next = (counts[id] ?? 0) - 1;
      if (next > 0) {
        counts[id] = next;
      } else {
        counts.remove(id);
      }
    }
  }
}
