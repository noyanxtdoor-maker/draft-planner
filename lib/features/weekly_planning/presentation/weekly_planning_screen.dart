import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';
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
          data: (value) => _PlanBody(plan: value, requestedDate: resolvedStart),
        ),
      ),
    );
  }
}

final class _PlanBody extends ConsumerWidget {
  const _PlanBody({required this.plan, required this.requestedDate});

  final WeeklyPlan plan;
  final PlannerDate requestedDate;

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
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('Commitments', style: AppTypography.sectionTitle),
            ),
            if (editable)
              PopupMenuButton<WeeklyCommitmentType>(
                key: const Key('weekly-plan-add-commitment'),
                tooltip: 'Add commitment',
                onSelected: (type) => _selectCommitment(context, ref, type),
                itemBuilder: (context) =>
                    const <PopupMenuEntry<WeeklyCommitmentType>>[
                      PopupMenuItem(
                        value: WeeklyCommitmentType.task,
                        child: Text('Select existing Task'),
                      ),
                      PopupMenuItem(
                        value: WeeklyCommitmentType.event,
                        child: Text('Select weekly Event'),
                      ),
                    ],
                icon: const Icon(Icons.add_circle_outline),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (plan.commitments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No commitments yet. Add existing items or create a Task or '
                'Calendar Event.',
              ),
            ),
          )
        else
          for (final commitment in plan.commitments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    commitment.type == WeeklyCommitmentType.task
                        ? Icons.check_box_outlined
                        : Icons.event_outlined,
                  ),
                  title: Text(commitment.label, style: AppTypography.cardTitle),
                  subtitle: Text(
                    _commitmentStatus(commitment),
                    key: Key('commitment-status-${commitment.id}'),
                    style: AppTypography.secondary,
                  ),
                ),
              ),
            ),
        if (editable) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('weekly-plan-create-task'),
                  onPressed: () => context.push(
                    '${RoutePaths.taskCreate}?date=${plan.period.start.iso8601}',
                  ),
                  icon: const Icon(Icons.add_task),
                  label: const Text('New Task'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('weekly-plan-create-event'),
                  onPressed: () => unawaited(
                    launchCalendarEventCreation<void>(
                      context,
                      ref,
                      CalendarEventCreationContext(
                        source: 'weekly-planning',
                        destinationPath: RoutePaths.calendarEventCreate,
                        date: plan.period.start,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.event_available),
                  label: const Text('New Event'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (state == WeeklyPlanState.reviewDue)
          FilledButton.icon(
            key: const Key('weekly-plan-review-button'),
            onPressed: () =>
                context.push(RoutePaths.weeklyPlanningReview(plan.id)),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Complete Weekly Review'),
          ),
        if (plan.review != null) ...<Widget>[
          Card(
            child: ListTile(
              key: const Key('weekly-plan-reviewed-summary'),
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Review complete'),
              subtitle: Text(
                plan.postReviewChanges.isEmpty
                    ? 'No post-review factual changes.'
                    : '${plan.postReviewChanges.length} post-review factual '
                          'change(s) recorded.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('weekly-plan-start-next-button'),
            onPressed: () => _startNextWeek(context, ref),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Start next week'),
          ),
        ],
      ],
    );
  }

  void _openWeek(BuildContext context, PlannerDate start) {
    unawaited(context.push(RoutePaths.weeklyPlanningFor(_mondayOf(start))));
  }

  Future<void> _selectCommitment(
    BuildContext context,
    WidgetRef ref,
    WeeklyCommitmentType type,
  ) async {
    final repository = ref.read(weeklyPlanningRepositoryProvider);
    final profileId = ref.read(weeklyPlanningProfileIdProvider);
    final candidates = type == WeeklyCommitmentType.task
        ? await repository.readTaskCandidates(
            profileId: profileId,
            planId: plan.id,
          )
        : await repository.readEventCandidates(
            profileId: profileId,
            planId: plan.id,
          );
    if (!context.mounted) {
      return;
    }
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            type == WeeklyCommitmentType.task
                ? 'No unselected incomplete Tasks are available.'
                : 'No unselected Events occur in this week.',
          ),
        ),
      );
      return;
    }
    final selected = await showDialog<WeeklyPlanCommitment>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          type == WeeklyCommitmentType.task ? 'Select Task' : 'Select Event',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final candidate in candidates)
                ListTile(
                  title: Text(candidate.label),
                  onTap: () => Navigator.of(dialogContext).pop(candidate),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (selected == null || !context.mounted) {
      return;
    }
    try {
      await repository.addCommitment(
        profileId: profileId,
        planId: plan.id,
        type: selected.type,
        sourceId: selected.sourceId,
        occurrenceId: selected.occurrenceId,
      );
      ref.invalidate(weeklyPlanProvider(requestedDate));
    } on WeeklyPlanningValidationException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _startNextWeek(BuildContext context, WidgetRef ref) async {
    final incomplete = plan.commitments
        .where((item) => item.isIncompleteTask)
        .toList(growable: false);
    final carried = <String, bool>{
      for (final task in incomplete) task.sourceId: false,
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Start next week'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Tasks carry only when you choose them. Events never carry '
                  'automatically.',
                ),
                for (final task in incomplete)
                  CheckboxListTile(
                    value: carried[task.sourceId],
                    title: Text(task.label),
                    onChanged: (value) =>
                        setState(() => carried[task.sourceId] = value ?? false),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final decisions = <String, TaskCarryoverDecision>{
      for (final task in incomplete)
        task.sourceId: carried[task.sourceId]!
            ? TaskCarryoverDecision.carry
            : TaskCarryoverDecision.doNotCarry,
    };
    final next = await ref
        .read(weeklyPlanningRepositoryProvider)
        .startNextWeek(
          profileId: ref.read(weeklyPlanningProfileIdProvider),
          fromPlanId: plan.id,
          nextPlanId: ref.read(weeklyPlanningIdentifierProvider).nextUuid(),
          taskDecisions: decisions,
        );
    ref.invalidate(weeklyPlanHistoryProvider);
    if (context.mounted) {
      context.go(RoutePaths.weeklyPlanningFor(next.period.start));
    }
  }

  String _commitmentStatus(WeeklyPlanCommitment item) {
    if (item.hasUnresolvedReport) {
      return 'Outcome report outstanding';
    }
    if (item.requiresReport) {
      return 'Outcome report recorded';
    }
    if (item.type == WeeklyCommitmentType.task) {
      return item.taskStatus == PlannerTaskStatus.incomplete
          ? 'Incomplete Task'
          : 'Task ${item.taskStatus!.name}';
    }
    return 'Calendar Event';
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
    final start = MaterialLocalizations.of(context).formatShortMonthDay(
      period.start.asLocalDate,
    );
    final end = MaterialLocalizations.of(context).formatShortMonthDay(
      period.end.asLocalDate,
    );
    final label = period.start.year == period.end.year
        ? '$start – $end, ${period.end.year}'
        : '$start, ${period.start.year} – $end, ${period.end.year}';
    return SizedBox(
      height: 64,
      child: Row(
        children: <Widget>[
          const Icon(Icons.calendar_month_outlined, color: AppTheme.rose, size: 24),
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
  const _WeeklyGoalRow({required this.indicator, required this.onTap, super.key});

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
        constraints: const BoxConstraints(minHeight: 80),
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
