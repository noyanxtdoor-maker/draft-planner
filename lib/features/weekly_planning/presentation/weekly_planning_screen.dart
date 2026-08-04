import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/app_route_observer.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

final class WeeklyPlanningScreen extends ConsumerStatefulWidget {
  const WeeklyPlanningScreen({
    this.periodStart,
    this.initialManagementMode = false,
    super.key,
  });

  final PlannerDate? periodStart;
  final bool initialManagementMode;

  @override
  ConsumerState<WeeklyPlanningScreen> createState() =>
      _WeeklyPlanningScreenState();
}

final class _WeeklyPlanningScreenState
    extends ConsumerState<WeeklyPlanningScreen> {
  late bool _managementMode = widget.initialManagementMode;

  void _setManagementMode(bool value) {
    if (mounted && _managementMode != value) {
      setState(() => _managementMode = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final periodStart = widget.periodStart;
    final resolvedStart = periodStart == null
        ? ref.watch(weeklyPlanningTodayProvider).asData?.value
        : _mondayOf(periodStart);
    if (resolvedStart == null) {
      return Scaffold(
        appBar: _appBar(context),
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final plan = ref.watch(goalPlanningProvider(resolvedStart));
    return Scaffold(
      appBar: _appBar(context),
      body: SafeArea(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _Failure(
            message: error.toString(),
            onRetry: () => ref.invalidate(goalPlanningProvider(resolvedStart)),
          ),
          data: (value) => _GoalPlanBody(
            plan: value,
            managementMode: _managementMode,
            onManagementModeChanged: _setManagementMode,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const Key('weekly-plan-back-home'),
        tooltip: 'Back to Home',
        onPressed: () => context.go(RoutePaths.home),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Weekly Planning'),
      actions: <Widget>[
        if (!_managementMode)
          IconButton(
            key: const Key('goal-archive-button'),
            tooltip: 'Goal Archive',
            onPressed: () => context.push(RoutePaths.goalArchive),
            icon: const Icon(Icons.archive_outlined),
          ),
        if (!_managementMode)
          // Kept as a separate, read-only prior-plan entry point for the
          // already-approved Planner history behavior.
          IconButton(
            key: const Key('weekly-plan-history-button'),
            tooltip: 'Prior weeks',
            onPressed: () => context.go(RoutePaths.weeklyPlanningHistory),
            icon: const Icon(Icons.history),
          ),
      ],
    );
  }
}

final class _GoalPlanBody extends ConsumerStatefulWidget {
  const _GoalPlanBody({
    required this.plan,
    required this.managementMode,
    required this.onManagementModeChanged,
  });

  final GoalPlanningSnapshot plan;
  final bool managementMode;
  final ValueChanged<bool> onManagementModeChanged;

  @override
  ConsumerState<_GoalPlanBody> createState() => _GoalPlanBodyState();
}

final class _GoalPlanBodyState extends ConsumerState<_GoalPlanBody>
    with RouteAware {
  ModalRoute<void>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _route)) {
      return;
    }
    if (_route != null) {
      shellRouteObserver.unsubscribe(this);
    }
    _route = route;
    shellRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    shellRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    widget.onManagementModeChanged(false);
  }

  @override
  void didPop() {
    widget.onManagementModeChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final capacity = ref.watch(goalCapacityProvider).asData?.value;
    return Stack(
      children: <Widget>[
        ListView(
          key: const Key('weekly-plan-list'),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: <Widget>[
            _WeekNavigation(
              start: plan.periodStart,
              end: plan.periodEnd,
              canGoForward:
                  plan.periodStart.compareTo(_mondayOf(_today(ref))) < 0,
              onPrevious: () =>
                  _openWeek(context, plan.periodStart.addDays(-7)),
              onNext: plan.periodStart.compareTo(_mondayOf(_today(ref))) < 0
                  ? () => _openWeek(context, plan.periodStart.addDays(7))
                  : null,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: widget.managementMode
                  ? const Key('weekly-plan-cancel-management')
                  : const Key('weekly-plan-create-goal'),
              onPressed: widget.managementMode
                  ? _exitManagementMode
                  : () => unawaited(_createGoal(context, capacity)),
              icon: Icon(
                widget.managementMode ? Icons.close : Icons.add,
                size: 20,
              ),
              label: Text(widget.managementMode ? 'Cancel' : 'Create Goal'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: widget.managementMode
                    ? Colors.white70
                    : AppTheme.rose,
                side: BorderSide(
                  color: widget.managementMode
                      ? AppTheme.outline
                      : AppTheme.rose,
                ),
                textStyle: AppTypography.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _GoalSection(
              title: 'Daily Progress Goal',
              description:
                  'A daily target that builds toward your weekly goal.',
              emptyText: 'No active Daily Progress Goal',
              goals: plan.daily == null
                  ? const <GoalProgress>[]
                  : <GoalProgress>[plan.daily!],
              managementMode: widget.managementMode,
              onArchiveSuccess: _exitManagementMode,
            ),
            const SizedBox(height: 24),
            _GoalSection(
              title: 'Weekly Goals',
              description: 'Goals to complete during the current week.',
              emptyText: 'No active Weekly Goals',
              goals: plan.weekly,
              managementMode: widget.managementMode,
              onArchiveSuccess: _exitManagementMode,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${4 - plan.weekly.length} of 4 Weekly Goal slots available',
                style: AppTypography.secondary,
              ),
            ),
            const SizedBox(height: 24),
            _GoalSection(
              title: 'Monthly Progress Goal',
              description:
                  'A weekly target that moves you toward your monthly goal.',
              emptyText: 'No active Monthly Progress Goal',
              goals: plan.monthly == null
                  ? const <GoalProgress>[]
                  : <GoalProgress>[plan.monthly!],
              managementMode: widget.managementMode,
              onArchiveSuccess: _exitManagementMode,
            ),
          ],
        ),
        if (widget.managementMode)
          const IgnorePointer(
            child: SizedBox(
              key: Key('weekly-plan-management-mode'),
              width: 1,
              height: 1,
            ),
          ),
      ],
    );
  }

  Future<void> _createGoal(BuildContext context, GoalCapacity? capacity) async {
    final full =
        capacity != null &&
        capacity.usedDaily == 1 &&
        capacity.usedWeekly == 4 &&
        capacity.usedMonthly == 1;
    if (!full) {
      await context.push(RoutePaths.goalCreate);
      return;
    }
    final manage = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Goal limit reached'),
        content: const Text(
          'All 6 goal slots are currently in use. Archive at least one '
          'goal before creating another.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('weekly-plan-goal-limit-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('weekly-plan-goal-limit-manage'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Manage Goals'),
          ),
        ],
      ),
    );
    if (manage == true && mounted) {
      widget.onManagementModeChanged(true);
    }
  }

  void _exitManagementMode() {
    widget.onManagementModeChanged(false);
  }

  PlannerDate _today(WidgetRef ref) {
    return ref.watch(weeklyPlanningTodayProvider).asData?.value ??
        PlannerDate.fromDateTime(DateTime.now());
  }

  void _openWeek(BuildContext context, PlannerDate start) {
    _exitManagementMode();
    context.go(RoutePaths.weeklyPlanningFor(_mondayOf(start)));
  }
}

final class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.title,
    required this.description,
    required this.emptyText,
    required this.goals,
    required this.managementMode,
    required this.onArchiveSuccess,
  });

  final String title;
  final String description;
  final String emptyText;
  final List<GoalProgress> goals;
  final bool managementMode;
  final VoidCallback onArchiveSuccess;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: AppTypography.sectionTitle),
        const SizedBox(height: 3),
        Text(description, style: AppTypography.secondary),
        const SizedBox(height: 8),
        const Divider(height: 1),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(emptyText, style: AppTypography.secondary),
          )
        else
          for (final progress in goals)
            _GoalRow(
              progress: progress,
              managementMode: managementMode,
              onArchiveSuccess: onArchiveSuccess,
            ),
      ],
    );
  }
}

