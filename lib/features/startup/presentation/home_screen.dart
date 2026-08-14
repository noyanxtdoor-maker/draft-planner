import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';
import 'package:rmplanner/features/planner/presentation/contextual_create_fab.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

/// Returns the month-specific label shown beside the canonical monthly Goal.
///
/// The label is intentionally derived at render time. It is not a Goal title,
/// persisted field, activity entry, or outbox payload.
String homeMonthGoalLabel(PlannerDate today, Locale locale) {
  final month = DateFormat.LLLL(
    locale.toLanguageTag(),
  ).format(today.asLocalDate);
  return '$month Goal';
}

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  // The Home quick control runs one coalescing persistence drain per canonical
  // Goal. Rapid taps update the shared desired target instead of opening
  // competing read-modify-write operations.
  final Map<String, Future<void>> _dailyTargetQueues = <String, Future<void>>{};

  // Optimistic Today's Goal target overlay. The visible target reacts in the
  // same frame as the tap while the canonical read-modify-write queue runs
  // behind it; entries are pruned once the repository value catches up.
  // Keys are the canonical Goal IDs (only the daily Goal uses the stepper).
  final Map<String, int> _optimisticDailyTargets = <String, int>{};

  /// Canonical daily target captured when the first pending tap landed.
  /// Re-seeded whenever the canonical value moves independently, so an
  /// external edit cannot make the optimistic value stale forever.
  final Map<String, int> _optimisticBases = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final plannerToday = ref.watch(plannerDateSourceProvider).today();
    final startOfWeek = ref.watch(startOfWeekProvider);
    // A2: form period-family keys only after the initial persisted
    // start-of-week read is confirmed, so a provisional Monday-keyed family
    // never starts for a configured non-Monday week.
    final startOfWeekReady = ref.watch(
      startOfWeekInitialReadProvider,
    ).hasValue;
    final PlannerDate? periodStart = startOfWeekReady
        ? IndicatorPeriod.currentWeek(
            plannerToday,
            startDay: startOfWeek,
          ).start
        : null;
    final canonicalPlan = periodStart == null
        ? null
        : ref.watch(goalPlanningProvider(periodStart));
    // Plan-established signal: a WeeklyPlans row exists for the exact
    // resolved current period.  Read-only; never creates a row here.
    final established = periodStart == null
        ? null
        : ref.watch(weeklyPlanEstablishedProvider(periodStart)).value;
    _reconcileOptimisticTargets(canonicalPlan?.value);
    final planValue = canonicalPlan?.value;
    final optimisticDailyTarget = planValue?.daily == null
        ? null
        : _optimisticDailyTargets[planValue!.daily!.goal.id];
    final nextTempleVisit = ref.watch(nextTempleVisitProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        key: const Key('home-app-bar'),
        toolbarHeight: 66,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppTheme.outlineOf(context)),
          ),
        ),
        title: const Text('Home', key: Key('home-title')),
        leading: Builder(
          builder: (innerContext) => IconButton(
            key: const Key('home-hamburger'),
            tooltip: 'Open global navigation',
            onPressed: () => GlobalDrawerScope.of(innerContext).open(),
            icon: const Icon(Icons.menu),
          ),
        ),
        actions: <Widget>[
          // Pack 3: the Home bell opens the canonical local Messages screen,
          // never Android notification permissions.
          IconButton(
            key: const Key('home-messages'),
            tooltip: 'Messages',
            onPressed: () => context.push(RoutePaths.messages),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: RefreshIndicator(
            onRefresh: () async {
              final start = periodStart;
              if (start != null) {
                ref.invalidate(goalPlanningProvider(start));
              }
              ref.invalidate(nextTempleVisitProvider);
              await ref.read(nextTempleVisitProvider.future);
            },
            child: ListView(
              key: const Key('home-indicator-list'),
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                _homeBottomInset(context),
              ),
              children: <Widget>[
                _SectionHeader(
                  // Planner Polish Delta 2: the visible Home heading is
                  // "Life Goals".  Domain, provider, and database identifiers
                  // keep the canonical WLI naming.
                  title: 'Life Goals',
                  onViewAll: () {
                    final start = periodStart;
                    if (start != null) {
                      _openWeeklyPlanning(context, ref, start);
                    }
                  },
                  viewAllKey: const Key('home-wli-view-all'),
                ),
                const SizedBox(height: 6),
                _CanonicalHomePlan(
                  plan: canonicalPlan,
                  established: established,
                  monthGoalLabel: _monthGoalLabel(context, plannerToday),
                  optimisticDailyTarget: optimisticDailyTarget,
                  nextTempleVisit: nextTempleVisit,
                  onOpenWeeklyPlanning: () {
                    final start = periodStart;
                    if (start != null) {
                      _openWeeklyPlanning(context, ref, start);
                    }
                  },
                  onOpenGoal: (progress) =>
                      _openGoalById(context, progress.goal.id),
                  onOpenTempleSchedule: () =>
                      _openTempleSchedule(context, ref, plannerToday),
                  onAdjustDailyTarget: (progress, delta) {
                    final start = periodStart;
                    if (start == null) {
                      return;
                    }
                    _adjustDailyTarget(
                      ref,
                      progress,
                      delta: delta,
                      today: plannerToday,
                      periodStart: start,
                    );
                  },
                ),
                const SizedBox(height: 22),
                const _MajorSectionSeparator(),
                const SizedBox(height: 10),
                _SectionHeader(
                  title: 'Active Pathways',
                  onViewAll: () => _showPathwayMessage(context),
                  viewAllKey: const Key('home-pathways-view-all'),
                ),
                const SizedBox(height: 10),
                const _PathwaysCard(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: ContextualCreateFab(
        destination: CreateActionDestination.home,
        onSelected: (action) => _handleCreate(context, ref, action),
      ),
    );
  }

  static double _homeBottomInset(BuildContext context) {
    final navigationHeight =
        NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
    const fabDiameter = 56.0;
    const fabBottomMargin = 16.0;
    const breathingRoom = 24.0;
    return math.max(
      breathingRoom,
      navigationHeight +
          MediaQuery.viewPaddingOf(context).bottom +
          fabDiameter +
          fabBottomMargin +
          breathingRoom,
    );
  }

  /// Opens the current-period Goal Planning flow immediately.  The destination
  /// owns idempotent plan establishment; Start Planning / View All / the Goal
  /// Planning button all converge here.  Historical weeks are never created.
  static void _openWeeklyPlanning(
    BuildContext context,
    WidgetRef ref,
    PlannerDate start,
  ) {
    unawaited(
      context.push(RoutePaths.weeklyPlanningFor(start)).then((_) {
        if (context.mounted) {
          ref.invalidate(weeklyPlanEstablishedProvider(start));
        }
      }),
    );
  }

  static void _openGoalById(BuildContext context, String goalId) {
    unawaited(context.push(RoutePaths.goalEdit(goalId)));
  }

  static String _monthGoalLabel(BuildContext context, PlannerDate today) {
    return homeMonthGoalLabel(today, Localizations.localeOf(context));
  }

  /// Drop optimistic entries whose canonical value has caught up. Called from
  /// [build] after watching the canonical plan; mutating the maps without
  /// [setState] is safe because the rendered value is identical either way.
  void _reconcileOptimisticTargets(GoalPlanningSnapshot? plan) {
    final daily = plan?.daily;
    if (daily == null) {
      return;
    }
    final goalId = daily.goal.id;
    final optimistic = _optimisticDailyTargets[goalId];
    if (optimistic == null) {
      return;
    }
    // The active drain owns the overlay until it has observed the last tap.
    // A canonical emission for an intermediate write must not discard a newer
    // desired value that is still waiting to be persisted.
    if (_dailyTargetQueues.containsKey(goalId)) {
      return;
    }
    final canonical = daily.dailyTarget.value?.scaledValue;
    final base = _optimisticBases[goalId];
    final canonicalCaughtUp = canonical != null && canonical == optimistic;
    final canonicalMovedElsewhere =
        canonical != null && base != null && canonical != base;
    if (canonicalCaughtUp || canonicalMovedElsewhere) {
      _optimisticDailyTargets.remove(goalId);
      _optimisticBases.remove(goalId);
    }
  }

  /// Immediate Today's Goal stepper.
  ///
  /// The visible target changes on the same frame as the tap (optimistic
  /// overlay) while the canonical read-modify-write queue persists safely
  /// behind it. Taps are serialized per Goal, never lost, and never turn
  /// into duplicate repository operations; the optimistic value is pruned
  /// once the repository value catches up, and a failed write rolls the
  /// display back to the canonical value.
  void _adjustDailyTarget(
    WidgetRef ref,
    GoalProgress progress, {
    required int delta,
    required PlannerDate today,
    required PlannerDate periodStart,
  }) {
    final goalId = progress.goal.id;
    final canonical = progress.dailyTarget.value?.scaledValue ?? 0;
    final storedBase = _optimisticBases[goalId];
    final displayed = _optimisticDailyTargets[goalId];
    // Re-seed the base whenever the canonical value moved independently of
    // our pending taps (an external edit or a restored plan).
    final base = storedBase != null && canonical == storedBase
        ? storedBase
        : canonical;
    final visibleTarget = displayed ?? base;
    final updated = math.max(0, visibleTarget + delta);
    if (updated == visibleTarget) {
      // Clamped at the zero minimum; nothing visible to change.
      return;
    }
    setState(() {
      _optimisticBases[goalId] = base;
      _optimisticDailyTargets[goalId] = updated;
    });

    if (_dailyTargetQueues.containsKey(goalId)) {
      return;
    }
    final next = _persistDailyTarget(
      ref,
      goalId: goalId,
      today: today,
    );
    final handled = next.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Home daily target update failed: $error');
      // Honest rollback: the canonical store did not move, so drop the
      // optimistic overlay and reconcile from the repository.
      if (mounted) {
        setState(() {
          _optimisticDailyTargets.remove(goalId);
          _optimisticBases.remove(goalId);
        });
      }
      ref.invalidate(goalPlanningProvider(periodStart));
      ref.invalidate(activeGoalsProvider);
    });
    _dailyTargetQueues[goalId] = handled;
    unawaited(
      handled.then<void>((_) {
        if (identical(_dailyTargetQueues[goalId], handled)) {
          unawaited(_dailyTargetQueues.remove(goalId));
        }
      }),
    );
  }

  /// Persists the latest displayed target for one Goal. Rapid taps update the
  /// shared optimistic value, so a burst is coalesced into the fewest durable
  /// writes possible without dropping the final requested value.
  Future<void> _persistDailyTarget(
    WidgetRef ref, {
    required String goalId,
    required PlannerDate today,
  }) async {
    final repository = ref.read(goalRepositoryProvider);
    while (true) {
      final latest = await repository.readProgress(
        profileId: ref.read(goalProfileIdProvider),
        goalId: goalId,
        today: today,
        startDay: ref.read(startOfWeekProvider),
      );
      final desired = _optimisticDailyTargets[goalId];
      if (latest == null || desired == null) {
        return;
      }

      final existingDaily = latest.dailyTarget.value;
      final current = existingDaily?.scaledValue ?? 0;
      if (current == desired) {
        return;
      }
      final unit =
          existingDaily?.unit ?? latest.weeklyTarget.value?.unit ?? 'count';
      final scale =
          existingDaily?.scale ?? latest.weeklyTarget.value?.scale ?? 0;
      await repository.saveGoal(
        profileId: ref.read(goalProfileIdProvider),
        goalId: latest.goal.id,
        title: latest.goal.title,
        iconId: latest.goal.iconId,
        targets: GoalTargets(
          daily: IndicatorAmount(
            scaledValue: desired,
            scale: scale,
            unit: unit,
          ),
          weekly: latest.weeklyTarget.value,
          monthly: latest.monthlyTarget.value,
        ),
        today: today,
        startDay: ref.read(startOfWeekProvider),
      );
      if (_optimisticDailyTargets[goalId] == desired) {
        return;
      }
    }
  }

  static void _openTempleSchedule(
    BuildContext context,
    WidgetRef ref,
    PlannerDate date,
  ) {
    unawaited(
      launchCalendarEventCreation<void>(
        context,
        ref,
        CalendarEventCreationContext(
          source: 'home-temple-schedule',
          destinationPath: RoutePaths.calendarEventCreate,
          date: date,
          indicatorKey: 'temple_visit',
        ),
      ),
    );
  }

  static void _showPathwayMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pathways are not configured yet.')),
    );
  }

  void _handleCreate(
    BuildContext context,
    WidgetRef ref,
    ContextualCreateAction action,
  ) {
    final today = PlannerDate.fromDateTime(DateTime.now());
    switch (action) {
      case ContextualCreateAction.event:
        unawaited(
          launchCalendarEventCreation<void>(
            context,
            ref,
            CalendarEventCreationContext(
              source: 'home-fab',
              destinationPath: RoutePaths.calendarEventCreate,
              date: today,
            ),
          ),
        );
      case ContextualCreateAction.task:
        unawaited(
          context.push('${RoutePaths.taskCreate}?date=${today.iso8601}'),
        );
    }
  }
}

