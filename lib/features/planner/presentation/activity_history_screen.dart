import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';

final class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  ConsumerState<ActivityHistoryScreen> createState() =>
      _ActivityHistoryScreenState();
}

final class _ActivityHistoryScreenState
    extends ConsumerState<ActivityHistoryScreen> {
  late Future<_ActivityHistoryData> _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final controller = ref.read(outcomeReportingControllerProvider.notifier);
    _load =
        Future.wait<Object>(<Future<Object>>[
          controller.readHistory(),
          controller.readLedgerHistory(effectiveOnly: false),
        ]).then(
          (values) => _ActivityHistoryData(
            reports: values[0] as List<OutcomeReport>,
            entries: values[1] as List<ActivityLedgerEntry>,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity History')),
      body: SafeArea(
        child: FutureBuilder<_ActivityHistoryData>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Activity history could not be opened. No local data '
                        'was changed.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => setState(_reload),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            if (data.reports.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No submitted reports yet. Drafts stay on their reporting '
                    'source until submitted.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await _load;
              },
              child: ListView(
                key: const Key('activity-history-list'),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                children: <Widget>[
                  const _HistoryNotice(),
                  const SizedBox(height: 12),
                  for (final report in data.reports)
                    _ReportHistoryCard(
                      report: report,
                      entries: data.entries
                          .where((entry) => entry.sourceReportId == report.id)
                          .toList(growable: false),
                      onCorrect: report.status == OutcomeReportStatus.submitted
                          ? () => _correct(report.id)
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _correct(String reportId) async {
    final changed = await context.push<bool>(
      RoutePaths.outcomeReportCorrection(reportId),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }
}

final class _ActivityHistoryData {
  const _ActivityHistoryData({required this.reports, required this.entries});

  final List<OutcomeReport> reports;
  final List<ActivityLedgerEntry> entries;
}

final class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.verified_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Effective reports appear first. Corrections never overwrite '
                'history: reversals and replacements remain auditable, while '
                'Actual is derived only from effective ledger entries.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReportHistoryCard extends StatelessWidget {
  const _ReportHistoryCard({
    required this.report,
    required this.entries,
    required this.onCorrect,
  });

  final OutcomeReport report;
  final List<ActivityLedgerEntry> entries;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context) {
    final effective = report.status == OutcomeReportStatus.submitted;
    return Card(
      key: Key('activity-report-${report.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(
          effective ? Icons.check_circle_outline : Icons.history,
          color: effective
              ? Theme.of(context).colorScheme.primary
              : Colors.white54,
        ),
        title: Text(report.source.label),
        subtitle: Text(
          '${report.activityDate.iso8601} · ${_outcomeLabel(report.outcome)} · '
          '${effective ? 'Effective' : 'Superseded'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: <Widget>[
          if (report.correctsReportId != null)
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_note_outlined),
              title: Text('Correction report'),
              subtitle: Text(
                'The original report remains preserved in this history.',
              ),
            ),
          if (report.correctionReason != null)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.subject),
              title: const Text('Correction reason'),
              subtitle: Text(report.correctionReason!),
            ),
          if (entries.isEmpty)
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('No contribution was recorded.'),
            )
          else
            for (final entry in entries)
              ListTile(
                key: Key('ledger-entry-${entry.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.type == ActivityLedgerEntryType.reversal
                      ? Icons.undo
                      : Icons.add_chart,
                ),
                title: Text(
                  '${entry.value.displayValue} ${entry.value.unit} · '
                  '${entry.indicatorKey}',
                ),
                subtitle: Text(
                  entry.type == ActivityLedgerEntryType.reversal
                      ? 'Reversal preserved for audit'
                      : entry.isEffective
                      ? 'Effective contribution'
                      : 'Reversed contribution',
                ),
              ),
          if (onCorrect != null)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: Key('correct-report-${report.id}'),
                onPressed: onCorrect,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('Correct Report'),
              ),
            ),
        ],
      ),
    );
  }

  static String _outcomeLabel(OutcomeKind? outcome) {
    return switch (outcome) {
      OutcomeKind.completedHappened => 'Completed / Happened',
      OutcomeKind.partiallyCompleted => 'Partially Completed',
      OutcomeKind.didNotHappen => 'Did Not Happen',
      null => 'Draft',
    };
  }
}
