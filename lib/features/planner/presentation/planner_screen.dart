import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:rmplanner/features/planner/domain/planner_view.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_detail_screen.dart';
import 'package:rmplanner/features/planner/presentation/contextual_create_fab.dart';
import 'package:rmplanner/features/planner/presentation/widgets/anchored_top_bar_popup.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

final class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

final class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final ScrollController _dayScrollController = ScrollController();
  final GlobalKey _dayScrollKey = GlobalKey();
  final GlobalKey _timelineKey = GlobalKey();
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _overflowButtonKey = GlobalKey();
  String? _initialScrollSignature;
  PlannerPresentation? _presentation;
  final Set<PlannerSelectionId> _selectedItems = <PlannerSelectionId>{};
  Future<List<PlannerDay>>? _rangeLoad;
  String? _rangeSignature;
  bool _selectionActive = false;

  bool get _selectionMode => _selectionActive;

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
    _presentation ??= plannerSettings.preferredPresentation;

    return Scaffold(
      appBar: _buildAppBar(context, ref, state, plannerSettings, controller),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            _WeekStrip(
              selectedDate: state.selectedDate,
              weekStartDay: plannerSettings.weekStartDay,
              onSelected: controller.selectDate,
            ),
            Expanded(
              child: _buildContent(context, ref, state, plannerSettings),
            ),
          ],
        ),
      ),
      floatingActionButton: ContextualCreateFab(
        buttonKey: const Key('planner-create-button'),
        destination: CreateActionDestination.planner,
        onSelected: (action) =>
            _handleCreateAction(context, ref, state.selectedDate, action),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    PlannerState state,
    PlannerSettings settings,
    PlannerController controller,
  ) {
    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          key: const Key('planner-selection-cancel'),
          tooltip: 'Cancel selection',
          onPressed: () => setState(() {
            _selectionActive = false;
            _selectedItems.clear();
          }),
          icon: const Icon(Icons.close),
        ),
        title: Text('${_selectedItems.length} selected'),
        actions: <Widget>[
          IconButton(
            key: const Key('planner-selection-delete'),
            tooltip: 'Remove selected items',
            onPressed: _selectedItems.isEmpty
                ? null
                : () => _removeSelected(context, ref, state, settings),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }
    return AppBar(
      leading: Builder(
        builder: (innerContext) => IconButton(
          key: const Key('planner-hamburger'),
          tooltip: 'Open global navigation',
          onPressed: () => Scaffold.of(innerContext).openDrawer(),
          icon: const Icon(Icons.menu),
        ),
      ),
      titleSpacing: 0,
      title: InkWell(
        key: const Key('planner-date-label'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openCalendar(context, controller, state),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            key: const Key('planner-date-label-row'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  _dateLabel(state.selectedDate, _presentation!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                key: Key('planner-date-chevron'),
                size: 18,
                color: AppTheme.rose,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        Semantics(
          label: 'Calendar view active',
          button: false,
          child: ExcludeSemantics(
            child: Container(
              key: const Key('planner-calendar-button'),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: const Icon(
                Icons.calendar_month,
                color: AppTheme.rose,
                size: 22,
              ),
            ),
          ),
        ),
        KeyedSubtree(
          key: const Key('planner-filter-button'),
          child: IconButton(
            key: _filterButtonKey,
            tooltip: 'Filter Planner content',
            onPressed: () => _showFilters(context, ref, settings),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ),
        IconButton(
          key: const Key('planner-selection-button'),
          tooltip: 'Select Events or Tasks',
          onPressed: () => setState(() => _selectionActive = true),
          icon: const Icon(Icons.checklist_outlined),
        ),
        KeyedSubtree(
          key: const Key('planner-overflow-button'),
          child: IconButton(
            key: _overflowButtonKey,
            tooltip: 'Planner menu',
            onPressed: () => _showOverflowMenu(context, ref, state, settings),
            icon: const Icon(Icons.more_vert),
          ),
        ),
      ],
    );
  }

  Future<void> _showOverflowMenu(
    BuildContext context,
    WidgetRef ref,
    PlannerState state,
    PlannerSettings settings,
  ) async {
    await showAnchoredTopBarPopup(
      context: context,
      triggerKey: _overflowButtonKey,
      width: 240,
      maxHeight: 320,
      builder: (popupContext) {
        return Column(
          key: const Key('planner-overflow-menu'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final entry in <_OverflowEntry>[
              _OverflowEntry(
                action: _PlannerOverflowAction.search,
                label: 'Search',
                icon: Icons.search,
              ),
              _OverflowEntry(
                action: _PlannerOverflowAction.schedule,
                label: 'Schedule',
                icon: Icons.view_agenda_outlined,
                selected: _presentation == PlannerPresentation.schedule,
              ),
              _OverflowEntry(
                action: _PlannerOverflowAction.day,
                label: 'Day',
                icon: Icons.calendar_view_day_outlined,
                selected: _presentation == PlannerPresentation.day,
              ),
              _OverflowEntry(
                action: _PlannerOverflowAction.week,
                label: 'Week',
                icon: Icons.calendar_view_week_outlined,
                selected: _presentation == PlannerPresentation.week,
              ),
              _OverflowEntry(
                action: _PlannerOverflowAction.tasks,
                label: 'Tasks',
                icon: Icons.task_alt_outlined,
                selected: _presentation == PlannerPresentation.tasks,
              ),
            ])
              _OverflowPopupRow(
                entry: entry,
                onTap: () async {
                  anchoredTopBarPopupController.dismiss();
                  await _handleOverflow(
                    context,
                    ref,
                    state,
                    settings,
                    entry.action,
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _showFilters(
    BuildContext context,
    WidgetRef ref,
    PlannerSettings settings,
  ) async {
    var filters = settings.contentFilters;
    await showAnchoredTopBarPopup(
      context: context,
      triggerKey: _filterButtonKey,
      width: 300,
      maxHeight: 380,
      builder: (popupContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                key: const Key('planner-filter-menu'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'Show in Planner',
                      style: Theme.of(innerContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('planner-filter-events'),
                    title: const Text('Events'),
                    value: filters.events,
                    onChanged: (value) => setSheetState(
                      () => filters = filters.copyWith(events: value),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('planner-filter-backup-events'),
                    title: const Text('Backup Events'),
                    value: filters.backupEvents,
                    onChanged: (value) => setSheetState(
                      () => filters = filters.copyWith(backupEvents: value),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('planner-filter-tasks'),
                    title: const Text('Tasks'),
                    value: filters.tasks,
                    onChanged: (value) => setSheetState(
                      () => filters = filters.copyWith(tasks: value),
                    ),
                  ),
                  CheckboxListTile(
                    key: const Key('planner-filter-completed-tasks'),
                    title: const Text('Completed Tasks'),
                    value: filters.completedTasks,
                    onChanged: filters.tasks
                        ? (value) => setSheetState(
                            () => filters = filters.copyWith(
                              completedTasks: value,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: TextButton(
                            onPressed: () => setSheetState(
                              () => filters =
                                  const PlannerContentFilters.defaults(),
                            ),
                            child: const Text(
                              'Restore defaults',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('planner-filter-apply'),
                          onPressed: () async {
                            anchoredTopBarPopupController.dismiss();
                            if (!mounted ||
                                filters == settings.contentFilters) {
                              return;
                            }
                            await ref
                                .read(eventTypeControllerProvider.notifier)
                                .saveSettings(
                                  settings.copyWith(contentFilters: filters),
                                );
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) {
      return;
    }
  }

  Future<void> _handleOverflow(
    BuildContext context,
    WidgetRef ref,
    PlannerState state,
    PlannerSettings settings,
    _PlannerOverflowAction action,
  ) async {
    if (action == _PlannerOverflowAction.search) {
      final day = state.day;
      if (day != null) {
        await showSearch<void>(
          context: context,
          delegate: _PlannerSearchDelegate(day: day),
        );
      }
      return;
    }
    final presentation = switch (action) {
      _PlannerOverflowAction.schedule => PlannerPresentation.schedule,
      _PlannerOverflowAction.day => PlannerPresentation.day,
      _PlannerOverflowAction.week => PlannerPresentation.week,
      _PlannerOverflowAction.tasks => PlannerPresentation.tasks,
      _PlannerOverflowAction.search => settings.preferredPresentation,
    };
    await _setPresentation(ref, settings, presentation);
  }

  Future<void> _setPresentation(
    WidgetRef ref,
    PlannerSettings settings,
    PlannerPresentation presentation,
  ) async {
    setState(() {
      _presentation = presentation;
      _selectionActive = false;
      _selectedItems.clear();
    });
    await ref
        .read(eventTypeControllerProvider.notifier)
        .saveSettings(settings.copyWith(preferredPresentation: presentation));
  }

  void _handleCreateAction(
    BuildContext context,
    WidgetRef ref,
    PlannerDate selectedDate,
    ContextualCreateAction action,
  ) {
    switch (action) {
      case ContextualCreateAction.event:
        unawaited(
          launchCalendarEventCreation<void>(
            context,
            ref,
            CalendarEventCreationContext(
              source: 'planner-fab',
              destinationPath: RoutePaths.calendarEventCreate,
              date: selectedDate,
            ),
          ),
        );
        return;
      case ContextualCreateAction.task:
        unawaited(
          context.push('${RoutePaths.taskCreate}?date=${selectedDate.iso8601}'),
        );
        return;
      case ContextualCreateAction.person:
      case ContextualCreateAction.contact:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${action.label} remains distinct and will open when the '
              'authorized Contacts slice is implemented.',
            ),
          ),
        );
        return;
    }
  }

  static String _dateLabel(PlannerDate date, PlannerPresentation presentation) {
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
    if (presentation == PlannerPresentation.week) {
      final start = date.addDays(-(date.weekday - DateTime.monday));
      final end = start.addDays(6);
      return '${months[start.month - 1]} ${start.day}–'
          '${months[end.month - 1]} ${end.day}';
    }
    return '${months[date.month - 1]} ${date.day}';
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
    if (_presentation != PlannerPresentation.day) {
      return _buildAlternatePresentation(context, ref, state, settings, day);
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
              Container(
                key: _timelineKey,
                child: KeyedSubtree(
                  key: const Key('timed-events-section'),
                  child: _TimedEventTimeline(
                    events: _visibleEvents(day.timedEvents, settings)
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
                    onCreate: (minute) => _createTimedEvent(
                      context,
                      ref,
                      state.selectedDate,
                      minute,
                    ),
                    onMove: (event, startMinute) =>
                        _moveEvent(ref, event, startMinute),
                    onResize: (event, endMinute) =>
                        _resizeEvent(ref, event, endMinute),
                    selectionMode: _selectionMode,
                    selectedItems: _selectedItems,
                    onToggleSelection: _toggleEventSelection,
                    hourHeight: settings.timelineHourHeight,
                    onZoomEnd: (value) => _persistZoom(ref, settings, value),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlternatePresentation(
    BuildContext context,
    WidgetRef ref,
    PlannerState state,
    PlannerSettings settings,
    PlannerDay selectedDay,
  ) {
    final presentation = _presentation!;
    final dates = _weekDates(state.selectedDate, settings.weekStartDay);
    final signature =
        '${dates.first.iso8601}:${settings.contentFilters.hashCode}:'
        '${_dayContentSignature(selectedDay)}';
    if (_rangeSignature != signature) {
      _rangeSignature = signature;
      _rangeLoad = ref.read(plannerControllerProvider.notifier).readDays(dates);
    }
    return FutureBuilder<List<PlannerDay>>(
      future: _rangeLoad,
      builder: (context, snapshot) {
        final days = snapshot.data ?? <PlannerDay>[selectedDay];
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return switch (presentation) {
          PlannerPresentation.schedule => _SchedulePresentation(
            days: days,
            settings: settings,
            selectionMode: _selectionMode,
            selectedItems: _selectedItems,
            onToggleEvent: _toggleEventSelection,
            onToggleTask: _toggleTaskSelection,
          ),
          PlannerPresentation.week => _WeekPresentation(
            days: days,
            settings: settings,
            onSelected: (date) =>
                ref.read(plannerControllerProvider.notifier).selectDate(date),
          ),
          PlannerPresentation.tasks => _TasksPresentation(
            days: days,
            settings: settings,
            selectionMode: _selectionMode,
            selectedItems: _selectedItems,
            onToggleTask: _toggleTaskSelection,
          ),
          PlannerPresentation.awaitingReports => _AwaitingPresentation(
            days: days,
            settings: settings,
            selectionMode: _selectionMode,
            selectedItems: _selectedItems,
            onToggleEvent: _toggleEventSelection,
          ),
          PlannerPresentation.day => const SizedBox.shrink(),
        };
      },
    );
  }

  List<PlannerCalendarItem> _visibleEvents(
    List<PlannerCalendarItem> events,
    PlannerSettings settings,
  ) {
    final filters = settings.contentFilters;
    return events
        .where(
          (event) =>
              event.isBackupAppointment ? filters.backupEvents : filters.events,
        )
        .toList(growable: false);
  }

  static List<PlannerDate> _weekDates(PlannerDate date, int weekStartDay) {
    final offset = (date.weekday - weekStartDay + 7) % 7;
    final start = date.addDays(-offset);
    return List<PlannerDate>.generate(7, start.addDays);
  }

  static String _dayContentSignature(PlannerDay day) {
    return <String>[
      for (final event in <PlannerCalendarItem>[
        ...day.allDayEvents,
        ...day.timedEvents,
      ])
        '${event.id}:${event.state.name}:${event.hasOutcomeReport}',
      for (final task in <PlannerTask>[
        ...day.overdueTasks,
        ...day.tasks,
        ...day.completedTasks,
      ])
        '${task.id}:${task.status.name}',
    ].join('|');
  }

  void _toggleEventSelection(PlannerCalendarItem event) {
    setState(() {
      final selection = PlannerSelectionId(
        kind: PlannerSelectionKind.event,
        id: event.id,
      );
      _selectedItems.contains(selection)
          ? _selectedItems.remove(selection)
          : _selectedItems.add(selection);
    });
  }

  void _toggleTaskSelection(PlannerTask task) {
    setState(() {
      final selection = PlannerSelectionId(
        kind: PlannerSelectionKind.task,
        id: task.id,
      );
      _selectedItems.contains(selection)
          ? _selectedItems.remove(selection)
          : _selectedItems.add(selection);
    });
  }

  Future<void> _persistZoom(
    WidgetRef ref,
    PlannerSettings settings,
    double hourHeight,
  ) async {
    await ref
        .read(eventTypeControllerProvider.notifier)
        .saveSettings(
          settings.copyWith(
            timelineHourHeight: PlannerZoomPolicy.clamp(hourHeight),
          ),
        );
  }

  Future<void> _removeSelected(
    BuildContext context,
    WidgetRef ref,
    PlannerState state,
    PlannerSettings settings,
  ) async {
    final count = _selectedItems.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $count selected item${count == 1 ? '' : 's'}?'),
        content: const Text(
          'Events are cancelled and Tasks are cancelled independently. '
          'Links, reports, provenance, and the related record are preserved.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep items'),
          ),
          FilledButton(
            key: const Key('planner-confirm-selection-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final days = await ref
        .read(plannerControllerProvider.notifier)
        .readDays(_weekDates(state.selectedDate, settings.weekStartDay));
    final events = <String, PlannerCalendarItem>{
      for (final day in days)
        for (final event in <PlannerCalendarItem>[
          ...day.allDayEvents,
          ...day.timedEvents,
        ])
          event.id: event,
    };
    final tasks = <String, PlannerTask>{
      for (final day in days)
        for (final task in <PlannerTask>[
          ...day.tasks,
          ...day.overdueTasks,
          ...day.completedTasks,
        ])
          task.id: task,
    };
    var failed = 0;
    for (final selected in _selectedItems.toList(growable: false)) {
      switch (selected.kind) {
        case PlannerSelectionKind.event:
          final event = events[selected.id];
          if (event?.eventId == null || event?.originalDate == null) {
            failed += 1;
            continue;
          }
          final success = await ref
              .read(calendarEventControllerProvider.notifier)
              .cancelEvent(
                eventId: event!.eventId!,
                originalDate: event.originalDate!,
                scope: CalendarEventEditScope.occurrence,
                operationId: ref
                    .read(plannerIdentifierSourceProvider)
                    .nextUuid(),
              );
          if (!success) {
            failed += 1;
          }
          break;
        case PlannerSelectionKind.task:
          final task = tasks[selected.id];
          if (task == null) {
            failed += 1;
            continue;
          }
          final outcome = await ref
              .read(plannerControllerProvider.notifier)
              .changeStatus(
                taskId: task.id,
                target: PlannerTaskStatus.cancelled,
                operationId: ref
                    .read(plannerIdentifierSourceProvider)
                    .nextUuid(),
                reason: 'Removed from Planner selection mode',
              );
          if (outcome != TaskStatusChangeOutcome.changed &&
              outcome != TaskStatusChangeOutcome.unchanged) {
            failed += 1;
          }
          break;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionActive = false;
      _selectedItems.clear();
      _rangeSignature = null;
    });
    await ref
        .read(plannerControllerProvider.notifier)
        .selectDate(state.selectedDate);
    if (failed > 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$failed item${failed == 1 ? '' : 's'} could not be removed. '
            'Protected history was left unchanged.',
          ),
        ),
      );
    }
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
    WidgetRef ref,
    PlannerDate selectedDate,
    int startMinute,
  ) {
    unawaited(
      launchCalendarEventCreation<void>(
        context,
        ref,
        CalendarEventCreationContext(
          source: 'planner-timeline',
          destinationPath: RoutePaths.calendarEventCreate,
          date: selectedDate,
          startMinute: startMinute,
        ),
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
}

enum _PlannerOverflowAction { search, schedule, day, week, tasks }

/// Internal descriptor for a row inside the top-bar overflow popup.
final class _OverflowEntry {
  const _OverflowEntry({
    required this.action,
    required this.label,
    required this.icon,
    this.selected = false,
  });

  final _PlannerOverflowAction action;
  final String label;
  final IconData icon;
  final bool selected;
}

/// Single row in the anchored top-bar overflow popup.
class _OverflowPopupRow extends StatelessWidget {
  const _OverflowPopupRow({required this.entry, required this.onTap});

  final _OverflowEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = entry.selected;
    return InkWell(
      key: Key('planner-overflow-${entry.action.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(
              isSelected ? Icons.check : entry.icon,
              size: 20,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDate,
    required this.weekStartDay,
    required this.onSelected,
  });

  final PlannerDate selectedDate;
  final int weekStartDay;
  final ValueChanged<PlannerDate> onSelected;

  @override
  Widget build(BuildContext context) {
    final offset = (selectedDate.weekday - weekStartDay + 7) % 7;
    final weekStart = selectedDate.addDays(-offset);
    return Container(
      key: const Key('planner-week-strip'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        key: const Key('planner-week-strip-row'),
        children: <Widget>[
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

final class _TimedEventTimeline extends StatefulWidget {
  const _TimedEventTimeline({
    required this.events,
    required this.selectedDate,
    required this.settings,
    required this.onCreate,
    required this.onMove,
    required this.onResize,
    required this.selectionMode,
    required this.selectedItems,
    required this.onToggleSelection,
    required this.hourHeight,
    required this.onZoomEnd,
  });

  final List<PlannerCalendarItem> events;
  final PlannerDate selectedDate;
  final PlannerSettings settings;
  final ValueChanged<int> onCreate;
  final Future<bool> Function(PlannerCalendarItem event, int startMinute)
  onMove;
  final Future<bool> Function(PlannerCalendarItem event, int endMinute)
  onResize;
  final bool selectionMode;
  final Set<PlannerSelectionId> selectedItems;
  final ValueChanged<PlannerCalendarItem> onToggleSelection;
  final double hourHeight;
  final ValueChanged<double> onZoomEnd;

  @override
  State<_TimedEventTimeline> createState() => _TimedEventTimelineState();
}

final class _TimedEventTimelineState extends State<_TimedEventTimeline> {
  static const double _timeColumnWidth = 56;
  static const double _eventGap = 3;

  final Map<String, int> _previewStartMinutes = <String, int>{};
  final Map<String, int> _previewEndMinutes = <String, int>{};
  final Set<String> _persisting = <String>{};
  late double _hourHeight;
  double? _zoomStartHeight;

  @override
  void initState() {
    super.initState();
    _hourHeight = PlannerZoomPolicy.clamp(widget.hourHeight);
  }

  @override
  void didUpdateWidget(covariant _TimedEventTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_zoomStartHeight == null && oldWidget.hourHeight != widget.hourHeight) {
      _hourHeight = PlannerZoomPolicy.clamp(widget.hourHeight);
    }
  }

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
    return GestureDetector(
      key: const Key('planner-zoom-surface'),
      behavior: HitTestBehavior.translucent,
      onScaleStart: (details) {
        if (details.pointerCount >= 2) {
          _zoomStartHeight = _hourHeight;
        }
      },
      onScaleUpdate: (details) {
        final start = _zoomStartHeight;
        if (start == null || details.pointerCount < 2) {
          return;
        }
        setState(
          () => _hourHeight = PlannerZoomPolicy.clamp(start * details.scale),
        );
      },
      onScaleEnd: (_) {
        if (_zoomStartHeight != null) {
          _zoomStartHeight = null;
          widget.onZoomEnd(_hourHeight);
        }
      },
      child: SizedBox(
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
                    onTapUp: (details) {
                      final minute = snapPlannerMinute(
                        _firstHour * 60 +
                            (details.localPosition.dy / _hourHeight * 60)
                                .round(),
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
                      'No timed Calendar Events. Tap the timeline to add one.',
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
        displayStartMinute: startMinute,
        displayEndMinute: endMinute,
        awaitingReport: event.isAwaitingReport(DateTime.now()),
        selectionMode: widget.selectionMode,
        selected: widget.selectedItems.contains(
          PlannerSelectionId(kind: PlannerSelectionKind.event, id: event.id),
        ),
        onToggleSelection: () => widget.onToggleSelection(event),
        interactive:
            !widget.selectionMode &&
            widget.settings.quickEditEnabled &&
            !_persisting.contains(event.id),
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
    required this.displayStartMinute,
    required this.displayEndMinute,
    required this.awaitingReport,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelection,
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
  final int displayStartMinute;
  final int displayEndMinute;
  final bool awaitingReport;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelection;
  final bool interactive;
  final ValueChanged<double> onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onMoveCancel;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;
  final VoidCallback onResizeCancel;

  @override
  Widget build(BuildContext context) {
    final base = Color(event.activityTypeColorValue ?? 0xFFE91E63);
    final fill = PlannerEventBlockColorPolicy.surfaceColor(base);
    final border = PlannerEventBlockColorPolicy.borderColor(base);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : PlannerEventBlockLayoutPolicy.mediumThreshold + 1;
        final content = PlannerEventBlockContent.forHeight(
          availableHeight,
          interactive: interactive,
        );
        return Semantics(
          button: true,
          label:
              '${event.title}, ${event.activityTypeLabel ?? 'Calendar Event'}, '
              '${_minuteRange(displayStartMinute, displayEndMinute, use24HourTime)}'
              '${event.isBackupAppointment ? ', Backup Appointment' : ''}'
              '${awaitingReport ? ', Awaiting Report' : ''}'
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
                  onLongPressStart: interactive
                      ? (_) => unawaited(HapticFeedback.mediumImpact())
                      : null,
                  onLongPressEnd: interactive ? (_) => onMoveEnd() : null,
                  onLongPressCancel: interactive ? onMoveCancel : null,
                  child: Material(
                    color: fill,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: selectionMode
                          ? onToggleSelection
                          : () => _openCalendarEvent(context, event),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: event.isBackupAppointment
                                  ? Colors.black
                                  : border,
                              width: event.isBackupAppointment ? 7 : 4,
                            ),
                          ),
                        ),
                        child: _EventBlockContent(
                          event: event,
                          use24HourTime: use24HourTime,
                          displayStartMinute: displayStartMinute,
                          displayEndMinute: displayEndMinute,
                          awaitingReport: awaitingReport,
                          content: content,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (content.showResizeHandle)
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
              if (selectionMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    selected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: selected ? AppTheme.rose : Colors.white,
                    size: 20,
                  ),
                ),
              if (awaitingReport &&
                  PlannerEventBlockLayoutPolicy.classify(availableHeight) ==
                      Density.tall)
                const Positioned(
                  left: 8,
                  bottom: 2,
                  child: Text(
                    'Awaiting Report',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _minuteRange(int start, int end, bool use24HourTime) {
    return '${_minute(start, use24HourTime)} – '
        '${_minute(end, use24HourTime)}';
  }

  static String _minute(int value, bool use24HourTime) {
    final hour = value ~/ 60;
    final minute = value % 60;
    if (use24HourTime) {
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:${minute.toString().padLeft(2, '0')} '
        '${hour >= 12 ? 'PM' : 'AM'}';
  }
}

/// Inner content of a Calendar Event timeline block.
///
/// Adapts to the available height by selecting how much of the title,
/// time, and status rows to render. The widget never forces a minimum
/// content height larger than the block, so it cannot produce a
/// RenderFlex overflow on short blocks.
final class _EventBlockContent extends StatelessWidget {
  const _EventBlockContent({
    required this.event,
    required this.use24HourTime,
    required this.displayStartMinute,
    required this.displayEndMinute,
    required this.awaitingReport,
    required this.content,
  });

  final PlannerCalendarItem event;
  final bool use24HourTime;
  final int displayStartMinute;
  final int displayEndMinute;
  final bool awaitingReport;
  final PlannerEventBlockContent content;

  @override
  Widget build(BuildContext context) {
    final density = content.density;
    final textColor = PlannerEventBlockColorPolicy.textColor(
      Color(event.activityTypeColorValue ?? 0xFFE91E63),
    );
    final titleStyle = TextStyle(
      color: textColor,
      fontWeight: FontWeight.w700,
      fontSize: density == Density.veryShort ? 11 : 12,
      height: 1.1,
    );
    final timeStyle = TextStyle(
      color: textColor.withValues(alpha: 0.92),
      fontWeight: FontWeight.w600,
      fontSize: density == Density.tall ? 11 : 10,
      height: 1.1,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Column(
        key: const Key('planner-event-block-content'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            event.title,
            style: titleStyle,
            maxLines: content.titleMaxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          if (content.showTime)
            Padding(
              padding: EdgeInsets.only(top: density == Density.tall ? 2 : 1),
              child: Text(
                _formatRange(
                  displayStartMinute,
                  displayEndMinute,
                  use24HourTime,
                ),
                style: timeStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          if (content.showStatusIcons)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _StatusRow(
                textColor: textColor,
                isBackup: event.isBackupAppointment,
                awaitingReport: awaitingReport,
                linkedTaskCount: event.linkedTaskIds.length,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatRange(
    int start,
    int end,
    bool use24HourTime,
  ) {
    final startText = _minute(start, use24HourTime);
    final endText = _minute(end, use24HourTime);
    return '$startText - $endText';
  }

  static String _minute(int value, bool use24HourTime) {
    final hour = value ~/ 60;
    final minute = value % 60;
    if (use24HourTime) {
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    }
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:${minute.toString().padLeft(2, '0')} '
        '${hour >= 12 ? 'PM' : 'AM'}';
  }
}

/// Compact status row inside an Event block.
///
/// Renders at most one icon-and-text pair that summarises the Event's
/// most relevant status. Order of preference: Awaiting Report > Backup >
/// linked Task count.
final class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.textColor,
    required this.isBackup,
    required this.awaitingReport,
    required this.linkedTaskCount,
  });

  final Color textColor;
  final bool isBackup;
  final bool awaitingReport;
  final int linkedTaskCount;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    if (awaitingReport) {
      icon = Icons.assignment_late_outlined;
      label = 'Awaiting Report';
    } else if (isBackup) {
      icon = Icons.layers_outlined;
      label = 'Backup';
    } else if (linkedTaskCount > 0) {
      icon = Icons.task_alt_outlined;
      label = '$linkedTaskCount linked';
    } else {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: textColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
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
  const _TaskTile({
    required this.task,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelection,
  });

  final PlannerTask task;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelection;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        key: Key('planner-task-${task.id}'),
        leading: selectionMode
            ? Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? AppTheme.rose : Colors.white70,
              )
            : const Icon(Icons.task_alt_outlined, color: AppTheme.rose),
        title: Text(task.title),
        subtitle: Text(_taskSubtitle(task)),
        trailing: const Icon(Icons.chevron_right),
        onTap: selectionMode
            ? onToggleSelection
            : () => context.push('${RoutePaths.tasks}/${task.id}'),
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
  const _EventTile({
    required this.event,
    this.awaitingReport = false,
    this.selectionMode = false,
    this.selected = false,
    this.onToggleSelection,
  });

  final PlannerCalendarItem event;
  final bool awaitingReport;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onToggleSelection;

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
      if (event.isBackupAppointment) 'Backup Appointment',
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: event.isBackupAppointment
              ? const Border(left: BorderSide(color: Colors.black, width: 7))
              : null,
        ),
        child: ListTile(
          key: Key('planner-event-${event.id}'),
          leading: selectionMode
              ? Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  color: selected ? AppTheme.rose : Colors.white70,
                )
              : Icon(
                  awaitingReport
                      ? Icons.assignment_late_outlined
                      : event.timing == PlannerEventTiming.allDay
                      ? Icons.event_available_outlined
                      : Icons.schedule,
                  color: awaitingReport
                      ? AppTheme.warning
                      : AppTheme.eventAccent,
                ),
          title: Row(
            children: <Widget>[
              Flexible(child: Text(event.title)),
              if (event.isRecurring) ...const <Widget>[
                SizedBox(width: 6),
                Icon(Icons.repeat, size: 16),
              ],
              if (event.isBackupAppointment) ...const <Widget>[
                SizedBox(width: 6),
                Icon(Icons.layers_outlined, size: 16),
              ],
            ],
          ),
          subtitle: Text(detail),
          trailing: selectionMode
              ? null
              : event.locationText == null
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
          onTap: selectionMode
              ? onToggleSelection
              : () => _openCalendarEvent(context, event),
        ),
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

final class _SchedulePresentation extends StatelessWidget {
  const _SchedulePresentation({
    required this.days,
    required this.settings,
    required this.selectionMode,
    required this.selectedItems,
    required this.onToggleEvent,
    required this.onToggleTask,
  });

  final List<PlannerDay> days;
  final PlannerSettings settings;
  final bool selectionMode;
  final Set<PlannerSelectionId> selectedItems;
  final ValueChanged<PlannerCalendarItem> onToggleEvent;
  final ValueChanged<PlannerTask> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final filters = settings.contentFilters;
    return ListView(
      key: const Key('planner-schedule-view'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: <Widget>[
        for (final day in days) ...<Widget>[
          Text(
            day.selectedDate.iso8601,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final event in <PlannerCalendarItem>[
            ...day.allDayEvents,
            ...day.timedEvents,
          ])
            if (event.isBackupAppointment
                ? filters.backupEvents
                : filters.events)
              _EventTile(
                event: event,
                awaitingReport: event.isAwaitingReport(DateTime.now()),
                selectionMode: selectionMode,
                selected: selectedItems.contains(
                  PlannerSelectionId(
                    kind: PlannerSelectionKind.event,
                    id: event.id,
                  ),
                ),
                onToggleSelection: () => onToggleEvent(event),
              ),
          if (filters.tasks)
            for (final task in <PlannerTask>[
              ...day.overdueTasks,
              ...day.tasks,
              if (filters.completedTasks) ...day.completedTasks,
            ])
              _TaskTile(
                task: task,
                selectionMode: selectionMode,
                selected: selectedItems.contains(
                  PlannerSelectionId(
                    kind: PlannerSelectionKind.task,
                    id: task.id,
                  ),
                ),
                onToggleSelection: () => onToggleTask(task),
              ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

final class _WeekPresentation extends StatelessWidget {
  const _WeekPresentation({
    required this.days,
    required this.settings,
    required this.onSelected,
  });

  final List<PlannerDay> days;
  final PlannerSettings settings;
  final ValueChanged<PlannerDate> onSelected;

  @override
  Widget build(BuildContext context) {
    final filters = settings.contentFilters;
    return ListView(
      key: const Key('planner-week-view'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: <Widget>[
        for (final day in days)
          Card(
            child: InkWell(
              onTap: () => onSelected(day.selectedDate),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 76,
                      child: Text(
                        day.selectedDate.iso8601,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final event in <PlannerCalendarItem>[
                            ...day.allDayEvents,
                            ...day.timedEvents,
                          ])
                            if (event.isBackupAppointment
                                ? filters.backupEvents
                                : filters.events)
                              Chip(
                                key: Key('planner-week-event-${event.id}'),
                                avatar: Icon(
                                  event.isBackupAppointment
                                      ? Icons.layers_outlined
                                      : event.isAwaitingReport(DateTime.now())
                                      ? Icons.assignment_late_outlined
                                      : Icons.event_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  event.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          if (filters.tasks)
                            for (final task in day.tasks)
                              Chip(
                                avatar: const Icon(
                                  Icons.task_alt_outlined,
                                  size: 16,
                                ),
                                label: Text(task.title),
                              ),
                          if (<Object>[
                            ...day.allDayEvents,
                            ...day.timedEvents,
                            ...day.tasks,
                          ].isEmpty)
                            const Text(
                              'No visible items',
                              style: TextStyle(color: Colors.white54),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final class _TasksPresentation extends StatelessWidget {
  const _TasksPresentation({
    required this.days,
    required this.settings,
    required this.selectionMode,
    required this.selectedItems,
    required this.onToggleTask,
  });

  final List<PlannerDay> days;
  final PlannerSettings settings;
  final bool selectionMode;
  final Set<PlannerSelectionId> selectedItems;
  final ValueChanged<PlannerTask> onToggleTask;

  @override
  Widget build(BuildContext context) {
    final incomplete = <String, PlannerTask>{
      for (final day in days)
        for (final task in <PlannerTask>[...day.overdueTasks, ...day.tasks])
          task.id: task,
    }.values.toList(growable: false);
    final completed = <String, PlannerTask>{
      for (final day in days)
        for (final task in day.completedTasks) task.id: task,
    }.values.toList(growable: false);
    return ListView(
      key: const Key('planner-tasks-view'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: <Widget>[
        const _ViewHeading('Incomplete'),
        for (final task in incomplete) _taskTile(task),
        const SizedBox(height: 18),
        const _ViewHeading('Completed'),
        if (!settings.contentFilters.tasks ||
            !settings.contentFilters.completedTasks)
          const _EmptySectionMessage(
            'Enable Tasks and Completed Tasks in Filter to show completed '
            'items.',
          )
        else
          for (final task in completed) _taskTile(task),
      ],
    );
  }

  Widget _taskTile(PlannerTask task) {
    return _TaskTile(
      task: task,
      selectionMode: selectionMode,
      selected: selectedItems.contains(
        PlannerSelectionId(kind: PlannerSelectionKind.task, id: task.id),
      ),
      onToggleSelection: () => onToggleTask(task),
    );
  }
}

final class _AwaitingPresentation extends StatelessWidget {
  const _AwaitingPresentation({
    required this.days,
    required this.settings,
    required this.selectionMode,
    required this.selectedItems,
    required this.onToggleEvent,
  });

  final List<PlannerDay> days;
  final PlannerSettings settings;
  final bool selectionMode;
  final Set<PlannerSelectionId> selectedItems;
  final ValueChanged<PlannerCalendarItem> onToggleEvent;

  @override
  Widget build(BuildContext context) {
    final events =
        <String, PlannerCalendarItem>{
              for (final day in days)
                for (final event in day.awaitingReportEvents) event.id: event,
            }.values
            .where((event) {
              return event.isBackupAppointment
                  ? settings.contentFilters.backupEvents
                  : settings.contentFilters.events;
            })
            .toList(growable: false);
    return ListView(
      key: const Key('planner-awaiting-reports-view'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: <Widget>[
        const _ViewHeading('Awaiting Reports'),
        if (events.isEmpty)
          const _EmptySectionMessage('No qualifying reports are pending.')
        else
          for (final event in events)
            _EventTile(
              event: event,
              awaitingReport: true,
              selectionMode: selectionMode,
              selected: selectedItems.contains(
                PlannerSelectionId(
                  kind: PlannerSelectionKind.event,
                  id: event.id,
                ),
              ),
              onToggleSelection: () => onToggleEvent(event),
            ),
      ],
    );
  }
}

final class _ViewHeading extends StatelessWidget {
  const _ViewHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

final class _PlannerSearchDelegate extends SearchDelegate<void> {
  _PlannerSearchDelegate({required this.day});

  final PlannerDay day;

  @override
  String get searchFieldLabel => 'Search Planner';

  @override
  List<Widget> buildActions(BuildContext context) => <Widget>[
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Clear search',
        onPressed: () => query = '',
        icon: const Icon(Icons.clear),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Close search',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final events =
        <PlannerCalendarItem>[...day.allDayEvents, ...day.timedEvents].where(
          (event) =>
              normalized.isEmpty ||
              <String?>[
                event.title,
                event.locationText,
                event.activityTypeLabel,
              ].whereType<String>().any(
                (value) => value.toLowerCase().contains(normalized),
              ),
        );
    final tasks =
        <PlannerTask>[
          ...day.overdueTasks,
          ...day.tasks,
          ...day.completedTasks,
        ].where(
          (task) =>
              normalized.isEmpty ||
              <String?>[task.title, task.notes].whereType<String>().any(
                (value) => value.toLowerCase().contains(normalized),
              ),
        );
    return ListView(
      children: <Widget>[
        for (final event in events) _EventTile(event: event),
        for (final task in tasks) _TaskTile(task: task),
      ],
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
    showCalendarEventDetailSheet<void>(
      context: context,
      eventId: eventId,
      originalDate: originalDate,
    ),
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
