import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// The two owner-approved recurrence scopes presented as unmistakable,
/// whole-row actions. This widget deliberately contains no recurrence logic;
/// callers retain their existing occurrence/series mutation semantics.
final class RepeatingEventScopeChoices extends StatelessWidget {
  const RepeatingEventScopeChoices({
    required this.originalDate,
    required this.onSelected,
    required this.keyPrefix,
    super.key,
  });

  final PlannerDate originalDate;
  final ValueChanged<CalendarEventEditScope> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Choose what this change applies to.'),
        const SizedBox(height: 14),
        _ScopeChoiceCard(
          key: Key('$keyPrefix-this'),
          title: 'This event only',
          helper: 'Change only ${_formattedDate(originalDate)}',
          onTap: () => onSelected(CalendarEventEditScope.occurrence),
        ),
        const SizedBox(height: 10),
        _ScopeChoiceCard(
          key: Key('$keyPrefix-all'),
          title: 'All events',
          helper: 'Update this repeating series',
          onTap: () => onSelected(CalendarEventEditScope.series),
        ),
      ],
    );
  }

  static String _formattedDate(PlannerDate date) {
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} '
        '${date.day}';
  }
}

final class _ScopeChoiceCard extends StatelessWidget {
  const _ScopeChoiceCard({
    required this.title,
    required this.helper,
    required this.onTap,
    super.key,
  });

  final String title;
  final String helper;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.radio_button_unchecked,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        helper,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
