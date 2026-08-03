import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
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
          child: snapshot == null
              ? _InitialState(state: state)
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(homeIndicatorControllerProvider.notifier)
                      .refresh(),
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
                        onViewAll: () =>
                            _openWeeklyPlanning(context, snapshot.period.start),
                        viewAllKey: const Key('home-wli-view-all'),
                      ),
                      const SizedBox(height: 6),
                      if (!snapshot.currentWeekPlanned)
                        _StartPlanningButton(
                          onPressed: () => _openWeeklyPlanning(
                            context,
                            snapshot.period.start,
                          ),
                        )
                      else ...<Widget>[
                        _IndicatorGrid(
                          snapshot: snapshot,
                          onOpenGoal: (indicator) => _openGoal(
                            context,
                            snapshot.period.start,
                            indicator,
                          ),
                          onOpenTempleSchedule: () => _openTempleSchedule(
                            context,
                            ref,
                            snapshot.period.start,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: OutlinedButton(
                            key: const Key('weekly-targets-button'),
                            onPressed: () => _openWeeklyPlanning(
                              context,
                              snapshot.period.start,
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(182, 42),
                              fixedSize: const Size(182, 42),
                              textStyle: AppTypography.button,
                              side: const BorderSide(color: AppTheme.outline),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Weekly Planning'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _SectionHeader(
                        title: 'Active Pathways',
                        onViewAll: () => _showPathwayMessage(context),
                        viewAllKey: const Key('home-pathways-view-all'),
                      ),
                      const SizedBox(height: 10),
                      const _PathwaysCard(),
                      if (state.status == HomeIndicatorLoadStatus.rebuilding)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(),
                        ),
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

  static void _openGoal(
    BuildContext context,
    PlannerDate start,
    LifeIndicatorSummary indicator,
  ) {
    final goalId = indicator.goalId;
    if (goalId == null) {
      _openWeeklyPlanning(context, start);
      return;
    }
    unawaited(context.push(RoutePaths.goalEdit(goalId)));
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
      width: 182,
      child: Center(
        child: FilledButton(
          key: const Key('weekly-targets-button'),
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.rose,
            foregroundColor: const Color(0xFF400018),
            fixedSize: const Size(182, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: AppTypography.button,
          ),
          child: const Text('Start Weekly Planning'),
        ),
      ),
    );
  }
}

final class _IndicatorGrid extends StatelessWidget {
  const _IndicatorGrid({
    required this.snapshot,
    required this.onOpenGoal,
    required this.onOpenTempleSchedule,
  });

  final HomeIndicatorSnapshot snapshot;
  final ValueChanged<LifeIndicatorSummary> onOpenGoal;
  final VoidCallback onOpenTempleSchedule;

  @override
  Widget build(BuildContext context) {
    final indicators = snapshot.indicators;
    if (indicators.length < 2) {
      return const SizedBox.shrink();
    }
    final first = indicators.first;
    final temple = indicators.last;
    final middle = indicators.sublist(1, indicators.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 60,
          child: _IndicatorCard(
            indicator: first,
            wide: true,
            asideLabel: "Today's Goal",
            asideValue: _todayGoalRatio(snapshot),
            onTap: () => onOpenGoal(first),
          ),
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < middle.length; row += 2) ...<Widget>[
          SizedBox(
            height: 60,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _IndicatorCard(
                    indicator: middle[row],
                    wide: false,
                    onTap: () => onOpenGoal(middle[row]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: row + 1 < middle.length
                      ? _IndicatorCard(
                          indicator: middle[row + 1],
                          wide: false,
                          onTap: () => onOpenGoal(middle[row + 1]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (row + 2 < middle.length) const SizedBox(height: 6),
        ],
        const SizedBox(height: 6),
        SizedBox(
          height: 60,
          child: _IndicatorCard(
            indicator: temple,
            wide: true,
            asideLabel: 'Month Goal',
            asideValue: _monthlyTempleRatio(snapshot),
            secondaryLabel: snapshot.nextTempleVisit == null
                ? 'Set Schedule'
                : 'Next Visit: ${_formatNextVisit(context, snapshot.nextTempleVisit!)}',
            onTap: () => onOpenGoal(temple),
            onSecondaryTap: snapshot.nextTempleVisit == null
                ? onOpenTempleSchedule
                : null,
          ),
        ),
      ],
    );
  }

  String _todayGoalRatio(HomeIndicatorSnapshot snapshot) {
    final daily = snapshot.dailyJobApplications;
    final actual = daily?.actual.display ?? '0';
    final target = daily?.target.value?.display ?? '0';
    return '$actual/$target';
  }

  String _monthlyTempleRatio(HomeIndicatorSnapshot snapshot) {
    final actual = snapshot.monthlyTempleActual?.display ?? '0';
    final target = snapshot.monthlyTempleTarget?.value?.display ?? '0';
    return '$actual/$target';
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
    required this.wide,
    required this.onTap,
    this.asideLabel,
    this.asideValue,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  final LifeIndicatorSummary indicator;
  final bool wide;
  final String? asideLabel;
  final String? asideValue;
  final VoidCallback onTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

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
        Icon(_iconFor(indicator.key), color: AppTheme.rose, size: 26),
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
    return Row(
      children: <Widget>[
        Icon(_iconFor(indicator.key), color: AppTheme.rose, size: 27),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    foregroundColor: AppTheme.rose,
                  ),
                  child: const Text(
                    'Set Schedule',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        const SizedBox(width: 10),
        _WideAside(label: asideLabel!, value: asideValue!),
      ],
    );
  }
}

final class _WideAside extends StatelessWidget {
  const _WideAside({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      height: 46,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 15 / 13),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 19,
                  height: 20 / 19,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.rose,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

IconData _iconFor(String key) => switch (key) {
  'job_applications' => Icons.work_outline,
  'scripture_study' => Icons.menu_book_outlined,
  'exercise' => Icons.fitness_center,
  'meaningful_connections' => Icons.people_outline,
  'budget_review' => Icons.pie_chart_outline,
  'temple_visit' => Icons.account_balance_outlined,
  _ => Icons.insights_outlined,
};
