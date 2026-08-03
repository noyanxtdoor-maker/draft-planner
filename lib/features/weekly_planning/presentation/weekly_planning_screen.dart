import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

final class WeeklyPlanningScreen extends ConsumerWidget {
  const WeeklyPlanningScreen({this.periodStart, super.key});

  final PlannerDate? periodStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedStart = periodStart == null
        ? ref.watch(weeklyPlanningTodayProvider).asData?.value
        : _mondayOf(periodStart!);
    if (resolvedStart == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Weekly Planning')),
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    final plan = ref.watch(goalPlanningProvider(resolvedStart));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Planning'),
        actions: <Widget>[
          IconButton(
            key: const Key('goal-archive-button'),
            tooltip: 'Goal Archive',
            onPressed: () => context.push(RoutePaths.goalArchive),
            icon: const Icon(Icons.archive_outlined),
          ),
          // Kept as a separate, read-only prior-plan entry point for the
          // already-approved Planner history behavior.
          IconButton(
            key: const Key('weekly-plan-history-button'),
            tooltip: 'Prior weeks',
            onPressed: () => context.go(RoutePaths.weeklyPlanningHistory),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _Failure(
            message: error.toString(),
            onRetry: () => ref.invalidate(goalPlanningProvider(resolvedStart)),
          ),
          data: (value) => _GoalPlanBody(plan: value),
        ),
      ),
    );
  }
}

final class _GoalPlanBody extends ConsumerWidget {
  const _GoalPlanBody({required this.plan});

  final GoalPlanningSnapshot plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(goalCapacityProvider).asData?.value;
    return ListView(
      key: const Key('weekly-plan-list'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: <Widget>[
        _WeekNavigation(
          start: plan.periodStart,
          end: plan.periodEnd,
          canGoForward: plan.periodStart.compareTo(_mondayOf(_today(ref))) < 0,
          onPrevious: () => _openWeek(context, plan.periodStart.addDays(-7)),
          onNext: plan.periodStart.compareTo(_mondayOf(_today(ref))) < 0
              ? () => _openWeek(context, plan.periodStart.addDays(7))
              : null,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('weekly-plan-create-goal'),
          onPressed: () => _createGoal(context, capacity),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Create Goal'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppTheme.rose,
            side: const BorderSide(color: AppTheme.rose),
            textStyle: AppTypography.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _GoalSection(
          title: 'Daily Progress Goal',
          description: 'A daily target that builds toward your weekly goal.',
          emptyText: 'No active Daily Progress Goal',
          goals: plan.daily == null
              ? const <GoalProgress>[]
              : <GoalProgress>[plan.daily!],
        ),
        const SizedBox(height: 24),
        _GoalSection(
          title: 'Weekly Goals',
          description: 'Goals to complete during the current week.',
          emptyText: 'No active Weekly Goals',
          goals: plan.weekly,
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
        ),
      ],
    );
  }

  void _createGoal(BuildContext context, GoalCapacity? capacity) {
    final full =
        capacity != null &&
        capacity.usedDaily == 1 &&
        capacity.usedWeekly == 4 &&
        capacity.usedMonthly == 1;
    if (!full) {
      unawaited(context.push(RoutePaths.goalCreate));
      return;
    }
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Goal limit reached'),
          content: const Text(
            'All 6 goal slots are currently in use. Archive at least one '
            'goal before creating another.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Manage Goals'),
            ),
          ],
        ),
      ),
    );
  }

  PlannerDate _today(WidgetRef ref) {
    return ref.watch(weeklyPlanningTodayProvider).asData?.value ??
        PlannerDate.fromDateTime(DateTime.now());
  }

  void _openWeek(BuildContext context, PlannerDate start) {
    unawaited(context.push(RoutePaths.weeklyPlanningFor(_mondayOf(start))));
  }
}

final class _GoalSection extends StatelessWidget {
  const _GoalSection({
    required this.title,
    required this.description,
    required this.emptyText,
    required this.goals,
  });

  final String title;
  final String description;
  final String emptyText;
  final List<GoalProgress> goals;

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
          for (final progress in goals) _GoalRow(progress: progress),
      ],
    );
  }
}

final class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.progress});

  final GoalProgress progress;

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
            Icon(_iconForGoal(goal), color: AppTheme.rose, size: 32),
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
            PopupMenuButton<String>(
              key: Key('weekly-plan-goal-menu-${goal.id}'),
              tooltip: 'Goal actions',
              onSelected: (value) {
                if (value == 'edit') {
                  unawaited(context.push(RoutePaths.goalEdit(goal.id)));
                } else {
                  unawaited(_confirmArchive(context, ref, goal));
                }
              },
              itemBuilder: (context) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'edit', child: Text('Edit Goal')),
                PopupMenuItem(value: 'archive', child: Text('Archive Goal')),
              ],
              icon: const Icon(Icons.more_vert, size: 24),
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

  Future<void> _confirmArchive(
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
      return;
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

IconData _iconForGoal(Goal goal) => switch (goal.indicatorKey) {
  'job_applications' => Icons.work_outline,
  'scripture_study' => Icons.menu_book_outlined,
  'exercise' => Icons.fitness_center,
  'meaningful_connections' => Icons.people_outline,
  'budget_review' => Icons.pie_chart_outline,
  'temple_visit' => Icons.account_balance_outlined,
  _ => switch (goal.role) {
    GoalRole.dailyWeekly => Icons.today_outlined,
    GoalRole.weekly => Icons.flag_outlined,
    GoalRole.weeklyMonthly => Icons.calendar_month_outlined,
  },
};
