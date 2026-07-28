import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

final class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(plannerControllerProvider);
    final controller = ref.read(plannerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Planner sections',
          onPressed: () => _showPlannerSections(context),
          icon: const Icon(Icons.menu),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Planner'),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 22),
          ],
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('planner-activity-history-button'),
            tooltip: 'Activity History',
            onPressed: () => context.push(RoutePaths.activityHistory),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Privacy and Data',
            onPressed: () => context.push(RoutePaths.privacyCenter),
            icon: const Icon(Icons.shield_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _WeekStrip(
              selectedDate: state.selectedDate,
              onSelected: controller.selectDate,
              onOpenCalendar: () => _openCalendar(context, controller, state),
            ),
            Expanded(child: _buildContent(context, ref, state)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('planner-create-button'),
        tooltip: 'Create Task, Calendar Event, or Activity Report',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () => _showCreateActions(context, state.selectedDate),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    PlannerState state,
  ) {
    final day = state.day;
    if (state.status == PlannerLoadStatus.loading && day == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == PlannerLoadStatus.failure && day == null) {
      return _PlannerFailure(
        message: state.message ?? 'Planner data could not be opened.',
        onRetry: () => ref
            .read(plannerControllerProvider.notifier)
            .selectDate(state.selectedDate),
      );
    }
    if (day == null) {
      return const SizedBox.shrink();
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(plannerControllerProvider.notifier)
          .selectDate(state.selectedDate),
      child: ListView(
        key: const Key('planner-day-scroll'),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
        children: <Widget>[
          if (state.message != null) ...<Widget>[
            _PlannerNotice(message: state.message!),
            const SizedBox(height: 12),
          ],
          if (day.allDayEvents.isEmpty)
            const SizedBox.shrink(key: Key('all-day-section'))
          else
            Padding(
              key: const Key('all-day-section'),
              padding: const EdgeInsets.only(bottom: 10),
              child: _CompactAllDayEvents(events: day.allDayEvents),
            ),
          KeyedSubtree(
            key: const Key('timed-events-section'),
            child: _TimedEventTimeline(events: day.timedEvents),
          ),
          _PlannerSection(
            key: const Key('tasks-section'),
            title: 'Tasks',
            icon: Icons.task_alt_outlined,
            children: <Widget>[
              for (final task in day.tasks) _TaskTile(task: task),
            ],
          ),
          _PlannerSection(
            key: const Key('overdue-section'),
            title: 'Overdue Tasks',
            icon: Icons.priority_high,
            accent: AppTheme.warning,
            children: <Widget>[
              for (final task in day.overdueTasks) _TaskTile(task: task),
            ],
          ),
          _PlannerSection(
            key: const Key('awaiting-report-section'),
            title: 'Awaiting Report',
            icon: Icons.assignment_late_outlined,
            accent: AppTheme.rose,
            children: <Widget>[
              for (final event in day.awaitingReportEvents)
                _EventTile(event: event, awaitingReport: true),
            ],
          ),
          _PlannerSection(
            key: const Key('changes-section'),
            title: 'Changes',
            icon: Icons.history,
            trailing: IconButton(
              tooltip: state.historicalItemsExpanded
                  ? 'Collapse historical items'
                  : 'Expand historical items',
              onPressed: () => ref
                  .read(plannerControllerProvider.notifier)
                  .toggleHistoricalItems(),
              icon: Icon(
                state.historicalItemsExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
            ),
            children: state.historicalItemsExpanded
                ? <Widget>[
                    for (final change in day.changes)
                      _ChangeTile(change: change),
                  ]
                : const <Widget>[],
          ),
        ],
      ),
    );
  }

  Future<void> _openCalendar(
    BuildContext context,
    PlannerController controller,
    PlannerState state,
  ) async {
    final selected = state.selectedDate;
    final result = await showDatePicker(
      context: context,
      initialDate: selected.asLocalDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: 'Select Planner date',
    );
    if (result != null) {
      await controller.selectDate(PlannerDate.fromDateTime(result));
    }
  }

  Future<void> _showCreateActions(
    BuildContext context,
    PlannerDate selectedDate,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Create',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    key: const Key('create-task-action'),
                    leading: const Icon(Icons.task_alt_outlined),
                    title: const Text('Task'),
                    subtitle: const Text('Create immediately on this device'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(
                        context.push(
                          '${RoutePaths.taskCreate}'
                          '?date=${selectedDate.iso8601}',
                        ),
                      );
                    },
                  ),
                  ListTile(
                    key: const Key('create-calendar-event-action'),
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Calendar Event'),
                    subtitle: const Text(
                      'Separate from Tasks and saved offline',
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(
                        context.push(
                          '${RoutePaths.calendarEventCreate}'
                          '?date=${selectedDate.iso8601}',
                        ),
                      );
                    },
                  ),
                  ListTile(
                    key: const Key('create-activity-report-action'),
                    leading: const Icon(Icons.assignment_outlined),
                    title: const Text('Activity Report'),
                    subtitle: const Text(
                      'Structured manual reporting; never raw ledger editing',
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      unawaited(
                        context.push(
                          '${RoutePaths.outcomeReportCreate}'
                          '?date=${selectedDate.iso8601}',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPlannerSections(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text(
              'Planner keeps all-day events, timed events, Tasks, overdue '
              'Tasks, Awaiting Report, and Changes visibly separate.',
            ),
          ),
        );
      },
    );
  }
}

final class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDate,
    required this.onSelected,
    required this.onOpenCalendar,
  });

  final PlannerDate selectedDate;
  final ValueChanged<PlannerDate> onSelected;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final sundayOffset = selectedDate.weekday % 7;
    final weekStart = selectedDate.addDays(-sundayOffset);
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Choose any date',
            onPressed: onOpenCalendar,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.calendar_month, color: AppTheme.rose),
          ),
          Container(width: 1, height: 52, color: AppTheme.outline),
          const SizedBox(width: 4),
          for (var index = 0; index < 7; index++)
            Expanded(
              child: _DayButton(
                date: weekStart.addDays(index),
                selected: weekStart.addDays(index) == selectedDate,
                onSelected: onSelected,
              ),
            ),
        ],
      ),
    );
  }
}

