import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';
import 'package:rmplanner/features/planner/presentation/contextual_create_fab.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeIndicatorControllerProvider);
    final snapshot = state.snapshot;
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
        child: snapshot == null
            ? _InitialState(state: state)
            : RefreshIndicator(
                onRefresh: () => ref
                    .read(homeIndicatorControllerProvider.notifier)
                    .refresh(),
                child: ListView(
                  key: const Key('home-indicator-list'),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                  children: <Widget>[
                    _SectionHeader(
                      title: 'Weekly Life Indicators',
                      onViewAll: () => context.push(RoutePaths.progress),
                      viewAllKey: const Key('home-wli-view-all'),
                    ),
                    const SizedBox(height: 14),
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
                                  nextTempleVisit: snapshot.nextTempleVisit,
                                  wide:
                                      index == 0 ||
                                      index == snapshot.indicators.length - 1,
                                  onScheduleTemple:
                                      snapshot.indicators[index].key ==
                                              'temple_visit' &&
                                          snapshot.nextTempleVisit == null
                                      ? () => unawaited(
                                          launchCalendarEventCreation<void>(
                                            context,
                                            ref,
                                            CalendarEventCreationContext(
                                              source: 'home-temple-visit',
                                              destinationPath: RoutePaths
                                                  .calendarEventCreate,
                                              date: snapshot.period.start,
                                              recommendedEventTypeId:
                                                  SystemEventTypeIds
                                                      .templeVisit,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
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
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: 'Active Pathways',
                      onViewAll: () => _showPathwayMessage(context),
                      viewAllKey: const Key('home-pathways-view-all'),
                    ),
                    const SizedBox(height: 4),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: const Column(
                        children: <Widget>[
                          _PathwayRow(
                            key: Key('home-pathway-employment'),
                            icon: Icons.work_outline,
                            label: 'Employment',
                          ),
                          Divider(height: 1),
                          _PathwayRow(
                            key: Key('home-pathway-education'),
                            icon: Icons.school_outlined,
                            label: 'Education',
                          ),
                          Divider(height: 1),
                          _PathwayRow(
                            key: Key('home-pathway-documents'),
                            icon: Icons.description_outlined,
                            label: 'Documents',
                          ),
                        ],
                      ),
                    ),
                    if (state.status == HomeIndicatorLoadStatus.rebuilding)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              key: viewAllKey,
              onPressed: onViewAll,
              child: const Text('View All'),
            ),
          ],
        ),
        const Divider(height: 1),
      ],
    );
  }
}

final class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.indicator,
    required this.period,
    required this.nextTempleVisit,
    required this.wide,
    this.onScheduleTemple,
  });

  final LifeIndicatorSummary indicator;
  final IndicatorPeriod period;
  final PlannerDate? nextTempleVisit;
  final bool wide;
  final VoidCallback? onScheduleTemple;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final card = Card(
      key: Key('home-indicator-${indicator.key}'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        onTap: () => context.push(
          RoutePaths.indicatorDetail(indicator.key, period.start),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: wide
              ? _buildWide(context, colors)
              : _buildCompact(context, colors),
        ),
      ),
    );
    return card;
  }

  Widget _buildCompact(BuildContext context, ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(_iconFor(indicator.key), color: AppTheme.rose, size: 34),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                indicator.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _Metric(indicator: indicator, color: colors.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context, ColorScheme colors) {
    final isTemple = indicator.key == 'temple_visit';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(_iconFor(indicator.key), color: AppTheme.rose, size: 42),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                indicator.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              _Metric(indicator: indicator, color: colors.primary),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _WideAside(
          label: isTemple ? 'Next Visit' : "Today's Goal",
          value: isTemple
              ? _templeAsideValue(context)
              : indicator.target.display,
          isTemple: isTemple,
          onTap: onScheduleTemple,
        ),
      ],
    );
  }

  String _templeAsideValue(BuildContext context) {
    final next = nextTempleVisit;
    if (next == null) {
      return 'Set Schedule';
    }
    return MaterialLocalizations.of(context).formatShortDate(next.asLocalDate);
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.indicator, required this.color});

  final LifeIndicatorSummary indicator;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Actual / Target',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${indicator.actual.display} / ${indicator.target.display}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

final class _WideAside extends StatelessWidget {
  const _WideAside({
    required this.label,
    required this.value,
    required this.isTemple,
    this.onTap,
  });

  final String label;
  final String value;
  final bool isTemple;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          if (isTemple && onTap != null)
            TextButton(
              key: const Key('home-temple-set-schedule'),
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
            )
          else
            Text(
              value,
              key: isTemple ? const Key('home-temple-next-visit') : null,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.rose,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

final class _PathwayRow extends StatelessWidget {
  const _PathwayRow({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minVerticalPadding: 12,
      leading: SizedBox.square(
        dimension: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.rose),
          ),
          child: Icon(icon, color: AppTheme.rose),
        ),
      ),
      title: Text(label),
      subtitle: const Text('Not configured'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pathways are not configured yet.')),
      ),
    );
  }
}

IconData _iconFor(String key) => switch (key) {
  'job_applications' => Icons.work_outline,
  'scripture_study' => Icons.menu_book_outlined,
  'exercise' => Icons.fitness_center,
  'meaningful_connections' => Icons.people_outline,
  'budget_review' => Icons.pie_chart_outline,
  'temple_visit' => Icons.account_balance_outlined,
  _ => Icons.insights_outlined,
};
