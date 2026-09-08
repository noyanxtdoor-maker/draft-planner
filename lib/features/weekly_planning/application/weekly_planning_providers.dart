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

/// Read-only period lookup used by reminder routing and the completion seam;
/// unlike [weeklyPlanProvider], it never creates a historical plan row.
final weeklyPlanForPeriodProvider =
    FutureProvider.family<WeeklyPlan?, PlannerDate>((ref, periodStart) {
      return ref
          .read(weeklyPlanningRepositoryProvider)
          .readPlanForPeriod(
            profileId: ref.read(weeklyPlanningProfileIdProvider),
            periodStart: periodStart,
          );
    });

/// True when a WeeklyPlans row already exists for the exact resolved period
/// start.  Read-only (never creates) and lightweight (row existence only,
/// never the rich projection); Home uses this as the plan-established signal
/// for the current period.
final weeklyPlanEstablishedProvider = FutureProvider.family<bool, PlannerDate>((
  ref,
  periodStart,
) async {
  final profileId = ref.read(weeklyPlanningProfileIdProvider);
  return ref
      .read(weeklyPlanningRepositoryProvider)
      .periodExists(profileId: profileId, periodStart: periodStart);
});

/// Lightweight idempotent establishment of the exact current period row.
/// The Goal Planning screen gates on this instead of the rich projection so
/// route chrome and Goal rows never wait on indicator materialization.  Only
/// ever watched for the CURRENT period; historical weeks stay read-only.
final weeklyPlanEnsureProvider = FutureProvider.family<void, PlannerDate>((
  ref,
  periodStart,
) async {
  final profileId = ref.read(weeklyPlanningProfileIdProvider);
  final startDay = ref.watch(startOfWeekProvider);
  await ref
      .read(weeklyPlanningRepositoryProvider)
      .ensurePeriod(
        profileId: profileId,
        periodStart: periodStart,
        startDay: startDay,
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
