import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

final class WeeklyPlanningScreen extends ConsumerWidget {
  const WeeklyPlanningScreen({this.periodStart, super.key});

  final PlannerDate? periodStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedStart =
        periodStart ?? ref.watch(weeklyPlanningTodayProvider).asData?.value;
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
    return ListView(
      key: const Key('weekly-plan-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        Text(
          '${plan.period.start.iso8601} — ${plan.period.end.iso8601}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '${_stateLabel(state)} · ${plan.timeZoneId}',
          key: const Key('weekly-plan-identity'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        const Text(
          'Actual is factual and read-only. Target is your choice. Scheduled '
          'Potential comes only from qualified planned activities.',
        ),
        const SizedBox(height: 16),
        Text('Life Indicators', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final indicator in plan.indicators)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                key: Key('weekly-plan-indicator-${indicator.indicatorKey}'),
                title: Text(indicator.label),
                subtitle: Text(
                  'Actual ${indicator.actual.display} · '
                  'Target ${indicator.target.display} · '
                  'Scheduled ${indicator.scheduled.display}',
                ),
              ),
            ),
          ),
        if (editable)
          OutlinedButton.icon(
            key: const Key('weekly-plan-targets-button'),
            onPressed: () => context.push(
              RoutePaths.weeklyPlanningTargets(plan.period.start),
            ),
            icon: const Icon(Icons.tune),
            label: const Text('Set weekly targets'),
          ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Commitments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                  title: Text(commitment.label),
                  subtitle: Text(
                    _commitmentStatus(commitment),
                    key: Key('commitment-status-${commitment.id}'),
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
                    '${RoutePaths.taskCreate}'
                    '?date=${plan.period.start.iso8601}',
                  ),
                  icon: const Icon(Icons.add_task),
                  label: const Text('New Task'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('weekly-plan-create-event'),
                  onPressed: () => context.push(
                    '${RoutePaths.calendarEventCreate}'
                    '?date=${plan.period.start.iso8601}',
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

  String _stateLabel(WeeklyPlanState state) {
    return switch (state) {
      WeeklyPlanState.draft => 'Draft',
      WeeklyPlanState.active => 'Active',
      WeeklyPlanState.reviewDue => 'Review Due',
      WeeklyPlanState.reviewed => 'Reviewed',
      WeeklyPlanState.historical => 'Historical',
    };
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
