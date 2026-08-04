import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/indicators/application/indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
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

/// Reads the Temple Visit schedule directly from the canonical calendar
/// source. Home uses this small projection instead of retaining a potentially
/// stale legacy Home snapshot.
final nextTempleVisitProvider = FutureProvider<PlannerDate?>((ref) {
  final startup = ref.watch(startupControllerProvider);
  if (startup is! StartupReady) {
    throw StateError('Temple Visit schedule requires a ready Local Profile');
  }
  final today = ref.watch(plannerDateSourceProvider).today();
  // Calendar-event writes are included in the indicator change stream, so the
  // projection refreshes when an event is created, edited, or deleted.
  ref.watch(indicatorChangesProvider(startup.profile.id));
  return ref
      .read(indicatorRepositoryProvider)
      .readNextTempleVisit(profileId: startup.profile.id, today: today);
});

final indicatorPeriodSnapshotProvider =
    FutureProvider.family<HomeIndicatorSnapshot, IndicatorPeriod>((
      ref,
      period,
    ) {
      final startup = ref.read(startupControllerProvider);
      if (startup is! StartupReady) {
        throw StateError('Life Indicators require a ready Local Profile');
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

  IndicatorPeriod get currentPeriod =>
      IndicatorPeriod.currentWeek(ref.read(plannerDateSourceProvider).today());

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
        period: IndicatorPeriod.currentWeek(today),
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
            'Life Indicators could not be refreshed. Existing local data '
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
