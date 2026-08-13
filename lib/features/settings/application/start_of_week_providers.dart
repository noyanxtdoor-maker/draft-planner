import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/settings/application/start_of_week_repository.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final startOfWeekRepositoryProvider = Provider<StartOfWeekRepository>((ref) {
  throw StateError('StartOfWeekRepository must be overridden at the app root');
});

/// Canonical first day of the week (DateTime.monday .. DateTime.sunday) for
/// the current Local Profile.  Defaults to Monday when no preference exists.
///
/// This is the single read path every non-frozen weekly consumer uses; the
/// frozen Planner week view keeps reading the same stored column through its
/// own controller, so both agree by construction.
final startOfWeekProvider = NotifierProvider<StartOfWeekNotifier, int>(
  StartOfWeekNotifier.new,
);

final class StartOfWeekNotifier extends Notifier<int> {
  @override
  int build() {
    // Re-resolve the current profile whenever startup state changes (for
    // example, when onboarding completes and the Local Profile appears).
    ref.watch(startupControllerProvider);
    _load();
    return DateTime.monday;
  }

  void _load() {
    unawaited(refresh());
  }

  /// Re-reads the persisted preference without reconstructing this notifier.
  /// The last confirmed value remains visible until the read succeeds.
  Future<void> refresh() async {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      return;
    }
    await _loadFor(startup.profile.id);
  }

  Future<void> _loadFor(String profileId) async {
    try {
      final value = await ref
          .read(startOfWeekRepositoryProvider)
          .readStartOfWeek(profileId: profileId);
      state = value;
    } on Object {
      // Keep the last confirmed value (or the initial Monday default).
    }
  }

  /// Persists a new start day for the current Local Profile and applies it to
  /// the in-memory state so all watchers re-resolve their current period.
  Future<bool> setStartOfWeek(int startDay) async {
    final startup = ref.read(startupControllerProvider);
    if (startup is! StartupReady) {
      return false;
    }
    await ref.read(startOfWeekRepositoryProvider).saveStartOfWeek(
          profileId: startup.profile.id,
          startDay: startDay,
        );
    state = startDay;
    return true;
  }
}
