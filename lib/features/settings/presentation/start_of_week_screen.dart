import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

/// User-facing first day of the week selector (Monday .. Sunday).
///
/// The current persisted preference is preselected.  Choosing a DIFFERENT day
/// shows a clear confirmation before saving: the current Goal Planning period
/// is recalculated, but existing plans, goals, reports, and history are never
/// deleted.  Re-selecting the current value performs no write.
final class StartOfWeekScreen extends ConsumerStatefulWidget {
  const StartOfWeekScreen({super.key});

  @override
  ConsumerState<StartOfWeekScreen> createState() => _StartOfWeekScreenState();
}

final class _StartOfWeekScreenState extends ConsumerState<StartOfWeekScreen> {
  static const List<String> _dayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  int _selected = DateTime.monday;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(startOfWeekProvider);
    // Keep the local selection in sync with the persisted value when this
    // screen is opened after a prior change or a provider reload.
    _selected = current;
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Start of week')),
      body: SafeArea(
        child: ListView(
          padding: InternalScreen.pagePadding,
          children: <Widget>[
            RadioGroup<int>(
              groupValue: _selected,
              onChanged: (value) {
                if (value == null || value == _selected) {
                  return;
                }
                unawaited(_onSelect(context, value));
              },
              child: Column(
                children: <Widget>[
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    RadioListTile<int>(
                      key: Key('start-of-week-$day'),
                      value: day,
                      title: Text(_dayNames[day - DateTime.monday]),
                      activeColor: AppTheme.rose,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSelect(BuildContext context, int value) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change start of week?'),
        content: Text(
          'Your current Goal Planning period will be recalculated using '
          '${_dayNames[value - DateTime.monday]} as the first day. Existing '
          'plans, goals, reports, and history will not be deleted.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('start-of-week-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('start-of-week-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (changed != true || !mounted) {
      return;
    }
    final saved = await ref
        .read(startOfWeekProvider.notifier)
        .setStartOfWeek(value);
    if (!saved || !mounted) {
      return;
    }
    // The current period identity changed: re-resolve Home / Goal Planning
    // and the plan-established signal for the newly resolved week.
    ref.invalidate(goalPlanningProvider);
    ref.invalidate(weeklyPlanEstablishedProvider);
    // Return to Settings so the row subtitle reflects the new day.
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