final class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selected,
    required this.onSelected,
  });

  final PlannerDate date;
  final bool selected;
  final ValueChanged<PlannerDate> onSelected;

  static const _labels = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.rose : Theme.of(context).hintColor;
    return Semantics(
      key: selected ? const Key('planner-selected-date') : null,
      selected: selected,
      label:
          '${_labels[date.weekday - 1]} ${date.iso8601}'
          '${selected ? ', selected' : ''}',
      button: true,
      child: InkWell(
        key: Key('planner-day-${date.iso8601}'),
        onTap: () => onSelected(date),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            border: selected
                ? Border.all(color: AppTheme.rose, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _labels[date.weekday - 1],
                style: TextStyle(fontSize: 11, color: color),
              ),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PlannerSection extends StatelessWidget {
  const _PlannerSection({
    required this.title,
    required this.icon,
    required this.children,
    this.accent,
    this.trailing,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: accent ?? AppTheme.rose),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            const _EmptySectionMessage('Nothing in this section.')
          else
            ...children,
        ],
      ),
    );
  }
}

final class _CompactAllDayEvents extends StatelessWidget {
  const _CompactAllDayEvents({required this.events});

  final List<PlannerCalendarItem> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.event_available_outlined,
              size: 18,
              color: AppTheme.rose,
            ),
            const SizedBox(width: 7),
            Text(
              'All-day events',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final event in events) _EventTile(event: event),
      ],
    );
  }
}

final class _TimedEventTimeline extends StatelessWidget {
  const _TimedEventTimeline({required this.events});

  final List<PlannerCalendarItem> events;

  static const double _hourHeight = 60;
  static const int _firstHour = 6;
  static const int _lastHour = 22;
  static const double _timeColumnWidth = 54;

  @override
  Widget build(BuildContext context) {
    const slotCount = _lastHour - _firstHour + 1;
    const timelineHeight = slotCount * _hourHeight;
    return SizedBox(
      key: const Key('planner-time-grid'),
      height: timelineHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var index = 0; index < slotCount; index++) ...<Widget>[
            Positioned(
              top: index * _hourHeight,
              left: 0,
              width: _timeColumnWidth - 8,
              child: Text(
                _hourLabel(_firstHour + index),
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.white60),
              ),
            ),
            Positioned(
              top: index * _hourHeight + 7,
              left: _timeColumnWidth,
              right: 0,
              child: const Divider(height: 1, color: AppTheme.outline),
            ),
          ],
          Positioned(
            top: 0,
            bottom: 0,
            left: _timeColumnWidth,
            child: Container(width: 1, color: AppTheme.outline),
          ),
          if (events.isEmpty)
            const Positioned(
              top: 18,
              left: _timeColumnWidth + 14,
              right: 8,
              child: _EmptySectionMessage(
                'No timed Calendar Events for this day.',
              ),
            ),
          for (final event in events) _positionedEvent(event, timelineHeight),
        ],
      ),
    );
  }

  static Widget _positionedEvent(
    PlannerCalendarItem event,
    double timelineHeight,
  ) {
    final start = event.startLocal;
    final end = event.endLocal;
    final startMinutes = start == null
        ? 0
        : ((start.hour - _firstHour) * 60 + start.minute).clamp(
            0,
            (_lastHour - _firstHour + 1) * 60 - 30,
          );
    final durationMinutes = start == null || end == null
        ? 45
        : end.difference(start).inMinutes.clamp(30, 24 * 60);
    final top = startMinutes * (_hourHeight / 60);
    final height = (durationMinutes * (_hourHeight / 60))
        .clamp(36, timelineHeight - top)
        .toDouble();
    return Positioned(
      key: Key('planner-timed-event-${event.id}'),
      top: top,
      left: _timeColumnWidth + 7,
      right: 0,
      height: height,
      child: _TimelineEventBlock(event: event),
    );
  }

  static String _hourLabel(int hour24) {
    final hour = hour24 == 0
        ? 12
        : hour24 > 12
        ? hour24 - 12
        : hour24;
    return '$hour ${hour24 >= 12 ? 'PM' : 'AM'}';
  }
}

