import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

final class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({required this.planId, super.key});

  final String planId;

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

final class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  final TextEditingController _reflection = TextEditingController();
  bool _acknowledged = false;
  bool _saving = false;

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(weeklyPlanByIdProvider(widget.planId));
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Review')),
      body: SafeArea(
        child: value.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (plan) {
            if (plan == null) {
              return const Center(child: Text('Weekly Plan not found.'));
            }
            if (plan.review != null) {
              return _CompletedReview(plan: plan);
            }
            return ListView(
              key: const Key('weekly-review-list'),
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  '${plan.period.start.iso8601} — ${plan.period.end.iso8601}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Review factual outcomes. Actual remains ledger-derived; '
                  'this screen cannot fabricate progress.',
                ),
                const SizedBox(height: 16),
                for (final indicator in plan.indicators)
                  ListTile(
                    title: Text(indicator.label),
                    subtitle: Text(
                      'Actual ${indicator.actual.display} · '
                      'Target ${indicator.target.display} · '
                      'Scheduled ${indicator.scheduled.display}',
                    ),
                  ),
                const Divider(),
                Text(
                  'Outstanding reports (${plan.unresolvedReports.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (plan.unresolvedReports.isEmpty)
                  const ListTile(
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('No unresolved reports'),
                  )
                else
                  for (final item in plan.unresolvedReports)
                    ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: Text(item.label),
                      subtitle: const Text('Outcome report outstanding'),
                    ),
                if (plan.unresolvedReports.isNotEmpty)
                  CheckboxListTile(
                    key: const Key('weekly-review-acknowledge'),
                    contentPadding: EdgeInsets.zero,
                    value: _acknowledged,
                    onChanged: (value) =>
                        setState(() => _acknowledged = value ?? false),
                    title: const Text(
                      'I acknowledge these reports are still unresolved.',
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('weekly-review-reflection'),
                  controller: _reflection,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Private reflection (optional)',
                    helperText: 'Local-only and never contributes to Actual.',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('weekly-review-complete'),
                  onPressed:
                      _saving ||
                          (plan.unresolvedReports.isNotEmpty && !_acknowledged)
                      ? null
                      : () => _complete(plan),
                  child: Text(_saving ? 'Saving…' : 'Complete review'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _complete(WeeklyPlan plan) async {
    setState(() => _saving = true);
    try {
      final identifiers = ref.read(weeklyPlanningIdentifierProvider);
      await ref
          .read(weeklyPlanningRepositoryProvider)
          .completeReview(
            profileId: ref.read(weeklyPlanningProfileIdProvider),
            planId: plan.id,
            reviewId: identifiers.nextUuid(),
            operationId: identifiers.nextUuid(),
            unresolvedReportsAcknowledged: _acknowledged,
            privateReflection: _reflection.text,
          );
      ref.invalidate(weeklyPlanByIdProvider(plan.id));
      ref.invalidate(weeklyPlanProvider(plan.period.start));
      ref.invalidate(weeklyPlanHistoryProvider);
      if (mounted) {
        context.pop();
      }
    } on WeeklyPlanningValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

final class _CompletedReview extends StatelessWidget {
  const _CompletedReview({required this.plan});

  final WeeklyPlan plan;

  @override
  Widget build(BuildContext context) {
    final review = plan.review!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const ListTile(
          leading: Icon(Icons.verified_outlined),
          title: Text('Review complete'),
        ),
        for (final indicator in review.indicators)
          ListTile(
            title: Text(indicator.label),
            subtitle: Text(
              'Actual ${indicator.actual.display} · '
              'Target ${indicator.target.display} · '
              'Scheduled ${indicator.scheduled.display}',
            ),
          ),
        if (review.privateReflection != null)
          const Text('A private local reflection is stored.'),
        if (plan.postReviewChanges.isNotEmpty)
          Text(
            '${plan.postReviewChanges.length} factual change(s) were recorded '
            'after review completion.',
          ),
      ],
    );
  }
}
