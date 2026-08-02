import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class WeeklyTargetPromptScreen extends ConsumerWidget {
  const WeeklyTargetPromptScreen({
    required this.periodStart,
    this.indicatorKey,
    super.key,
  });

  final PlannerDate periodStart;
  final String? indicatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = IndicatorPeriod(
      start: periodStart,
      end: periodStart.addDays(6),
    );
    final snapshot = ref.watch(indicatorPeriodSnapshotProvider(period));
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Targets')),
      body: SafeArea(
        child: snapshot.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Weekly targets could not be opened. No data was changed.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (value) => ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text(
                '${period.start.iso8601} — ${period.end.iso8601}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Targets are optional. Not set and explicit zero are '
                'different. Actual is read-only and never changed here.',
              ),
              const SizedBox(height: 18),
              for (final indicator in value.indicators.where(
                (indicator) =>
                    indicatorKey == null || indicator.key == indicatorKey,
              ))
                Card(
                  child: ListTile(
                    key: Key('target-${indicator.key}'),
                    title: Text(indicator.label),
                    subtitle: Text('Target: ${indicator.target.display}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          key: Key('target-history-${indicator.key}'),
                          tooltip: 'Target revision history',
                          onPressed: () =>
                              _showHistory(context, ref, indicator, period),
                          icon: const Icon(Icons.history),
                        ),
                        const Icon(Icons.edit_outlined),
                      ],
                    ),
                    onTap: () => _edit(context, ref, indicator, period),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    LifeIndicatorSummary indicator,
    IndicatorPeriod period,
  ) async {
    final controller = TextEditingController(
      text: indicator.target.value?.display ?? '',
    );
    final result = await showDialog<_TargetChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${indicator.label} target'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('weekly-target-value-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Target (${indicator.unit})',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(const _TargetChoice.clear()),
            child: const Text('Set Not set'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_TargetChoice.value(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !context.mounted) {
      return;
    }
    IndicatorAmount? value;
    if (!result.clear) {
      final parsed = _parseTarget(result.rawValue!, indicator.unit);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid non-negative target.')),
        );
        return;
      }
      value = IndicatorAmount(
        scaledValue: parsed.scaledValue,
        scale: parsed.scale,
        unit: parsed.unit,
      );
    }
    try {
      await ref
          .read(homeIndicatorControllerProvider.notifier)
          .setTarget(indicatorKey: indicator.key, period: period, value: value);
      ref.invalidate(indicatorPeriodSnapshotProvider(period));
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Target was not changed. Reviewed weeks are read-only.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showHistory(
    BuildContext context,
    WidgetRef ref,
    LifeIndicatorSummary indicator,
    IndicatorPeriod period,
  ) async {
    final revisions = await ref
        .read(homeIndicatorControllerProvider.notifier)
        .readTargetHistory(
          indicatorKey: indicator.key,
          periodStart: period.start,
        );
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${indicator.label} target history'),
        content: revisions.isEmpty
            ? const Text('No target revisions for this week.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: revisions.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final revision = revisions[index];
                    return ListTile(
                      title: Text('Target ${revision.target.display}'),
                      subtitle: Text(revision.createdAtUtc.toIso8601String()),
                    );
                  },
                ),
              ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IndicatorAmount? _parseTarget(String raw, String unit) {
    final text = raw.trim();
    final allowedScale = unit == 'hours' ? 2 : 0;
    final match = RegExp(r'^([0-9]+)(?:\.([0-9]+))?$').firstMatch(text);
    if (match == null) {
      return null;
    }
    final decimals = match.group(2) ?? '';
    if (decimals.length > allowedScale) {
      return null;
    }
    try {
      var power = 1;
      for (var i = 0; i < allowedScale; i += 1) {
        power *= 10;
      }
      final scaled =
          int.parse(match.group(1)!) * power +
          (allowedScale == 0
              ? 0
              : int.parse(decimals.padRight(allowedScale, '0')));
      if (scaled > 9223372036854775807) {
        return null;
      }
      return IndicatorAmount(
        scaledValue: scaled,
        scale: allowedScale,
        unit: unit,
      );
    } on FormatException {
      return null;
    }
  }
}

final class _TargetChoice {
  const _TargetChoice.value(this.rawValue) : clear = false;
  const _TargetChoice.clear() : rawValue = null, clear = true;

  final String? rawValue;
  final bool clear;
}
