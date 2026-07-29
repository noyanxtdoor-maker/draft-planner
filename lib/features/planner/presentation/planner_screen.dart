import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';

final class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

final class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final ScrollController _dayScrollController = ScrollController();
  final GlobalKey _dayScrollKey = GlobalKey();
  final GlobalKey _timelineKey = GlobalKey();
  String? _initialScrollSignature;

  @override
  void dispose() {
    _dayScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(plannerControllerProvider);
    final controller = ref.read(plannerControllerProvider.notifier);
    final plannerSettings = ref.watch(eventTypeControllerProvider).settings;

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
            key: const Key('planner-settings-button'),
            tooltip: 'Planner and Calendar settings',
            onPressed: () => context.push(RoutePaths.plannerSettings),
            icon: const Icon(Icons.tune),
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
              weekStartDay: plannerSettings.weekStartDay,
              onSelected: controller.selectDate,
              onOpenCalendar: () => _openCalendar(context, controller, state),
            ),
            Expanded(
              child: _buildContent(context, ref, state, plannerSettings),
            ),
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
    PlannerSettings settings,
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
    _scheduleInitialScroll(
      selectedDate: state.selectedDate,
      settings: settings,
      timedEvents: day.timedEvents,
    );

    return RefreshIndicator(
      onRefresh: () => ref
          .read(plannerControllerProvider.notifier)
          .selectDate(state.selectedDate),
      child: KeyedSubtree(
        key: _dayScrollKey,
        child: SingleChildScrollView(
          key: const Key('planner-day-scroll'),
          controller: _dayScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
          child: Column(
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
              Container(
                key: _timelineKey,
                child: KeyedSubtree(
                  key: const Key('timed-events-section'),
                  child: _TimedEventTimeline(
                    events: day.timedEvents
                        .where(
                          (event) =>
                              (settings.showCancelledItems ||
                                  event.state != PlannerEventState.cancelled) &&
                              (settings.showCompletedItems ||
                                  (event.state !=
                                          PlannerEventState.completedHappened &&
                                      event.state !=
                                          PlannerEventState
                                              .partiallyCompleted)),
                        )
                        .toList(growable: false),
                    selectedDate: state.selectedDate,
                    settings: settings,
                    onCreate: (minute) =>
                        _createTimedEvent(context, state.selectedDate, minute),
                    onMove: (event, startMinute) =>
                        _moveEvent(ref, event, startMinute),
                    onResize: (event, endMinute) =>
                        _resizeEvent(ref, event, endMinute),
                  ),
                ),
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
        ),
      ),
    );
  }

  void _scheduleInitialScroll({
    required PlannerDate selectedDate,
    required PlannerSettings settings,
    required List<PlannerCalendarItem> timedEvents,
  }) {
    final signature =
        '${selectedDate.iso8601}:${settings.visibleStartHour}:'
        '${settings.visibleEndHour}:${settings.initialScrollBehavior.name}';
    if (_initialScrollSignature == signature) {
      return;
    }
    _initialScrollSignature = signature;
    final starts =
        timedEvents
            .map((event) => event.startLocal)
            .whereType<DateTime>()
            .map((value) => value.hour * 60 + value.minute)
            .toList(growable: false)
          ..sort();
    final targetMinute = plannerInitialScrollMinute(
      settings: settings,
      selectedDate: selectedDate,
      now: DateTime.now(),
      firstRelevantEventMinute: starts.firstOrNull,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dayScrollController.hasClients) {
        return;
      }
      final timelineBox =
          _timelineKey.currentContext?.findRenderObject() as RenderBox?;
      final scrollBox =
          _dayScrollKey.currentContext?.findRenderObject() as RenderBox?;
      if (timelineBox == null || scrollBox == null) {
        return;
      }
      final timelineTop =
          timelineBox.localToGlobal(Offset.zero).dy -
          scrollBox.localToGlobal(Offset.zero).dy +
          _dayScrollController.offset;
      final minuteOffset = targetMinute - settings.visibleStartHour * 60;
      final desired = (timelineTop + minuteOffset - 120).clamp(
        0.0,
        _dayScrollController.position.maxScrollExtent,
      );
      unawaited(
        _dayScrollController.animateTo(
          desired,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _createTimedEvent(
    BuildContext context,
    PlannerDate selectedDate,
    int startMinute,
  ) {
    unawaited(
      context.push(
        '${RoutePaths.calendarEventCreate}'
        '?date=${selectedDate.iso8601}&startMinute=$startMinute',
      ),
    );
  }

  Future<bool> _moveEvent(
    WidgetRef ref,
    PlannerCalendarItem event,
    int startMinute,
  ) async {
    final start = event.startLocal;
    final end = event.endLocal;
    if (start == null || end == null) {
      return false;
    }
    final duration = end.difference(start).inMinutes;
    return _persistTimelineEdit(
      ref,
      event,
      startMinute: startMinute,
      endMinute: (startMinute + duration).clamp(1, 1440),
    );
  }

  Future<bool> _resizeEvent(
    WidgetRef ref,
    PlannerCalendarItem event,
    int endMinute,
  ) async {
    final start = event.startLocal;
    if (start == null) {
      return false;
    }
    final startMinute = start.hour * 60 + start.minute;
    return _persistTimelineEdit(
      ref,
      event,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  Future<bool> _persistTimelineEdit(
    WidgetRef ref,
    PlannerCalendarItem event, {
    required int startMinute,
    required int endMinute,
  }) async {
    final eventId = event.eventId;
    final originalDate = event.originalDate;
    if (eventId == null ||
        originalDate == null ||
        endMinute <= startMinute ||
        endMinute > 1440) {
      return false;
    }
    final controller = ref.read(calendarEventControllerProvider.notifier);
    final existing = await controller.readEventDraft(eventId);
    if (existing == null) {
      return false;
    }
    final operationId = ref.read(plannerIdentifierSourceProvider).nextUuid();
    return controller.editEvent(
      eventId: eventId,
      originalDate: originalDate,
      scope: CalendarEventEditScope.occurrence,
      draft: existing.copyWith(
        startDate: originalDate,
        startMinute: startMinute,
        endMinute: endMinute,
      ),
      operationId: operationId,
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
    required this.weekStartDay,
    required this.onSelected,
    required this.onOpenCalendar,
  });

  final PlannerDate selectedDate;
  final int weekStartDay;
  final ValueChanged<PlannerDate> onSelected;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final offset = (selectedDate.weekday - weekStartDay + 7) % 7;
    final weekStart = selectedDate.addDays(-offset);
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

final class _TimedEventTimeline extends StatefulWidget {
  const _TimedEventTimeline({
    required this.events,
    required this.selectedDate,
    required this.settings,
    required this.onCreate,
    required this.onMove,
    required this.onResize,
  });

  final List<PlannerCalendarItem> events;
  final PlannerDate selectedDate;
  final PlannerSettings settings;
  final ValueChanged<int> onCreate;
  final Future<bool> Function(PlannerCalendarItem event, int startMinute)
  onMove;
  final Future<bool> Function(PlannerCalendarItem event, int endMinute)
  onResize;

  @override
  State<_TimedEventTimeline> createState() => _TimedEventTimelineState();
}

final class _TimedEventTimelineState extends State<_TimedEventTimeline> {
  static const double _hourHeight = 60;
  static const double _timeColumnWidth = 56;
  static const double _eventGap = 3;

  final Map<String, int> _previewStartMinutes = <String, int>{};
  final Map<String, int> _previewEndMinutes = <String, int>{};
  final Set<String> _persisting = <String>{};

  int get _firstHour => widget.settings.visibleStartHour;
  int get _lastHour => widget.settings.visibleEndHour;

  @override
  Widget build(BuildContext context) {
    final slotCount = _lastHour - _firstHour;
    final timelineHeight = slotCount * _hourHeight;
    final placements = PlannerTimelineLayout.arrange(widget.events);
    final now = DateTime.now();
    final showNow =
        widget.settings.showCurrentTime &&
        widget.selectedDate == PlannerDate.fromDateTime(now) &&
        now.hour >= _firstHour &&
        now.hour < _lastHour;
    return SizedBox(
      key: const Key('planner-time-grid'),
      height: timelineHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                left: _timeColumnWidth,
                child: GestureDetector(
                  key: const Key('planner-timeline-create-surface'),
                  behavior: HitTestBehavior.opaque,
                  onLongPressStart: (details) {
                    final minute = snapPlannerMinute(
                      _firstHour * 60 +
                          (details.localPosition.dy / _hourHeight * 60).round(),
                      widget.settings.snapMinutes,
                    ).clamp(_firstHour * 60, _lastHour * 60 - 15);
                    widget.onCreate(minute);
                  },
                ),
              ),
              for (var index = 0; index <= slotCount; index++) ...<Widget>[
                Positioned(
                  top: index * _hourHeight - 7,
                  left: 0,
                  width: _timeColumnWidth - 8,
                  child: Text(
                    _hourLabel(_firstHour + index),
                    textAlign: TextAlign.right,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.white54),
                  ),
                ),
                Positioned(
                  top: index * _hourHeight,
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
              if (widget.events.isEmpty)
                const Positioned(
                  top: 18,
                  left: _timeColumnWidth + 14,
                  right: 8,
                  child: _EmptySectionMessage(
                    'No timed Calendar Events. Long-press the timeline to add '
                    'one.',
                  ),
                ),
              if (showNow)
                _CurrentTimeLine(
                  top:
                      ((now.hour - _firstHour) * 60 + now.minute) *
                      (_hourHeight / 60),
                  left: _timeColumnWidth,
                ),
              for (final placement in placements)
                _positionedEvent(
                  placement,
                  constraints.maxWidth,
                  timelineHeight,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedEvent(
    PlannerTimelinePlacement placement,
    double totalWidth,
    double timelineHeight,
  ) {
    final event = placement.event;
    final originalStart = event.startLocal!;
    final originalEnd = event.endLocal!;
    final originalStartMinute = originalStart.hour * 60 + originalStart.minute;
    final originalEndMinute = originalEnd.hour * 60 + originalEnd.minute;
    final startMinute = _previewStartMinutes[event.id] ?? originalStartMinute;
    final endMinute = _previewEndMinutes[event.id] ?? originalEndMinute;
    final visibleStart = _firstHour * 60;
    final visibleEnd = _lastHour * 60;
    final clippedStart = startMinute.clamp(visibleStart, visibleEnd - 15);
    final clippedEnd = endMinute.clamp(clippedStart + 15, visibleEnd);
    final top = (clippedStart - visibleStart) * (_hourHeight / 60);
    final height = ((clippedEnd - clippedStart) * (_hourHeight / 60))
        .clamp(32, timelineHeight - top)
        .toDouble();
    final availableWidth = totalWidth - _timeColumnWidth - 8;
    final columnWidth =
        (availableWidth - _eventGap * (placement.columnCount - 1)) /
        placement.columnCount;
    final left =
        _timeColumnWidth + 5 + placement.column * (columnWidth + _eventGap);
    return Positioned(
      key: Key('planner-timed-event-${event.id}'),
      top: top,
      left: left,
      width: columnWidth,
      height: height,
      child: _TimelineEventBlock(
        event: event,
        use24HourTime: widget.settings.use24HourTime,
        interactive:
            widget.settings.quickEditEnabled && !_persisting.contains(event.id),
        onMoveUpdate: (deltaPixels) {
          final rawDelta = (deltaPixels / _hourHeight * 60).round();
          final deltaMinutes =
              (rawDelta / widget.settings.snapMinutes).round() *
              widget.settings.snapMinutes;
          final duration = originalEndMinute - originalStartMinute;
          final nextStart = (originalStartMinute + deltaMinutes).clamp(
            visibleStart,
            visibleEnd - duration,
          );
          setState(() {
            _previewStartMinutes[event.id] = nextStart;
            _previewEndMinutes[event.id] = nextStart + duration;
          });
        },
        onMoveEnd: () => _finishMove(event, originalStartMinute),
        onMoveCancel: () => _clearPreview(event.id),
        onResizeUpdate: (deltaPixels) {
          final rawDelta = (deltaPixels / _hourHeight * 60).round();
          final deltaMinutes =
              (rawDelta / widget.settings.snapMinutes).round() *
              widget.settings.snapMinutes;
          final nextEnd = (originalEndMinute + deltaMinutes).clamp(
            originalStartMinute + widget.settings.snapMinutes,
            visibleEnd,
          );
          setState(() => _previewEndMinutes[event.id] = nextEnd);
        },
        onResizeEnd: () => _finishResize(event, originalEndMinute),
        onResizeCancel: () => _clearPreview(event.id),
      ),
    );
  }

  Future<void> _finishMove(
    PlannerCalendarItem event,
    int originalStartMinute,
  ) async {
    final nextStart = _previewStartMinutes[event.id] ?? originalStartMinute;
    if (nextStart == originalStartMinute) {
      _clearPreview(event.id);
      return;
    }
    setState(() => _persisting.add(event.id));
    final saved = await widget.onMove(event, nextStart);
    if (mounted) {
      setState(() {
        _persisting.remove(event.id);
        _previewStartMinutes.remove(event.id);
        _previewEndMinutes.remove(event.id);
      });
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Event time was not changed. The original time is restored.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _finishResize(
    PlannerCalendarItem event,
    int originalEndMinute,
  ) async {
    final nextEnd = _previewEndMinutes[event.id] ?? originalEndMinute;
    if (nextEnd == originalEndMinute) {
      _clearPreview(event.id);
      return;
    }
    setState(() => _persisting.add(event.id));
    final saved = await widget.onResize(event, nextEnd);
    if (mounted) {
      setState(() {
        _persisting.remove(event.id);
        _previewStartMinutes.remove(event.id);
        _previewEndMinutes.remove(event.id);
      });
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Event duration was not changed. The original duration is '
              'restored.',
            ),
          ),
        );
      }
    }
  }

  void _clearPreview(String eventId) {
    setState(() {
      _previewStartMinutes.remove(eventId);
      _previewEndMinutes.remove(eventId);
    });
  }

  String _hourLabel(int hour24) {
    if (widget.settings.use24HourTime) {
      return '${hour24.toString().padLeft(2, '0')}:00';
    }
    final normalized = hour24 % 24;
    final hour = normalized == 0
        ? 12
        : normalized > 12
        ? normalized - 12
        : normalized;
    return '$hour ${normalized >= 12 ? 'PM' : 'AM'}';
  }
}

final class _TimelineEventBlock extends StatelessWidget {
  const _TimelineEventBlock({
    required this.event,
    required this.use24HourTime,
    required this.interactive,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onMoveCancel,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onResizeCancel,
  });

  final PlannerCalendarItem event;
  final bool use24HourTime;
  final bool interactive;
  final ValueChanged<double> onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onMoveCancel;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;
  final VoidCallback onResizeCancel;

  @override
  Widget build(BuildContext context) {
    final color = Color(event.activityTypeColorValue ?? 0xFFE91E63);
    return Semantics(
      button: true,
      label:
          '${event.title}, ${event.activityTypeLabel ?? 'Calendar Event'}, '
          '${_timeRange(event, use24HourTime)}'
          '${event.linkedTaskIds.isEmpty ? '' : ', ${event.linkedTaskIds.length} linked Task(s)'}',
      hint: interactive
          ? 'Tap for details. Long-press and move to change time.'
          : 'Tap for details.',
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPressMoveUpdate: interactive
                  ? (details) => onMoveUpdate(details.offsetFromOrigin.dy)
                  : null,
              onLongPressEnd: interactive ? (_) => onMoveEnd() : null,
              onLongPressCancel: interactive ? onMoveCancel : null,
              child: Material(
                color: color.withValues(alpha: 0.18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: color.withValues(alpha: 0.8)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openCalendarEvent(context, event),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: color, width: 4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 5, 7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (event.isRecurring)
                                const Padding(
                                  padding: EdgeInsets.only(left: 3),
                                  child: Icon(Icons.repeat, size: 13),
                                ),
                              if (event.linkedTaskIds.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Tooltip(
                                    message:
                                        '${event.linkedTaskIds.length} linked Task(s)',
                                    child: const Icon(Icons.link, size: 13),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            _timeRange(event, use24HourTime),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (interactive)
            Positioned(
              key: Key('planner-resize-handle-${event.id}'),
              left: 14,
              right: 14,
              bottom: 0,
              height: 14,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressMoveUpdate: (details) =>
                    onResizeUpdate(details.offsetFromOrigin.dy),
                onLongPressEnd: (_) => onResizeEnd(),
                onLongPressCancel: onResizeCancel,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white60,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _timeRange(PlannerCalendarItem event, bool use24HourTime) {
    return '${_time(event.startLocal, use24HourTime)} – '
        '${_time(event.endLocal, use24HourTime)}';
  }

  static String _time(DateTime? value, bool use24HourTime) {
    if (value == null) {
      return 'Time not set';
    }
    if (use24HourTime) {
      return '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}';
    }
    return _EventTile._time(value);
  }
}

final class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({required this.top, required this.left});

  final double top;
  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const Key('planner-current-time-line'),
      top: top,
      left: left - 4,
      right: 0,
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.rose,
              shape: BoxShape.circle,
            ),
          ),
          const Expanded(
            child: Divider(height: 1, thickness: 1, color: AppTheme.rose),
          ),
        ],
      ),
    );
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
