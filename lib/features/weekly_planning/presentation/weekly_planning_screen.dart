import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

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
    final plan = ref.watch(weeklyPlanProvider(resolvedStart));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Planning'),
        actions: <Widget>[
          IconButton(
            key: const Key('weekly-plan-history-button'),
            tooltip: 'Prior weeks',
            onPressed: () => context.push(RoutePaths.weeklyPlanningHistory),
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: SafeArea(
        child: plan.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _Failure(
            message: error.toString(),
            onRetry: () => ref.invalidate(weeklyPlanProvider(resolvedStart)),
          ),
          data: (value) => _PlanBody(plan: value),
        ),
      ),
    );
  }
}

final class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.plan});

  final WeeklyPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(weeklyPlanningTodayProvider).asData?.value;
    final state = plan.effectiveState(today ?? plan.period.start);
    final editable =
        state == WeeklyPlanState.draft || state == WeeklyPlanState.active;
    final currentWeek = today == null ? plan.period.start : _mondayOf(today);
    final canGoForward = plan.period.start.compareTo(currentWeek) < 0;
    return ListView(
      key: const Key('weekly-plan-list'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: <Widget>[
        _WeekNavigation(
          period: plan.period,
          canGoForward: canGoForward,
          onPrevious: () => _openWeek(context, plan.period.start.addDays(-7)),
          onNext: canGoForward
              ? () => _openWeek(context, plan.period.start.addDays(7))
              : null,
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        for (final indicator in plan.indicators)
          _WeeklyGoalRow(
            key: Key('weekly-plan-indicator-${indicator.indicatorKey}'),
            indicator: indicator,
            onTap: editable
                ? () => context.push(
                    RoutePaths.weeklyPlanningTargets(
                      plan.period.start,
                      indicatorKey: indicator.indicatorKey,
                    ),
                  )
                : null,
          ),
      ],
    );
  }

  void _openWeek(BuildContext context, PlannerDate start) {
    unawaited(context.push(RoutePaths.weeklyPlanningFor(_mondayOf(start))));
  }
}

final class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({
    required this.period,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final WeeklyPeriod period;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(period.start.asLocalDate);
    final end = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(period.end.asLocalDate);
    final label = period.start.year == period.end.year
        ? '$start – $end, ${period.end.year}'
        : '$start, ${period.start.year} – $end, ${period.end.year}';
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.calendar_month_outlined,
            color: AppTheme.rose,
            size: 24,
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
            onPressed: onNext,
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

final class _WeeklyGoalRow extends StatelessWidget {
  const _WeeklyGoalRow({
    required this.indicator,
    required this.onTap,
    super.key,
  });

  final WeeklyIndicatorReview indicator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = indicator.target.isSet
        ? '${indicator.actual.display}/${indicator.target.display}'
        : 'Set Goal';
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 80, maxHeight: 82),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.outline)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                indicator.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              value,
              style: indicator.target.isSet
                  ? AppTypography.metricCompact
                  : AppTypography.button.copyWith(color: AppTheme.rose),
            ),
          ],
        ),
      ),
    );
  }
}

PlannerDate _mondayOf(PlannerDate date) {
  return date.addDays(-(date.asLocalDate.weekday - DateTime.monday));
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
