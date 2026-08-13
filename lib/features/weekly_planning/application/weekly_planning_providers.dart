import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
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
  final startDay = ref.watch(startOfWeekProvider);
  ref.watch(indicatorChangesProvider(profileId));
  return ref
      .read(weeklyPlanningRepositoryProvider)
      .openOrCreate(profileId: profileId, date: date, startDay: startDay);
});

/// True when a WeeklyPlans row already exists for the exact resolved period
/// start.  Read-only (never creates); Home uses this as the plan-established
/// signal for the current period.
final weeklyPlanEstablishedProvider = FutureProvider.family<bool, PlannerDate>((
  ref,
  periodStart,
) async {
  final profileId = ref.read(weeklyPlanningProfileIdProvider);
  final plan = await ref
      .read(weeklyPlanningRepositoryProvider)
      .readPlanForPeriod(
        profileId: profileId,
        periodStart: periodStart,
      );
  return plan != null;
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
