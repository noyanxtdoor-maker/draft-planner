import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

final class WeeklyPlanHistoryScreen extends ConsumerWidget {
  const WeeklyPlanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(weeklyPlanHistoryProvider);
    return Scaffold(
      appBar: InternalAppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('weekly-plan-history-back'),
          tooltip: 'Back to Planning',
          // Pack 2 B5/B6: Back pops this pushed page so Planning (its logical
          // parent) is revealed; a direct entry with no parent page falls
          // back to the Planning route instead of exiting.
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.weeklyPlanning);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Plan History'),
      ),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (plans) => plans.isEmpty
              ? const Center(child: Text('No Weekly Plans yet.'))
              : ListView.separated(
                  key: const Key('weekly-plan-history-list'),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                        // Pack 2 B5: selecting a prior week pops this page
                        // and hands the chosen week to the Planning screen
                        // beneath it as the push result.  The week becomes
                        // local Planning state, so Back from Planning still
                        // returns Home directly (no week-by-week unwinding).
                        onTap: () => context.pop(plan.period.start),
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