final class _TimelineEventBlock extends StatelessWidget {
  const _TimelineEventBlock({required this.event});

  final PlannerCalendarItem event;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${event.title}, Calendar Event, ${_timeRange(event)}'
          '${event.linkedTaskIds.isEmpty ? '' : ', ${event.linkedTaskIds.length} linked Task(s)'}',
      child: Material(
        color: AppTheme.eventAccent.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppTheme.eventAccent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openCalendarEvent(context, event),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (event.isRecurring) ...const <Widget>[
                            SizedBox(width: 5),
                            Icon(Icons.repeat, size: 15),
                          ],
                          if (event.linkedTaskIds.isNotEmpty) ...<Widget>[
                            const SizedBox(width: 5),
                            Tooltip(
                              message:
                                  '${event.linkedTaskIds.length} linked Task(s)',
                              child: const Icon(Icons.link, size: 15),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _timeRange(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white60,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _timeRange(PlannerCalendarItem event) {
    return '${_EventTile._time(event.startLocal)} – '
        '${_EventTile._time(event.endLocal)}';
  }
}

final class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final PlannerTask task;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        key: Key('planner-task-${task.id}'),
        leading: const Icon(Icons.task_alt_outlined, color: AppTheme.rose),
        title: Text(task.title),
        subtitle: Text(_taskSubtitle(task)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('${RoutePaths.tasks}/${task.id}'),
      ),
    );
  }

  static String _taskSubtitle(PlannerTask task) {
    final due = task.dueDate;
    final dueText = due == null ? 'No due date' : 'Due ${due.iso8601}';
    return task.requiresReport ? '$dueText · Report required' : dueText;
  }
}

final class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, this.awaitingReport = false});

  final PlannerCalendarItem event;
  final bool awaitingReport;

  @override
  Widget build(BuildContext context) {
    final detail = <String>[
      if (event.timing == PlannerEventTiming.allDay) 'All day',
      if (event.timing == PlannerEventTiming.timed)
        '${_time(event.startLocal)} – ${_time(event.endLocal)}',
      if (event.locationText != null) event.locationText!,
      if (event.linkedTaskIds.isNotEmpty)
        '${event.linkedTaskIds.length} linked Task(s)',
      if (awaitingReport) 'Awaiting Report',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          event.timing == PlannerEventTiming.allDay
              ? Icons.event_available_outlined
              : Icons.schedule,
          color: awaitingReport ? AppTheme.warning : AppTheme.eventAccent,
        ),
        title: Row(
          children: <Widget>[
            Flexible(child: Text(event.title)),
            if (event.isRecurring) ...const <Widget>[
              SizedBox(width: 6),
              Icon(Icons.repeat, size: 16),
            ],
          ],
        ),
        subtitle: Text(detail),
        trailing: event.locationText == null
            ? const Icon(Icons.chevron_right)
            : IconButton(
                tooltip: 'Open contextual map action',
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The stored location remains visible. Map handoff is '
                      'not available in this authorized build.',
                    ),
                  ),
                ),
                icon: const Icon(Icons.map_outlined),
              ),
        onTap: () => _openCalendarEvent(context, event),
      ),
    );
  }

  static String _time(DateTime? value) {
    if (value == null) {
      return 'Time not set';
    }
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    return '$hour:${value.minute.toString().padLeft(2, '0')} '
        '${value.hour >= 12 ? 'PM' : 'AM'}';
  }
}

final class _ChangeTile extends StatelessWidget {
  const _ChangeTile({required this.change});

  final PlannerChangeItem change;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        change.isTask ? Icons.task_alt_outlined : Icons.event_outlined,
      ),
      title: Text(change.title),
      subtitle: Text(change.label),
      onTap: change.isTask
          ? () => context.push('${RoutePaths.tasks}/${change.id}')
          : change.eventId == null || change.originalDate == null
          ? null
          : () => context.push(
              RoutePaths.calendarEventDetail(
                change.eventId!,
                change.originalDate!,
              ),
            ),
    );
  }
}

void _openCalendarEvent(BuildContext context, PlannerCalendarItem event) {
  final eventId = event.eventId;
  final originalDate = event.originalDate;
  if (eventId == null || originalDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This external calendar item has no editable local record.',
        ),
      ),
    );
    return;
  }
  unawaited(
    context.push(RoutePaths.calendarEventDetail(eventId, originalDate)),
  );
}

final class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

final class _PlannerNotice extends StatelessWidget {
  const _PlannerNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.rose.withValues(alpha: 0.12),
        border: Border.all(color: AppTheme.rose),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message),
    );
  }
}

final class _PlannerFailure extends StatelessWidget {
  const _PlannerFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
