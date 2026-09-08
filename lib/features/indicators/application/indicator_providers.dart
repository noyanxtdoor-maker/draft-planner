import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/indicators/application/indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final indicatorRepositoryProvider = Provider<IndicatorRepository>((ref) {
  throw StateError('IndicatorRepository must be overridden at the app root');
});

final indicatorIdentifierSourceProvider = Provider<IdentifierSource>((ref) {
  return const UuidIdentifierSource();
});

final indicatorChangesProvider = StreamProvider.family<void, String>((
  ref,
  profileId,
) {
  return ref.read(indicatorRepositoryProvider).watchChanges(profileId);
});

/// Tri-state for the Home Temple Visit secondary line (MP-18).
///
/// Home must never render "Set Schedule" from the unresolved/loading state:
/// only a RESOLVED true-null result may claim there is no scheduled visit.
enum NextTempleVisitStatus { loading, ready, failure }

final class NextTempleVisitState {
  const NextTempleVisitState({required this.status, this.value});

  final NextTempleVisitStatus status;

  /// The last CONFIRMED read result.  While the first-ever read is in flight
  /// this is null; while a refresh is in flight it retains the previous
  /// confirmed value (retained, never fabricated).
  final PlannerDate? value;

  /// A confirmed value exists (a date is scheduled).
  bool get hasConfirmedValue => value != null;

  /// True only when the last read CONFIRMED that no Temple Visit is scheduled.
  bool get isResolvedNull =>
      status == NextTempleVisitStatus.ready && value == null;
}

/// Reads the Temple Visit schedule directly from the canonical calendar
/// source. Home uses this small projection instead of retaining a potentially
/// stale legacy Home snapshot.
///
/// MP-18: the controller keeps the previous CONFIRMED value visible while a
/// refresh is in flight and exposes a distinct loading state, so the Home
/// card can tell "unresolved" apart from "confirmed no schedule".  It replaces
/// the old FutureProvider whose null-while-loading state collapsed both cases
/// into one visual "Set Schedule".
final nextTempleVisitControllerProvider =
    NotifierProvider<NextTempleVisitController, NextTempleVisitState>(
      NextTempleVisitController.new,
    );

final class NextTempleVisitController extends Notifier<NextTempleVisitState> {
  StreamSubscription<void>? _subscription;
  bool _disposed = false;
  int _generation = 0;

  IndicatorRepository get _repository => ref.read(indicatorRepositoryProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Temple Visit schedule requires a ready Local Profile');
    }
    return startup.profile.id;
  }

  PlannerDate get _today => ref.read(plannerDateSourceProvider).today();

  @override
  NextTempleVisitState build() {
    _disposed = false;
    _generation++;
    // Keep the projection dependent on startup readiness and the date source,
    // exactly like the old FutureProvider, so it re-reads when either
    // changes (e.g. app resume re-invalidates the date source).
    ref.watch(startupControllerProvider);
    ref.watch(plannerDateSourceProvider);
    final profileId = _profileId;
    // Calendar-event writes are included in the indicator change stream, so
    // the projection refreshes when an event is created, edited, or deleted.
    _subscription = _repository.watchChanges(profileId).listen((_) {
      if (!_disposed) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      unawaited(_subscription?.cancel());
    });
    unawaited(Future<void>.microtask(refresh));
    return const NextTempleVisitState(status: NextTempleVisitStatus.loading);
  }

  /// Re-reads the schedule, retaining the last confirmed value while the read
  /// is in flight (MP-18: no "Set Schedule" flash during a refresh).  A
  /// first-ever read stays in [NextTempleVisitStatus.loading] until a result
  /// lands; a failure also retains the previous value and never claims
  /// "no schedule".
  Future<void> refresh() async {
    if (_disposed) {
      return;
    }
    final generation = ++_generation;
    final previous = state;
    try {
      final result = await _repository.readNextTempleVisit(
        profileId: _profileId,
        today: _today,
      );
      if (_disposed || generation != _generation) {
        return;
      }
      state = NextTempleVisitState(
        status: NextTempleVisitStatus.ready,
        value: result,
      );
    } catch (_) {
      if (_disposed || generation != _generation) {
        return;
      }
      state = NextTempleVisitState(
        status: NextTempleVisitStatus.failure,
        value: previous.value,
      );
    }
  }
}

final indicatorPeriodSnapshotProvider =
    FutureProvider.family<HomeIndicatorSnapshot, IndicatorPeriod>((
      ref,
      period,
    ) {
      final startup = ref.read(startupControllerProvider);
      if (startup is! StartupReady) {
        throw StateError('Life Goals require a ready Local Profile');
      }
      return ref
          .read(indicatorRepositoryProvider)
          .readHome(
            profileId: startup.profile.id,
            period: period,
            today: ref.read(plannerDateSourceProvider).today(),
          );
    });

enum HomeIndicatorLoadStatus { loading, ready, rebuilding, failure }

final class HomeIndicatorState {
  const HomeIndicatorState({required this.status, this.snapshot, this.message});

  final HomeIndicatorLoadStatus status;
  final HomeIndicatorSnapshot? snapshot;
  final String? message;
}