final class _GoalRow extends ConsumerWidget {
  const _GoalRow({
    required this.progress,
    required this.managementMode,
    required this.onArchiveSuccess,
  });

  final GoalProgress progress;
  final bool managementMode;
  final VoidCallback onArchiveSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = progress.goal;
    final ratio = progress.primaryTarget.isSet
        ? '${progress.primaryActual.display}/${progress.primaryTarget.display}'
        : 'Set Goal';
    final secondary = switch (goal.role) {
      GoalRole.dailyWeekly =>
        'Today Goal: ${progress.dailyActual.display}/${progress.dailyTarget.value?.display ?? '0'}',
      GoalRole.weeklyMonthly =>
        'Month Goal: ${progress.monthlyActual.display}/${progress.monthlyTarget.value?.display ?? '0'}',
      GoalRole.weekly => null,
    };
    final row = InkWell(
      key: Key('weekly-plan-goal-${goal.id}'),
      onTap: () => context.push(RoutePaths.goalEdit(goal.id)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.outline)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            GoalIcon(
              iconId: goal.iconId,
              size: 32,
              semanticLabel: '${goal.title} goal icon',
              fallbackIcon: goalIconFallbackForRole(goal.role),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    goal.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle,
                  ),
                  Text(ratio, style: AppTypography.metricCompact),
                  if (secondary != null)
                    Text(secondary, style: AppTypography.secondary),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (managementMode)
                  IconButton(
                    key: Key('weekly-plan-goal-direct-archive-${goal.id}'),
                    tooltip: 'Archive goal',
                    onPressed: () {
                      unawaited(
                        _confirmArchive(context, ref, goal).then((archived) {
                          if (archived) {
                            onArchiveSuccess();
                          }
                        }),
                      );
                    },
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.archive_outlined, size: 24),
                  ),
                PopupMenuButton<String>(
                  key: Key('weekly-plan-goal-menu-${goal.id}'),
                  tooltip: 'Goal actions',
                  onSelected: (value) {
                    if (value == 'edit') {
                      unawaited(context.push(RoutePaths.goalEdit(goal.id)));
                    } else {
                      unawaited(
                        _confirmArchive(context, ref, goal).then((archived) {
                          if (archived && managementMode) {
                            onArchiveSuccess();
                          }
                        }),
                      );
                    }
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem(value: 'edit', child: Text('Edit Goal')),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive Goal'),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 24),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    final indicatorKey = goal.indicatorKey;
    return indicatorKey == null
        ? row
        : KeyedSubtree(
            key: Key('weekly-plan-indicator-$indicatorKey'),
            child: row,
          );
  }

  Future<bool> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    Goal goal,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive "${goal.title}"?'),
        content: const Text(
          'It will be removed from your active goals. Past targets, results, '
          'and history will be preserved.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('weekly-plan-archive-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return false;
    }
    await ref
        .read(goalRepositoryProvider)
        .archiveGoal(
          profileId: ref.read(goalProfileIdProvider),
          goalId: goal.id,
        );
    ref.invalidate(activeGoalsProvider);
    ref.invalidate(goalCapacityProvider);
    ref.invalidate(goalPlanningProvider);
    return true;
  }
}

final class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({
    required this.start,
    required this.end,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final PlannerDate start;
  final PlannerDate end;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final startLabel = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(start.asLocalDate);
    final endLabel = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(end.asLocalDate);
    final label = start.year == end.year
        ? '$startLabel \u2013 $endLabel, ${end.year}'
        : '$startLabel, ${start.year} \u2013 $endLabel, ${end.year}';
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.calendar_month_outlined,
            color: AppTheme.rose,
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: AppTypography.body)),
          IconButton(
            tooltip: 'Previous week',
            onPressed: onPrevious,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
          IconButton(
            tooltip: 'Next week',
            onPressed: canGoForward ? onNext : null,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.chevron_right,
              size: 28,
              color: onNext == null ? Colors.white24 : null,
            ),
          ),
        ],
      ),
    );
  }
}

final class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Weekly Planning could not be opened.'),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

PlannerDate _mondayOf(PlannerDate date) {
  return date.addDays(-(date.asLocalDate.weekday - DateTime.monday));
}
