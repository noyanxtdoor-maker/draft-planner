import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';
import 'package:rmplanner/features/planner/presentation/contextual_create_fab.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeIndicatorControllerProvider);
    final snapshot = state.snapshot;
    // Phase 9 — Slice D removed the Home top-bar calendar and shield
    // actions. The hamburger navigation and Home title remain. The
    // Planner "Go to today" surface owns the consolidated calendar
    // icon from this slice, and Privacy remains reachable through the
    // global navigation drawer so the underlying domain/security
    // logic is unchanged. The actions list is intentionally empty
    // and contains no placeholders so the AppBar does not reserve
    // space for removed controls.
    return Scaffold(
      appBar: AppBar(
        key: const Key('home-app-bar'),
        title: const Text('Home', key: Key('home-title')),
        leading: Builder(
          builder: (innerContext) => IconButton(
            key: const Key('home-hamburger'),
            tooltip: 'Open global navigation',
            onPressed: () => GlobalDrawerScope.of(innerContext).open(),
            icon: const Icon(Icons.menu),
          ),
        ),
        actions: const <Widget>[],
      ),
      body: SafeArea(
        child: snapshot == null
            ? _InitialState(state: state)
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(homeIndicatorControllerProvider.notifier)
                    .refresh(),
                child: ListView(
                  key: const Key('home-indicator-list'),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: <Widget>[
                    _PeriodHeader(snapshot: snapshot, status: state.status),
                    const SizedBox(height: 16),
                    _AttentionRow(snapshot: snapshot),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns = constraints.maxWidth >= 360;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < snapshot.indicators.length;
                              index += 1
                            )
                              SizedBox(
                                width:
                                    twoColumns &&
                                        index != 0 &&
                                        index != snapshot.indicators.length - 1
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth,
                                child: _IndicatorCard(
                                  indicator: snapshot.indicators[index],
                                  period: snapshot.period,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: OutlinedButton.icon(
                        key: const Key('weekly-targets-button'),
                        onPressed: () => context.push(
                          RoutePaths.weeklyPlanningFor(snapshot.period.start),
                        ),
                        icon: const Icon(Icons.calendar_view_week_outlined),
                        label: const Text('Weekly Planning'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Targets begin as Not set. Suggested values are optional '
                      'and never applied without your choice.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: ContextualCreateFab(
        destination: CreateActionDestination.home,
        onSelected: (action) => _handleCreate(context, ref, action),
      ),
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
        return;
      case ContextualCreateAction.task:
        unawaited(
          context.push('${RoutePaths.taskCreate}?date=${today.iso8601}'),
        );
        return;
    }
  }
}

final class _InitialState extends StatelessWidget {
  const _InitialState({required this.state});

  final HomeIndicatorState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == HomeIndicatorLoadStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(state.message ?? 'Home data is unavailable.'),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}

final class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.snapshot, required this.status});

  final HomeIndicatorSnapshot snapshot;
  final HomeIndicatorLoadStatus status;

  @override
  Widget build(BuildContext context) {
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Weekly Life Indicators',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${snapshot.period.start.iso8601} — ${snapshot.period.end.iso8601}',
          key: const Key('home-active-period'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final statusWidget = switch (status) {
      HomeIndicatorLoadStatus.ready => const Chip(
        key: Key('home-offline-ready-state'),
        avatar: Icon(Icons.offline_bolt_outlined, size: 16),
        label: Text('Ready offline'),
      ),
      HomeIndicatorLoadStatus.rebuilding => const Chip(
        key: Key('home-rebuilding-state'),
        avatar: SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: Text('Updating'),
      ),
      HomeIndicatorLoadStatus.loading ||
      HomeIndicatorLoadStatus.failure => const SizedBox.shrink(),
    };
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.5) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[header, const SizedBox(height: 8), statusWidget],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(child: header),
        statusWidget,
      ],
    );
  }
}

final class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.snapshot});

  final HomeIndicatorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _AttentionCard(
            key: const Key('home-overdue-count'),
            icon: Icons.warning_amber_rounded,
            label: 'Overdue Tasks',
            count: snapshot.overdueTaskCount,
            onTap: () => context.go(RoutePaths.planner),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AttentionCard(
            key: const Key('home-awaiting-report-count'),
            icon: Icons.fact_check_outlined,
            label: 'Unreported',
            count: snapshot.awaitingReportCount,
            onTap: () => context.go(RoutePaths.planner),
          ),
        ),
      ],
    );
  }
}

final class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.indicator, required this.period});

  final LifeIndicatorSummary indicator;
  final IndicatorPeriod period;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: Key('home-indicator-${indicator.key}'),
      child: InkWell(
        onTap: () => context.push(
          RoutePaths.indicatorDetail(indicator.key, period.start),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    _iconFor(indicator.key),
                    color: colors.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      indicator.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Value(
                      label: 'Actual',
                      value: indicator.actual.display,
                      emphasized: true,
                    ),
                  ),
                  Expanded(
                    child: _Value(
                      label: 'Target',
                      value: indicator.target.display,
                    ),
                  ),
                  Expanded(
                    child: _Value(
                      label: 'Scheduled',
                      value: indicator.scheduledPotential.display,
                      muted: true,
                    ),
                  ),
                ],
              ),
              if (indicator.projectionState !=
                  IndicatorProjectionState.current) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  switch (indicator.projectionState) {
                    IndicatorProjectionState.stale =>
                      'Projection needs verification',
                    IndicatorProjectionState.rebuilding =>
                      'Projection is rebuilding',
                    IndicatorProjectionState.failed =>
                      indicator.failureMessage ?? 'Projection unavailable',
                    IndicatorProjectionState.current => '',
                  },
                  key: Key('indicator-state-${indicator.key}'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _Value extends StatelessWidget {
  const _Value({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool emphasized;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: emphasized
                ? colors.primary
                : muted
                ? colors.onSurfaceVariant
                : colors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(String key) => switch (key) {
  'job_applications' => Icons.work_outline,
  'scripture_study' => Icons.menu_book_outlined,
  'exercise' => Icons.fitness_center,
  'meaningful_connections' => Icons.people_outline,
  'budget_review' => Icons.pie_chart_outline,
  'temple_visit' => Icons.church_outlined,
  _ => Icons.insights_outlined,
};
