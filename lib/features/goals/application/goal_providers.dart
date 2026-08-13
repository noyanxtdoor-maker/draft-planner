import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/goals/application/goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  throw StateError('GoalRepository must be overridden at the app root');
});

final goalProfileIdProvider = Provider<String>((ref) {
  final startup = ref.read(startupControllerProvider);
  if (startup is! StartupReady) {
    throw StateError('Goals require a ready Local Profile');
  }
  return startup.profile.id;
});

final goalChangesProvider = StreamProvider.family<int, String>((
  ref,
  profileId,
) {
  return ref.read(goalRepositoryProvider).watchChanges(profileId);
});

final goalPlanningProvider =
    FutureProvider.family<GoalPlanningSnapshot, PlannerDate>((
      ref,
      periodStart,
    ) {
      final profileId = ref.read(goalProfileIdProvider);
      final today = ref.read(plannerDateSourceProvider).today();
      final startDay = ref.watch(startOfWeekProvider);
      ref.watch(goalChangesProvider(profileId));
      return ref
          .read(goalRepositoryProvider)
          .readPlanning(
            profileId: profileId,
            periodStart: periodStart,
            today: today,
            startDay: startDay,
          );
    });

final activeGoalsProvider = FutureProvider<List<Goal>>((ref) {
  final profileId = ref.read(goalProfileIdProvider);
  ref.watch(goalChangesProvider(profileId));
  return ref.read(goalRepositoryProvider).readActiveGoals(profileId);
});

/// Resolves a single Life Indicator (Goal) by its stable ID regardless of
/// status, so an Event linked to an archived indicator still renders its
/// name and icon while archived indicators stay hidden from new linking.
final goalByIdProvider = FutureProvider.family<Goal?, String>((ref, goalId) {
  final profileId = ref.read(goalProfileIdProvider);
  ref.watch(goalChangesProvider(profileId));
  return ref
      .read(goalRepositoryProvider)
      .readGoal(profileId: profileId, goalId: goalId);
});

final goalCapacityProvider = FutureProvider<GoalCapacity>((ref) {
  final profileId = ref.read(goalProfileIdProvider);
  ref.watch(goalChangesProvider(profileId));
  return ref.read(goalRepositoryProvider).readCapacity(profileId);
});
