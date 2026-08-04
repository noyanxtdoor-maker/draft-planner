import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

final class WeeklyPlanHistoryScreen extends ConsumerWidget {
  const WeeklyPlanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weeklyPlanHistoryProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('weekly-plan-history-back'),
          tooltip: 'Back to Planning',
          onPressed: () => context.go(RoutePaths.weeklyPlanning),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Prior Weeks'),
      ),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (plans) => plans.isEmpty
              ? const Center(child: Text('No Weekly Plans yet.'))
              : ListView.separated(
                  key: const Key('weekly-plan-history-list'),
                  padding: const EdgeInsets.all(20),
                  itemCount: plans.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          '${plan.period.start.iso8601} — '
                          '${plan.period.end.iso8601}',
                        ),
                        subtitle: Text(_stateLabel(plan.storedState)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          RoutePaths.weeklyPlanningFor(plan.period.start),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
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
}
