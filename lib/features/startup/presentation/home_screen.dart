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

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // The Home quick control is intentionally serialized per canonical Goal.
  // This keeps rapid taps target-only and prevents duplicate writes from
  // racing against one another or reading a stale progress snapshot.
  static final Map<String, Future<void>> _dailyTargetQueues =
      <String, Future<void>>{};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerToday = ref.watch(plannerDateSourceProvider).today();
    final periodStart = IndicatorPeriod.currentWeek(plannerToday).start;
    final canonicalPlan = ref.watch(goalPlanningProvider(periodStart));
    final nextTempleVisit = ref.watch(nextTempleVisitProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(
        key: const Key('home-app-bar'),
        toolbarHeight: 66,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppTheme.outline),
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
          IconButton(
            key: const Key('home-notifications'),
            tooltip: 'Notifications',
            onPressed: () => context.push(RoutePaths.permissions),
            icon: const Icon(Icons.notifications_none_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(goalPlanningProvider(periodStart));
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
                  title: 'Weekly Life Indicators',
                  onViewAll: () => _openWeeklyPlanning(context, periodStart),
                  viewAllKey: const Key('home-wli-view-all'),
                ),
                const SizedBox(height: 6),
                _CanonicalHomePlan(
                  plan: canonicalPlan,
                  monthGoalLabel: _monthGoalLabel(context, plannerToday),
                  nextTempleVisit: nextTempleVisit,
                  onOpenWeeklyPlanning: () =>
                      _openWeeklyPlanning(context, periodStart),
                  onOpenGoal: (progress) =>
                      _openGoalById(context, progress.goal.id),
                  onOpenTempleSchedule: () =>
                      _openTempleSchedule(context, ref, plannerToday),
                  onAdjustDailyTarget: (progress, delta) => _adjustDailyTarget(
                    ref,
                    progress,
                    delta: delta,
                    today: plannerToday,
                    periodStart: periodStart,
                  ),
                ),
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

  static void _openWeeklyPlanning(BuildContext context, PlannerDate start) {
    unawaited(context.push(RoutePaths.weeklyPlanningFor(start)));
  }

  static void _openGoalById(BuildContext context, String goalId) {
    unawaited(context.push(RoutePaths.goalEdit(goalId)));
  }

  static String _monthGoalLabel(BuildContext context, PlannerDate today) {
    return homeMonthGoalLabel(today, Localizations.localeOf(context));
  }

  static void _adjustDailyTarget(
    WidgetRef ref,
    GoalProgress progress, {
    required int delta,
    required PlannerDate today,
    required PlannerDate periodStart,
  }) {
    final goalId = progress.goal.id;
    final previous = _dailyTargetQueues[goalId] ?? Future<void>.value();
    final next = previous.then<void>((_) async {
      final repository = ref.read(goalRepositoryProvider);
      final latest = await repository.readProgress(
        profileId: ref.read(goalProfileIdProvider),
        goalId: goalId,
        today: today,
      );
      if (latest == null) {
        return;
      }

      final existingDaily = latest.dailyTarget.value;
      final current = existingDaily?.scaledValue ?? 0;
      final updated = math.max(0, current + delta);
      if (updated == current) {
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
            scaledValue: updated,
            scale: scale,
            unit: unit,
          ),
          weekly: latest.weeklyTarget.value,
          monthly: latest.monthlyTarget.value,
        ),
        today: today,
      );
      ref.invalidate(goalPlanningProvider(periodStart));
      ref.invalidate(activeGoalsProvider);
    });
    final handled = next.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Home daily target update failed: $error');
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
    required this.monthGoalLabel,
    required this.nextTempleVisit,
    required this.onOpenWeeklyPlanning,
    required this.onOpenGoal,
    required this.onOpenTempleSchedule,
    required this.onAdjustDailyTarget,
  });

  final AsyncValue<GoalPlanningSnapshot> plan;
  final String monthGoalLabel;
  final PlannerDate? nextTempleVisit;
  final VoidCallback onOpenWeeklyPlanning;
  final ValueChanged<GoalProgress> onOpenGoal;
  final VoidCallback onOpenTempleSchedule;
  final void Function(GoalProgress progress, int delta) onAdjustDailyTarget;

  @override
  Widget build(BuildContext context) {
    return plan.when(
      loading: () => const SizedBox(
        key: Key('home-canonical-plan-loading'),
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox(
        key: Key('home-canonical-plan-error'),
        height: 96,
        child: Center(child: Text('Weekly Life Indicators unavailable.')),
      ),
      data: (value) {
        final hasActiveGoals =
            value.daily != null ||
            value.weekly.isNotEmpty ||
            value.monthly != null;
        if (!hasActiveGoals) {
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
              nextTempleVisit: nextTempleVisit,
              onOpenGoal: onOpenGoal,
              onOpenTempleSchedule: onOpenTempleSchedule,
              onAdjustDailyTarget: onAdjustDailyTarget,
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton(
                key: const Key('weekly-targets-button'),
                onPressed: onOpenWeeklyPlanning,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 40),
                  fixedSize: const Size(160, 40),
                  textStyle: AppTypography.button,
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: AppTheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: const Text('Planning'),
              ),
            ),
          ],
        );
      },
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
                  foregroundColor: AppTheme.rose,
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
            foregroundColor: Colors.white,
            fixedSize: const Size(160, 40),
            side: const BorderSide(color: AppTheme.outline),
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
        child: const SizedBox(
          height: 8,
          child: ColoredBox(color: AppTheme.outline),
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
  });

  final GoalPlanningSnapshot plan;
  final String monthGoalLabel;
  final PlannerDate? nextTempleVisit;
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
            // The daily card carries two 48 dp controls in addition to its
            // title/value pair.  Give that integrated surface enough vertical
            // room for the control hit targets instead of squeezing them into
            // the compact weekly-card height.
            height: MediaQuery.sizeOf(context).width < 380
                ? (136 * MediaQuery.textScalerOf(context).scale(1))
                      .clamp(136.0, 220.0)
                      .toDouble()
                : 88,
            child: _goalCard(
              context,
              daily,
              wide: true,
              asideLabel: "Today's Goal",
              asideValue: _ratio(daily.dailyActual, daily.dailyTarget),
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
      onTap: () => onOpenGoal(progress),
    );
  }

  LifeIndicatorSummary _summaryFor(GoalProgress progress) {
    final target = progress.weeklyTarget;
    final unit = target.value?.unit ?? progress.weeklyActual.unit;
    return LifeIndicatorSummary(
      key: progress.goal.indicatorKey ?? 'goal-${progress.goal.id}',
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

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Card(
        key: Key('home-indicator-${indicator.key}'),
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF414649)),
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
      ),
    );
  }

  Widget _compact(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _goalIcon(size: 36),
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
                '${indicator.actual.display}/${indicator.target.display}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 21,
                  height: 23 / 21,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.rose,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // At the narrowest supported width, stacking the daily content and
        // its control surface preserves the full labels and both hit targets.
        // The approved-width layout remains a single integrated row.
        if (hasDailyControls && constraints.maxWidth < 325) {
          return Column(
            children: <Widget>[
              Expanded(child: _wideContent(context)),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _WideAside(
                  label: asideLabel!,
                  value: asideValue!,
                  onMinus: onDailyTargetMinus,
                  onPlus: onDailyTargetPlus,
                ),
              ),
            ],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: _wideContent(context)),
            const SizedBox(width: 10),
            _WideAside(
              label: asideLabel!,
              value: asideValue!,
              onMinus: onDailyTargetMinus,
              onPlus: onDailyTargetPlus,
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
        _goalIcon(size: 40),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                indicator.label,
                maxLines: onDailyTargetPlus == null ? 1 : 2,
                overflow: TextOverflow.clip,
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
                    foregroundColor: AppTheme.rose,
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
                      '${indicator.actual.display}/${indicator.target.display}',
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
                        ? AppTheme.rose
                        : Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalIcon({required double size}) {
    return GoalIcon(
      iconId: goal?.iconId,
      size: size,
      semanticLabel: '${indicator.label} goal icon',
      fallbackIcon: goalIconFallbackForRole(goal?.role),
      color: AppTheme.rose,
    );
  }
}

final class _WideAside extends StatelessWidget {
  const _WideAside({
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
  });

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final hasControls = onMinus != null && onPlus != null;
    return SizedBox(
      key: onPlus == null && onMinus == null
          ? null
          : const Key('home-daily-target-quick-control'),
      width: hasControls ? 192 : 106,
      height: hasControls ? 72 : 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hasControls ? 12 : 10),
          child: _WideAsideContent(
            label: label,
            value: value,
            hasControls: hasControls,
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
  });

  final String label;
  final String value;
  final bool hasControls;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

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
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 22,
              height: 24 / 22,
              fontWeight: FontWeight.w600,
              color: AppTheme.rose,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(fontSize: 14, height: 18 / 14),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 22,
                  height: 24 / 22,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.rose,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('home-daily-target-minus'),
                tooltip: 'Decrease daily target',
                onPressed: onMinus,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.remove, size: 24, color: AppTheme.rose),
              ),
              IconButton(
                key: const Key('home-daily-target-plus'),
                tooltip: 'Increase daily target',
                onPressed: onPlus,
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add, size: 24, color: AppTheme.rose),
              ),
            ],
          ),
        ),
      ],
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
        side: const BorderSide(color: Color(0xFF414649)),
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
                  border: Border.all(color: AppTheme.rose),
                ),
                child: Icon(icon, color: AppTheme.rose, size: 22),
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
                    child: const SizedBox(
                      height: 5,
                      child: LinearProgressIndicator(
                        value: .45,
                        backgroundColor: Color(0xFF343638),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.rose,
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
