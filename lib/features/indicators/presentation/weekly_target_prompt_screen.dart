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
    final state = ref.watch(homeIndicatorControllerProvider);
    final snapshot = state.snapshot;
    final period = IndicatorPeriod(
      start: periodStart,
      end: periodStart.addDays(6),
    );
    final indicators = snapshot?.indicators
        .where(
          (indicator) => indicatorKey == null || indicator.key == indicatorKey,
        )
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Targets')),
      body: SafeArea(
        child: indicators == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
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
                  for (final indicator in indicators)
                    Card(
                      child: ListTile(
                        key: Key('target-${indicator.key}'),
                        title: Text(indicator.label),
                        subtitle: Text(
                          'Target: ${indicator.target.display} · '
                          'Scheduled: ${indicator.scheduledPotential.display}',
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _edit(context, ref, indicator, period),
                      ),
                    ),
                ],
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
            if (indicator.scheduledPotential.scaledValue > 0)
              TextButton(
                onPressed: () {
                  controller.text = indicator.scheduledPotential.display;
                },
                child: Text(
                  'Use scheduled potential '
                  '(${indicator.scheduledPotential.display})',
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
    await ref
        .read(homeIndicatorControllerProvider.notifier)
        .setTarget(indicatorKey: indicator.key, period: period, value: value);
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
