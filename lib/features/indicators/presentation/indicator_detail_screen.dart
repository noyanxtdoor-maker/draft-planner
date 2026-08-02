import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';

final class IndicatorDetailScreen extends ConsumerWidget {
  const IndicatorDetailScreen({
    required this.indicatorKey,
    required this.periodStart,
    super.key,
  });

  final String indicatorKey;
  final PlannerDate periodStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = IndicatorPeriod(
      start: periodStart,
      end: periodStart.addDays(6),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Indicator Detail')),
      body: SafeArea(
        child: FutureBuilder<IndicatorDetail?>(
          future: ref
              .read(homeIndicatorControllerProvider.notifier)
              .readDetail(indicatorKey, period),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final detail = snapshot.data;
            if (detail == null) {
              return const Center(child: Text('Life Indicator not found.'));
            }
            final summary = detail.summary;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  summary.label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${period.start.iso8601} - ${period.end.iso8601}',
                  key: const Key('indicator-detail-period'),
                ),
                const SizedBox(height: 18),
                _MetricRow(summary: summary),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('indicator-edit-button'),
                  onPressed: () => context.push(
                    RoutePaths.indicatorEdit(indicatorKey, period.start),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit indicator names'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    RoutePaths.weeklyPlanningTargets(
                      period.start,
                      indicatorKey: indicatorKey,
                    ),
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Set or change weekly target'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('indicator-schedule-activity'),
                  onPressed: () => unawaited(
                    launchCalendarEventCreation<void>(
                      context,
                      ref,
                      CalendarEventCreationContext(
                        source: 'life-indicator',
                        destinationPath: RoutePaths.calendarEventCreate,
                        date: period.start,
                        indicatorKey: indicatorKey,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_task_outlined),
                  label: const Text('Schedule activity'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Contribution History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (detail.contributionHistory.isEmpty)
                  const Text('No Activity Ledger contributions this week.')
                else
                  for (final item in detail.contributionHistory)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.isReversal
                            ? Icons.undo_outlined
                            : Icons.add_circle_outline,
                      ),
                      title: Text(item.sourceLabel),
                      subtitle: Text(item.activityDate.iso8601),
                      trailing: Text(item.value.display),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.summary});

  final LifeIndicatorSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            _Cell(label: 'Actual', value: summary.actual.display),
            _Cell(label: 'Target', value: summary.target.display),
          ],
        ),
      ),
    );
  }
}

final class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(label, textAlign: TextAlign.center),
          const SizedBox(height: 5),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
