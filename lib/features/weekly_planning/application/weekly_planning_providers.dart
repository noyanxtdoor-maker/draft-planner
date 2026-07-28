import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_repository.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

final weeklyPlanningRepositoryProvider = Provider<WeeklyPlanningRepository>((
  ref,
) {
  throw StateError(
    'WeeklyPlanningRepository must be overridden at the app root',
  );
});

final weeklyPlanningIdentifierProvider = Provider<IdentifierSource>((ref) {
  return const UuidIdentifierSource();
});

final weeklyPlanningProfileIdProvider = Provider<String>((ref) {
  final startup = ref.read(startupControllerProvider);
  if (startup is! StartupReady) {
    throw StateError('Weekly Planning requires a ready Local Profile');
  }
  return startup.profile.id;
});

final weeklyPlanProvider = FutureProvider.family<WeeklyPlan, PlannerDate>((
  ref,
  date,
) {
  final profileId = ref.read(weeklyPlanningProfileIdProvider);
  ref.watch(indicatorChangesProvider(profileId));
  return ref
      .read(weeklyPlanningRepositoryProvider)
      .openOrCreate(profileId: profileId, date: date);
});

final weeklyPlanByIdProvider = FutureProvider.family<WeeklyPlan?, String>((
  ref,
  planId,
) {
  return ref
      .read(weeklyPlanningRepositoryProvider)
      .readPlan(
        profileId: ref.read(weeklyPlanningProfileIdProvider),
        planId: planId,
      );
});

final weeklyPlanHistoryProvider = FutureProvider<List<WeeklyPlan>>((ref) {
  return ref
      .read(weeklyPlanningRepositoryProvider)
      .readHistory(ref.read(weeklyPlanningProfileIdProvider));
});

final weeklyPlanningTodayProvider = FutureProvider<PlannerDate>((ref) {
  return ref
      .read(weeklyPlanningRepositoryProvider)
      .todayForProfile(ref.read(weeklyPlanningProfileIdProvider));
});