final class _CanonicalHomePlan extends StatelessWidget {
  const _CanonicalHomePlan({
    required this.plan,
    required this.established,
    required this.monthGoalLabel,
    required this.nextTempleVisit,
    required this.onOpenWeeklyPlanning,
    required this.onOpenGoal,
    required this.onOpenTempleSchedule,
    required this.onAdjustDailyTarget,
    this.optimisticDailyTarget,
  });

  /// Null while the start-of-week preference is still being confirmed, in
  /// which case no period family has been formed yet (A2).
  final AsyncValue<GoalPlanningSnapshot>? plan;

  /// True when a WeeklyPlans row exists for the exact resolved current period;
  /// null while the read-only existence check is still loading (so the Home
  /// never flashes Start Planning for an already-established period).
  final bool? established;
  final String monthGoalLabel;
  final PlannerDate? nextTempleVisit;
  final int? optimisticDailyTarget;
  final VoidCallback onOpenWeeklyPlanning;
  final ValueChanged<GoalProgress> onOpenGoal;
  final VoidCallback onOpenTempleSchedule;
  final void Function(GoalProgress progress, int delta) onAdjustDailyTarget;

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    if (plan == null) {
      // A2: start-of-week readiness pending — honest section skeleton, no
      // fabricated names, actuals, targets, or established state.
      return const _LifeGoalsSkeleton();
    }
    return plan.when(
      skipLoadingOnReload: true,
      loading: () => const _LifeGoalsSkeleton(),
      error: (error, stackTrace) => const SizedBox(
        key: Key('home-canonical-plan-error'),
        height: 96,
        child: Center(child: Text('Life Goals unavailable.')),
      ),
      data: (value) {
        if (established == null) {
          return const _LifeGoalsSkeleton();
        }
        final hasActiveGoals =
            value.daily != null ||
            value.weekly.isNotEmpty ||
            value.monthly != null;
        // Unestablished period: hide the Life Goal card grid, keep the
        // section header + View All above, and show centered Start Planning.
        // Established-but-empty is treated the same defensive way.
        if (!established! || !hasActiveGoals) {
          return Align(
            alignment: Alignment.center,
            child: _StartPlanningButton(onPressed: onOpenWeeklyPlanning),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _CanonicalIndicatorGrid(
              plan: value,
              monthGoalLabel: monthGoalLabel,
              optimisticDailyTarget: optimisticDailyTarget,
              nextTempleVisit: nextTempleVisit,
              onOpenGoal: onOpenGoal,
              onOpenTempleSchedule: onOpenTempleSchedule,
              onAdjustDailyTarget: onAdjustDailyTarget,
            ),
            const SizedBox(height: 16),
            // The visible pill stays compact (118-134 x 34-38) while the outer
            // hit area keeps a minimum 48 dp touch target.
            SizedBox(
              key: const Key('weekly-targets-hit-area'),
              height: 48,
              child: Center(
                child: OutlinedButton(
                  key: const Key('weekly-targets-button'),
                  onPressed: onOpenWeeklyPlanning,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(126, 36),
                    fixedSize: const Size(126, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      height: 18 / 14,
                      fontWeight: FontWeight.w500,
                    ),
                    foregroundColor: AppTheme.onFillTextOf(context, 0.70),
                    side: BorderSide(color: AppTheme.outlineOf(context), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: const Text('Goal Planning'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Honest first-load placeholder for the Life Goals section (A2): the same
/// card-grid geometry as the confirmed content but with NO fabricated Goal
/// names, actuals, targets, established state, or numbers.  Rendered while
/// the start-of-week preference is being confirmed or while the genuine
/// initial period family has no confirmed snapshot yet.
final class _LifeGoalsSkeleton extends StatelessWidget {
  const _LifeGoalsSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = AppTheme.blockOf(context);
    return Column(
      key: const Key('home-life-goals-skeleton'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _skeletonCard(block),
        const SizedBox(height: 6),
        _skeletonPair(block),
        const SizedBox(height: 6),
        _skeletonPair(block),
        const SizedBox(height: 6),
        _skeletonCard(block),
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 126,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: AppTheme.outlineOf(context)),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _skeletonCard(Color block) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: block,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  static Widget _skeletonPair(Color block) {
    return SizedBox(
      height: 60,
      child: Row(
        children: <Widget>[
          Expanded(child: _skeletonCard(block)),
          const SizedBox(width: 10),
          Expanded(child: _skeletonCard(block)),
        ],
      ),
    );
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onViewAll,
    required this.viewAllKey,
  });

  final String title;
  final VoidCallback onViewAll;
  final Key viewAllKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 30,
          child: Row(
            children: <Widget>[
              Expanded(child: Text(title, style: AppTypography.sectionTitle)),
              TextButton(
                key: viewAllKey,
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 30),
                  padding: EdgeInsets.zero,
                  textStyle: AppTypography.button,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1),
      ],
    );
  }
}

final class _StartPlanningButton extends StatelessWidget {
  const _StartPlanningButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('home-start-weekly-planning'),
      height: 42,
      width: 160,
      child: Center(
        child: OutlinedButton(
          key: const Key('weekly-targets-button'),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.onFillTextOf(context, 1.0),
            fixedSize: const Size(160, 40),
            side: BorderSide(color: AppTheme.outlineOf(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            textStyle: AppTypography.button,
          ),
          child: const Text('Start Planning'),
        ),
      ),
    );
  }
}

final class _MajorSectionSeparator extends StatelessWidget {
  const _MajorSectionSeparator();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return SizedBox(
      key: const Key('home-major-separator'),
      height: 8,
      child: OverflowBox(
        alignment: Alignment.center,
        minWidth: width,
        maxWidth: width,
        child: SizedBox(
          height: 8,
          child: ColoredBox(color: AppTheme.outlineOf(context)),
        ),
      ),
    );
  }
}

final class _CanonicalIndicatorGrid extends StatelessWidget {
  const _CanonicalIndicatorGrid({
    required this.plan,
    required this.monthGoalLabel,
    required this.nextTempleVisit,
    required this.onOpenGoal,
    required this.onOpenTempleSchedule,
    required this.onAdjustDailyTarget,
    this.optimisticDailyTarget,
  });

  final GoalPlanningSnapshot plan;
  final String monthGoalLabel;
  final PlannerDate? nextTempleVisit;
  final int? optimisticDailyTarget;
  final ValueChanged<GoalProgress> onOpenGoal;
  final VoidCallback onOpenTempleSchedule;
  final void Function(GoalProgress progress, int delta) onAdjustDailyTarget;

  @override
  Widget build(BuildContext context) {
    final daily = plan.daily;
    final monthly = plan.monthly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (daily != null)
          SizedBox(
            // Goal 1 derives its outer geometry from Goal 6: the same card
            // height, padding, border, radius, and icon alignment.  The
            // Today's Goal inset is the only shaded surface and stays compact
            // with 48 dp tap targets that do not inflate its visual size.
            height: 60,
            child: _goalCard(
              context,
              daily,
              wide: true,
              asideLabel: "Today's Goal",
              // The aside reflects the optimistic target immediately when a
              // quick-control tap is pending; the canonical value otherwise.
              asideValue: _dailyAsideValue(daily, optimisticDailyTarget),
              // The minus control is hidden (a reserved, non-interactive slot)
              // while the visible Daily Target is zero, so the plus never
              // jumps and the optimistic overlay never exposes a minus that
              // would target a negative value.
              dailyTargetIsZero: _dailyTargetIsZero(
                daily,
                optimisticDailyTarget,
              ),
              onDailyTargetMinus: () => onAdjustDailyTarget(daily, -1),
              onDailyTargetPlus: () => onAdjustDailyTarget(daily, 1),
            ),
          ),
        if (daily != null && plan.weekly.isNotEmpty) const SizedBox(height: 6),
        for (var row = 0; row < plan.weekly.length; row += 2) ...<Widget>[
          SizedBox(
            height: 60,
            child: Row(
              children: <Widget>[
                Expanded(child: _goalCard(context, plan.weekly[row])),
                if (row + 1 < plan.weekly.length) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(child: _goalCard(context, plan.weekly[row + 1])),
                ],
              ],
            ),
          ),
          if (row + 2 < plan.weekly.length) const SizedBox(height: 6),
        ],
        if (monthly != null) ...<Widget>[
          if (daily != null || plan.weekly.isNotEmpty)
            const SizedBox(height: 6),
          SizedBox(
            height: 60,
            child: _goalCard(
              context,
              monthly,
              wide: true,
              asideLabel: monthGoalLabel,
              asideValue: _ratio(monthly.monthlyActual, monthly.monthlyTarget),
              secondaryLabel: monthly.goal.indicatorKey == 'temple_visit'
                  ? nextTempleVisit == null
                        ? 'Set Schedule'
                        : 'Next Visit: ${_formatNextVisit(context, nextTempleVisit!)}'
                  : null,
              onSecondaryTap:
                  monthly.goal.indicatorKey == 'temple_visit' &&
                      nextTempleVisit == null
                  ? onOpenTempleSchedule
                  : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _goalCard(
    BuildContext context,
    GoalProgress progress, {
    bool wide = false,
    String? asideLabel,
    String? asideValue,
    String? secondaryLabel,
    VoidCallback? onSecondaryTap,
    VoidCallback? onDailyTargetMinus,
    VoidCallback? onDailyTargetPlus,
    bool dailyTargetIsZero = false,
  }) {
    return _IndicatorCard(
      indicator: _summaryFor(progress),
      goal: progress.goal,
      wide: wide,
      asideLabel: asideLabel,
      asideValue: asideValue,
      secondaryLabel: secondaryLabel,
      onSecondaryTap: onSecondaryTap,
      onDailyTargetMinus: onDailyTargetMinus,
      onDailyTargetPlus: onDailyTargetPlus,
      dailyTargetIsZero: dailyTargetIsZero,
      onTap: () => onOpenGoal(progress),
    );
  }

  LifeIndicatorSummary _summaryFor(GoalProgress progress) {
    final target = progress.weeklyTarget;
    final unit = target.value?.unit ?? progress.weeklyActual.unit;
    return LifeIndicatorSummary(
      // The rendered Home identity belongs to the canonical Goal row, not
      // the legacy indicator definition.  This is what lets a replacement
      // Goal occupy the same role without inheriting the default Goal's
      // identity or a stale indicator snapshot.
      key: 'goal-${progress.goal.id}',
      label: progress.goal.title,
      unit: unit,
      position: progress.goal.activeSlotIndex ?? 0,
      goalId: progress.goal.id,
      actual: progress.weeklyActual,
      target: target,
      scheduledPotential: IndicatorAmount(
        scaledValue: 0,
        scale: progress.weeklyActual.scale,
        unit: unit,
      ),
      scheduledSources: const <ScheduledIndicatorSource>[],
      projectionState: IndicatorProjectionState.current,
    );
  }

  String _ratio(IndicatorAmount actual, IndicatorTarget target) {
    return '${actual.display}/${target.value?.display ?? '0'}';
  }

  /// Renders the Today's Goal ratio. When an optimistic target is pending it
  /// is formatted with the canonical target's scale/unit so the visible value
  /// changes on the same frame as the tap without fabricating progress.
  String _dailyAsideValue(GoalProgress progress, int? optimisticTarget) {
    final target = progress.dailyTarget.value;
    final targetDisplay = optimisticTarget == null
        ? target?.display ?? '0'
        : IndicatorAmount(
            scaledValue: optimisticTarget,
            scale: target?.scale ?? 0,
            unit: target?.unit ?? 'count',
          ).display;
    return '${progress.dailyActual.display}/$targetDisplay';
  }

  bool _dailyTargetIsZero(GoalProgress progress, int? optimisticTarget) {
    final value =
        optimisticTarget ?? progress.dailyTarget.value?.scaledValue ?? 0;
    return value == 0;
  }

  String _formatNextVisit(BuildContext context, PlannerDate date) {
    return MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(date.asLocalDate);
  }
}

final class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.indicator,
    required this.goal,
    required this.wide,
    required this.onTap,
    this.asideLabel,
    this.asideValue,
    this.secondaryLabel,
    this.onSecondaryTap,
    this.onDailyTargetMinus,
    this.onDailyTargetPlus,
    this.dailyTargetIsZero = false,
  });

  final LifeIndicatorSummary indicator;
  final Goal? goal;
  final bool wide;
  final String? asideLabel;
  final String? asideValue;
  final VoidCallback onTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onDailyTargetMinus;
  final VoidCallback? onDailyTargetPlus;
  final bool dailyTargetIsZero;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      key: Key(
        'home-indicator-goal-${goal?.id ?? indicator.goalId ?? indicator.key}',
      ),
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.cardBorderOf(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: wide ? _wide(context) : _compact(context),
          ),
        ),
      ),
    );

    // Keep the pre-Pack-1 selector as a render-box-sized compatibility alias
    // for existing tests and automation.  It is not used for data binding or
    // Goal lookup; the Card itself is always keyed by the Goal identity.
    final legacyIndicatorKey = goal?.indicatorKey;
    final keyedCard = legacyIndicatorKey == null
        ? card
        : SizedBox(key: Key('home-indicator-$legacyIndicatorKey'), child: card);
    return SizedBox.expand(child: keyedCard);
  }

  Widget _compact(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _goalIcon(size: 36, context: context),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  indicator.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 14,
                    height: 16 / 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                _homeRatioText(indicator.actual, indicator.target),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 21,
                  height: 23 / 21,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wide(BuildContext context) {
    final hasDailyControls =
        onDailyTargetMinus != null && onDailyTargetPlus != null;
    // A single horizontal composition is preserved at every supported phone
    // width.  The left content flexes and the Today's Goal inset takes a
    // proportional share of the inner width, so nothing stacks or overflows
    // at 360, 393, or 411 dp.
    return LayoutBuilder(
      builder: (context, constraints) {
        // The Today's Goal inset needs a wider share of the Goal 1 card than
        // the monthly aside: it must hold the left-pinned label, the progress
        // value centered beneath it, and the minus/plus controls on the right.
        // 0.58 of the inner width (capped 172-206 dp) keeps the label at
        // readable scale on 360 dp phones while leaving the Goal title room.
        final asideWidth = hasDailyControls
            ? (constraints.maxWidth * 0.58).clamp(172.0, 206.0)
            : null;
        return Row(
          children: <Widget>[
            Expanded(child: _wideContent(context)),
            const SizedBox(width: 10),
            _WideAside(
              label: asideLabel!,
              value: asideValue!,
              onMinus: onDailyTargetMinus,
              onPlus: onDailyTargetPlus,
              minusEnabled: !dailyTargetIsZero,
              width: asideWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _wideContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _goalIcon(size: 40, context: context),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                indicator.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  height: 18 / 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (secondaryLabel == 'Set Schedule' && onSecondaryTap != null)
                TextButton(
                  key: const Key('home-temple-schedule'),
                  onPressed: onSecondaryTap,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text(
                    'Set Schedule',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 14,
                      height: 18 / 14,
                    ),
                  ),
                )
              else
                Text(
                  secondaryLabel ??
                      _homeRatioText(indicator.actual, indicator.target),
                  maxLines: secondaryLabel == null ? 1 : 2,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: secondaryLabel == null ? 22 : 14,
                    height: secondaryLabel == null ? 24 / 22 : 18 / 14,
                    fontWeight: secondaryLabel == null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: secondaryLabel == null
                        ? Theme.of(context).colorScheme.primary
                        : AppTheme.onFillTextOf(context, 0.70),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalIcon({required double size, required BuildContext context}) {
    return GoalIcon(
      iconId: goal?.iconId,
      size: size,
      semanticLabel: '${indicator.label} goal icon',
      fallbackIcon: goalIconFallbackForRole(goal?.role),
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

final class _WideAside extends StatelessWidget {
  const _WideAside({
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
    this.minusEnabled = true,
    this.width,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool minusEnabled;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final hasControls = onMinus != null && onPlus != null;
    return SizedBox(
      key: onPlus == null && onMinus == null
          ? null
          : const Key('home-daily-target-quick-control'),
      width: width ?? (hasControls ? 165 : 106),
      height: hasControls ? 52 : 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasControls ? 10 : 10,
            vertical: hasControls ? 6 : 0,
          ),
          child: _WideAsideContent(
            label: label,
            value: value,
            hasControls: hasControls,
            minusEnabled: minusEnabled,
            onMinus: onMinus,
            onPlus: onPlus,
          ),
        ),
      ),
    );
  }
}

final class _WideAsideContent extends StatelessWidget {
  const _WideAsideContent({
    required this.label,
    required this.value,
    required this.hasControls,
    required this.onMinus,
    required this.onPlus,
    this.minusEnabled = true,
  });

  final String label;
  final String value;
  final bool hasControls;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool minusEnabled;

  @override
  Widget build(BuildContext context) {
    if (!hasControls) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 14, height: 16 / 14),
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 22,
              height: 24 / 22,
              fontWeight: FontWeight.w600,
              // Pack 3 final polish: the August Goal progress value uses the
              // same neutral primary text family as the Today's Goal inset.
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    // Approved Today's Goal inset layout:
    //   Today's Goal        <- label pinned to the left
    //      0/1        −   + <- value centered beneath the label, controls right
    // The value is centered relative to the label/progress block (never the
    // whole inset), the minus/plus controls sit on the right with deliberate
    // gaps, and the minus hides behind a reserved, non-interactive,
    // semantics-excluded slot while the Daily Target is zero so the plus never
    // jumps.  The block scales down gracefully on narrow phones instead of
    // overflowing.  Buttons keep 48 dp tap targets without inflating the
    // inset.  The progress value uses neutral primary text; only the controls
    // carry the accent.
    return Row(
      children: <Widget>[
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(fontSize: 14, height: 15 / 14),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 22,
                    height: 21 / 22,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (minusEnabled)
          _DailyTargetButton(
            key: const Key('home-daily-target-minus'),
            tooltip: 'Decrease daily target',
            icon: Icons.remove,
            onPressed: onMinus!,
          )
        else
          // Reserved invisible slot: same footprint as the minus
          // button so the plus keeps its exact position at zero.
          const ExcludeSemantics(child: SizedBox(width: 40)),
        const SizedBox(width: 6),
        _DailyTargetButton(
          key: const Key('home-daily-target-plus'),
          tooltip: 'Increase daily target',
          icon: Icons.add,
          onPressed: onPlus!,
        ),
      ],
    );
  }
}

/// The Today's Goal minus/plus control.
///
/// The visible icon stays compact (22 dp) so the inset does not grow to the
/// size of its touch targets.  NOTE: Flutter hit-tests the layout footprint
/// (40 x 20 inside the locked 60 dp shared card), so a tap that lands just
/// outside the button falls through to the Goal card and opens Edit Goal.
/// A true 48 x 48 hit area cannot coexist with the approved two-line inset
/// inside the shared Goal 6 geometry; the owner approved the current
/// footprint in the Pack 1A physical acceptance.
final class _DailyTargetButton extends StatelessWidget {
  const _DailyTargetButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          // A 40 dp layout footprint keeps the target/minus/plus row compact
          // on narrow phones.  The 48 x 48 OverflowBox only enlarges the
          // painted child; Flutter hit-tests the 40 x 20 layout box, so the
          // effective tap area is the button footprint itself.
          width: 40,
          height: 24,
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 48,
            maxWidth: 48,
            minHeight: 48,
            maxHeight: 48,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PathwaysCard extends StatelessWidget {
  const _PathwaysCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.cardBorderOf(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        children: <Widget>[
          _PathwayRow(
            key: Key('home-pathway-employment'),
            icon: Icons.work_outline,
            label: 'Employment',
            milestone: '3 of 7 milestones',
          ),
          Divider(height: 1),
          _PathwayRow(
            key: Key('home-pathway-education'),
            icon: Icons.school_outlined,
            label: 'Education',
            milestone: '2 of 6 milestones',
          ),
          Divider(height: 1),
          _PathwayRow(
            key: Key('home-pathway-documents'),
            icon: Icons.description_outlined,
            label: 'Documents',
            milestone: '4 of 8 milestones',
          ),
        ],
      ),
    );
  }
}

final class _PathwayRow extends StatelessWidget {
  const _PathwayRow({
    required this.icon,
    required this.label,
    required this.milestone,
    super.key,
  });

  final IconData icon;
  final String label;
  final String milestone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                  const Text(
                    'On Track',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.secondary,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 118,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    milestone,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.micro,
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      height: 5,
                      child: LinearProgressIndicator(
                        value: .45,
                        backgroundColor: AppTheme.raisedOf(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Home-only compact ratio text: an unset target renders as 0 (0/0) exactly
/// like an explicit zero.  Domain semantics stay untouched — Goal Planning and
/// Edit screens keep distinguishing notSet/null from explicit 0.
String _homeRatioText(IndicatorAmount actual, IndicatorTarget target) {
  return '${actual.display}/${target.value?.display ?? '0'}';
}