final homeIndicatorControllerProvider =
    NotifierProvider<HomeIndicatorController, HomeIndicatorState>(
      HomeIndicatorController.new,
    );

final class HomeIndicatorController extends Notifier<HomeIndicatorState> {
  StreamSubscription<void>? _subscription;
  bool _disposed = false;

  IndicatorRepository get _repository => ref.read(indicatorRepositoryProvider);

  String get _profileId {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      throw StateError('Home indicators require a ready Local Profile');
    }
    return startup.profile.id;
  }

  IndicatorPeriod get currentPeriod => IndicatorPeriod.currentWeek(
    ref.read(plannerDateSourceProvider).today(),
    startDay: ref.read(startOfWeekProvider),
  );

  @override
  HomeIndicatorState build() {
    _disposed = false;
    final profileId = _profileId;
    _subscription = _repository.watchChanges(profileId).listen((_) {
      if (!_disposed) {
        unawaited(refresh());
      }
    });
    ref.onDispose(() {
      _disposed = true;
      unawaited(_subscription?.cancel());
    });
    unawaited(Future<void>.microtask(refresh));
    return const HomeIndicatorState(status: HomeIndicatorLoadStatus.loading);
  }

  Future<void> refresh() async {
    if (_disposed) {
      return;
    }
    final previous = state.snapshot;
    state = HomeIndicatorState(
      status: previous == null
          ? HomeIndicatorLoadStatus.loading
          : HomeIndicatorLoadStatus.rebuilding,
      snapshot: previous,
    );
    try {
      final today = ref.read(plannerDateSourceProvider).today();
      final snapshot = await _repository.readHome(
        profileId: _profileId,
        period: IndicatorPeriod.currentWeek(
          today,
          startDay: ref.read(startOfWeekProvider),
        ),
        today: today,
      );
      if (_disposed) {
        return;
      }
      state = HomeIndicatorState(
        status: HomeIndicatorLoadStatus.ready,
        snapshot: snapshot,
      );
    } on Object {
      if (_disposed) {
        return;
      }
      state = HomeIndicatorState(
        status: HomeIndicatorLoadStatus.failure,
        snapshot: previous,
        message:
            'Life Goals could not be refreshed. Existing local data '
            'was not changed.',
      );
    }
  }

  Future<IndicatorDetail?> readDetail(
    String indicatorKey,
    IndicatorPeriod period,
  ) {
    return _repository.readDetail(
      profileId: _profileId,
      indicatorKey: indicatorKey,
      period: period,
      today: ref.read(plannerDateSourceProvider).today(),
    );
  }

  Future<void> setTarget({
    required String indicatorKey,
    required IndicatorPeriod period,
    required IndicatorAmount? value,
  }) async {
    final ids = ref.read(indicatorIdentifierSourceProvider);
    await _repository.saveTarget(
      profileId: _profileId,
      startDay: ref.read(startOfWeekProvider),
      draft: IndicatorTargetRevisionDraft(
        id: ids.nextUuid(),
        operationId: ids.nextUuid(),
        indicatorKey: indicatorKey,
        period: period,
        value: value,
      ),
    );
    if (!_disposed) {
      await refresh();
    }
  }

  Future<void> saveGoal({
    required String indicatorKey,
    required IndicatorGoalPeriod period,
    required IndicatorAmount? value,
  }) async {
    final ids = ref.read(indicatorIdentifierSourceProvider);
    await _repository.saveGoal(
      profileId: _profileId,
      startDay: ref.read(startOfWeekProvider),
      draft: IndicatorGoalRevisionDraft(
        id: ids.nextUuid(),
        operationId: ids.nextUuid(),
        indicatorKey: indicatorKey,
        period: period,
        value: value,
      ),
    );
    if (!_disposed) {
      await refresh();
    }
  }

  Future<IndicatorGoalSnapshot> readGoal({
    required String indicatorKey,
    required IndicatorGoalPeriod period,
  }) {
    return _repository.readGoal(
      profileId: _profileId,
      indicatorKey: indicatorKey,
      period: period,
      today: ref.read(plannerDateSourceProvider).today(),
    );
  }

  Future<List<IndicatorGoalSnapshot>> readGoalHistory({
    required String indicatorKey,
    required IndicatorGoalPeriodType periodType,
    required PlannerDate anchor,
  }) {
    return _repository.readGoalHistory(
      profileId: _profileId,
      indicatorKey: indicatorKey,
      periodType: periodType,
      anchor: anchor,
      today: ref.read(plannerDateSourceProvider).today(),
      startDay: ref.read(startOfWeekProvider),
    );
  }

  Future<void> renameIndicator({
    required String indicatorKey,
    required String label,
  }) async {
    await _repository.renameIndicator(
      profileId: _profileId,
      indicatorKey: indicatorKey,
      label: label,
    );
    if (!_disposed) {
      await refresh();
    }
  }

  Future<List<IndicatorTargetRevision>> readTargetHistory({
    required String indicatorKey,
    required PlannerDate periodStart,
  }) {
    return _repository.readTargetHistory(
      profileId: _profileId,
      indicatorKey: indicatorKey,
      periodStart: periodStart,
    );
  }
}
