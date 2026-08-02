import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';

final class IndicatorListScreen extends ConsumerWidget {
  const IndicatorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref
        .read(homeIndicatorControllerProvider.notifier)
        .currentPeriod;
    final snapshot = ref.watch(indicatorPeriodSnapshotProvider(period));
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Life Indicators')),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('Life Indicators could not be loaded.')),
          data: (value) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 96),
            itemCount: value.indicators.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final indicator = value.indicators[index];
              return ListTile(
                key: Key('indicator-list-${indicator.key}'),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                title: Text(indicator.label),
                subtitle: Text(
                  'Actual ${indicator.actual.display} · '
                  'Target ${indicator.target.display}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  RoutePaths.indicatorDetail(indicator.key, value.period.start),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
