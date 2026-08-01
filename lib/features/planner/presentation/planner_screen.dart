import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
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
import 'package:rmplanner/features/planner/presentation/widgets/planner_calendar_icon.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_date_strip.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_interactive_day_pager.dart'
    show PlannerInteractiveDayPager, PlannerInteractiveDayPagerController;
import 'package:rmplanner/features/planner/presentation/widgets/planner_slide_down_date_picker.dart';

final class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key, this.currentTimeListenable});

  /// Optional current-time source used by the exact current-time
  /// indicator. When omitted, the screen owns a [ValueNotifier] of
  /// [DateTime] seeded from `DateTime.now()` and refreshed by an
  /// internal minute-boundary [Timer] (production behavior).
  /// When provided, the screen reads this listenable directly and
  /// does not create its own notifier, timer, or ticker — the
  /// caller (typically a focused widget test) owns the listenable
  /// and is responsible for advancing it. Production code paths
  /// never pass this argument.
  final ValueListenable<DateTime>? currentTimeListenable;

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

final class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  final ScrollController _dayScrollController = ScrollController();
  final GlobalKey _dayScrollKey = GlobalKey();
  final GlobalKey _timelineKey = GlobalKey();
  final GlobalKey _filterButtonKey = GlobalKey();
  final GlobalKey _overflowButtonKey = GlobalKey();
  // External command surface owned by the screen for the
  // lifetime of the Planner route. The interactive day pager
  // attaches itself to this controller in its
  // [State.initState] and detaches itself in
  // [State.dispose]. The screen's `_DaySwipeCoordinator`
  // cancel listener invokes
  // [PlannerInteractiveDayPagerController.recenterFromExternalCancel]
  // so a competing recognizer (long-press move, vertical
  // drag, pinch scale) tears the pager back to the centered
  // resting position. The previous `GlobalKey<State>` design
  // is removed: this typed controller is the only public
  // command surface, and the pager's private State class is
  // not exposed across files.
  final PlannerInteractiveDayPagerController _pagerController =
      PlannerInteractiveDayPagerController();
  String? _initialScrollSignature;
  bool _initialScrollPerformed = false;
  PlannerPresentation? _presentation;
  final Set<PlannerSelectionId> _selectedItems = <PlannerSelectionId>{};
  Future<List<PlannerDay>>? _rangeLoad;
  String? _rangeSignature;
  // Cached three-day read-only preview future for the
  // interactive pager. The cached future is rebuilt only
  // when the preview signature changes. The signature is
  // composed of:
  //   * the selected ISO date;
  //   * a per-build data revision counter that bumps every
  //     time the planner state is rebuilt (so any path that
  //     re-reads `state.day` — including a normal
  //     `refresh()` call after an adjacent-day mutation —
  //     invalidates the cache);
  //   * the resolved previous/next PlannerDay content
  //     signatures, captured the most recent time the
  //     preview trio completed (so a subsequent adjacent
  //     mutation refetches the preview the very next build
  //     after the data revision bumped);
  //   * the relevant settings that affect preview
  //     rendering (visible hour window, hour height,
  //     use-24-hour time, show-current-time, show-cancelled,
  //     content filters).
  //
  // The previous/next content signatures are captured at
  // the moment the preview future STARTS (not just when it
  // resolves) so a future started after a fresh data
  // revision uses the most recent known previous/next
  // signatures and refetches the trio on the next build.
  //
  // The generation captured at future-start is stored in
  // [_previewGeneration]. When the future resolves, the
  // result is adopted only if the generation still matches
  // the most recent build's generation — so an older
  // in-flight future cannot overwrite the active preview
  // when a more recent data revision has already started a
  // newer future.
  Future<List<PlannerDay>>? _previewLoad;
  int? _previewGeneration;
  String? _previewSignature;
  String? _previousDayContentSignature;
  String? _nextDayContentSignature;
  // Bumped on every build of the screen that holds a
  // non-null `state.day`. Used as the data-revision
  // component of the preview signature so any path that
  // re-reads the selected day through the controller
  // (date navigation, refresh, save) invalidates the
  // cached preview future on the next build.
  int _dataRevision = 0;
  bool _selectionActive = false;
  // Owns the day-swipe candidate lifetime across the Listener
  // wrapper and the timeline's pinch/long-press/resize recognizers.
  // The field is initialized on first build and reused for every
  // subsequent gesture so each pointer-down starts from a known
  // clean state.
  final _DaySwipeCoordinator _daySwipeCoordinator = _DaySwipeCoordinator();
  // Owns the pinch state for the Planner timeline. The
  // timeline's pointer Listener updates the active pointer
  // count; the parent reads the coordinator to decide whether
  // to swap the SingleChildScrollView's physics to
  // NeverScrollableScrollPhysics during a two-pointer pinch.
  // The coordinator lives on the parent state so its lifetime
  // spans the entire Planner route and its listeners (the
  // physics swap and the gesture suppressions) can be wired
  // up once on first build.
  final _PinchCoordinator _pinchCoordinator = _PinchCoordinator();
  // Owns the current-time value for the planner's exact
  // current-time indicator. The timeline reads this via a
  // ValueListenableBuilder so only the indicator subtree rebuilds
  // when the minute changes — the pinch/long-press/resize
  // recognizers and the surrounding widget tree remain untouched
  // by minute ticks. Ownership semantics:
  //
  // - the notifier is constructed in [initState] (so its first
  //   value matches `DateTime.now()` when the widget mounts, not
  //   at field-init time);
  // - a single narrowly-scoped Timer schedules itself to fire at
  //   the next minute boundary and then continues once per minute,
  //   updating the notifier with the latest wall-clock minute;
  // - the timer is cancelled and the notifier is disposed in
  //   [dispose];
  // - tests drive the indicator deterministically by calling
  //   `currentTimeNotifier.value = newNow`, which notifies listeners
  //   without scheduling any real-time wait.
  //
  // When [PlannerScreen.currentTimeListenable] is supplied, the
  // screen-owned notifier and ticker are not constructed — the
  // injected listenable is used verbatim, and the screen does not
  // own its lifecycle. In that mode both [currentTimeNotifier] and
  // [_currentTimeTicker] remain `null` for the entire lifetime of
  // the state, so [dispose] is a no-op for current-time resources.
  ValueNotifier<DateTime>? currentTimeNotifier;
  Timer? _currentTimeTicker;

  /// The listenable the timeline actually reads. Equals the
  /// screen-owned notifier in production; equals the injected
  /// override in focused tests.
  ValueListenable<DateTime> get _activeCurrentTimeListenable =>
      widget.currentTimeListenable ?? currentTimeNotifier!;

  bool get _selectionMode => _selectionActive;

  @override
  void initState() {
    super.initState();
    if (widget.currentTimeListenable == null) {
      currentTimeNotifier = ValueNotifier<DateTime>(DateTime.now());
      _scheduleCurrentTimeTicker();
    }
    // Subscribe to pinch-state changes so the SingleChildScrollView
    // can be rebuilt with the appropriate physics on the same
    // frame a two-finger pinch begins or ends. The listener
    // uses setState; the timeline guarantees the callback only
    // fires on actual state transitions, so the rebuild cost is
    // bounded to one rebuild per gesture boundary.
    _pinchCoordinator.addListener(_onPinchCoordinatorChanged);
    // Register the day-swipe coordinator cancel listener so a
    // competing recognizer (long-press move, vertical drag,
    // pinch scale) tears the interactive day pager back to
    // the centered resting position. The listener is
    // unregistered in [dispose] to keep the lifecycle
    // symmetric; the typed controller exposed on
    // [_pagerController] is the only public command surface
    // used here, so there is no GlobalKey lookup or dynamic
    // invocation crossing module boundaries.
    _daySwipeCoordinator.addCancelListener(
      _pagerController.recenterFromExternalCancel,
    );
  }

  /// Schedule the next minute-boundary tick of [currentTimeNotifier].
  ///
  /// The timer fires once for the next minute boundary then
  /// reschedules itself every minute. Scheduling against the
  /// next boundary (rather than an arbitrary 60-second interval
  /// after construction) keeps the visible time text aligned
  /// with the actual wall-clock minute that crossed during the
  /// interval — a 60 s loop constructed at, say, 14:03:42 would
  /// otherwise tick at 14:04:42 and disagree with the wall clock.
  /// The scheduled duration is recomputed against the current
  /// moment so the ticker stays accurate even if the device's
  /// wall-clock changes mid-session.
  void _scheduleCurrentTimeTicker() {
    _currentTimeTicker?.cancel();
    final now = DateTime.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    final initialDelay = nextMinute.difference(now);
    void onTick() {
      if (!mounted) {
        return;
      }
      currentTimeNotifier!.value = DateTime.now();
      _scheduleCurrentTimeTicker();
    }

    if (initialDelay <= Duration.zero) {
      onTick();
      return;
    }
    _currentTimeTicker = Timer(initialDelay, onTick);
  }

  @override
  void dispose() {
    _currentTimeTicker?.cancel();
    _currentTimeTicker = null;
    currentTimeNotifier?.dispose();
    currentTimeNotifier = null;
    _pinchCoordinator.removeListener(_onPinchCoordinatorChanged);
    _daySwipeCoordinator.removeCancelListener(
      _pagerController.recenterFromExternalCancel,
    );
    _dayScrollController.dispose();
    super.dispose();
  }

  /// Listener invoked by the [_PinchCoordinator] whenever the
  /// pinch state changes. The parent uses the resulting
  /// `isPinchActive` signal to decide whether the parent
  /// SingleChildScrollView's `physics` should be
  /// [NeverScrollableScrollPhysics] (during a two-finger
  /// pinch) or the default [ClampingScrollPhysics] (one
  /// finger or zero fingers). The setState is guarded by
  /// `mounted` to avoid touching a disposed widget, and it
  /// only fires on a real state transition, so the rebuild
  /// cost is bounded.
  void _onPinchCoordinatorChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
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
            PlannerDateStrip(
              selectedDate: state.selectedDate,
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
    // Today icon visual state: pink only when the selected Planner
    // date is the current local date. Date-only comparison via
    // [PlannerDate] equality so hours/minutes/seconds do not affect
    // the color. The clock source is the same deterministic
    // [PlannerDateSource] used by the current-time indicator, so
    // production and tests share the same anchor.
    final today = ref.read(plannerDateSourceProvider).today();
    final isViewingToday = state.selectedDate == today;
    final todayIconColor = isViewingToday
        ? AppTheme.rose
        : Theme.of(context).colorScheme.onSurface;
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
          onPressed: () => GlobalDrawerScope.of(innerContext).open(),
          icon: const Icon(Icons.menu),
        ),
      ),
      titleSpacing: 0,
      title: KeyedSubtree(
        key: const Key('planner-date-picker-trigger'),
        child: InkWell(
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
      ),
      actions: <Widget>[
        Semantics(
          label: 'Go to today',
          button: true,
          child: ExcludeSemantics(
            // Slice D reuses the same calendar icon that the Home
            // top bar used to expose. The component encapsulates the
            // glyph, size, and visual structure while the parent
            // owns the tap callback, the focused key, and the
            // Slice C color contract (pink when selected date is
            // today; on-surface otherwise).
            child: PlannerCalendarButtonSurface(
              onTap: () {
                final today = ref.read(plannerDateSourceProvider).today();
                unawaited(
                  ref
                      .read(plannerControllerProvider.notifier)
                      .selectDate(today),
                );
              },
              color: todayIconColor,
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

    // Bump the per-build data revision every time the planner
    // state is rebuilt with a non-null day. The bump is the
    // authoritative signal that the selected-day content
    // signature may have changed (e.g. a controller refresh
    // after a repository mutation on an adjacent day). The
    // revision is composed into the preview signature below.
    _dataRevision += 1;

    // Three-day read-only preview state for the interactive
    // day pager. The previous/next trio is loaded once per
    // relevant signature change (selected-date change OR a
    // relevant data refresh on the selected day) so a date
    // navigation does not double-fetch. `state.day` keeps
    // driving the centered current page; the preview columns
    // only consume the previous/next slots from the resolved
    // FutureBuilder snapshot for read-only painting. The
    // selected-day slot is intentionally never read from the
    // preview load: the centered current page continues to
    // render the authoritative current Planner state. This
    // avoids duplicate repository caches and bypasses any
    // future drift between the preview store and the
    // authoritative state.
    //
    // The `today` value is read once per build and is the
    // authoritative "is this page today" anchor for the
    // centered indicator and the preview columns. The
    // source is watched (not just read) so a midnight roll
    // — production's system source ticks at midnight,
    // tests inject a mutable source — propagates a single
    // rebuild that re-evaluates `today` and re-seats the
    // indicator ownership across the three pages.
    final today = ref.watch(plannerDateSourceProvider).today();
    final previousDate = state.selectedDate.addDays(-1);
    final nextDate = state.selectedDate.addDays(1);
    final previousSig = _previousDayContentSignature;
    final nextSig = _nextDayContentSignature;
    final previewSignature = 'pager:'
        '${state.selectedDate.iso8601}:'
        'r$_dataRevision:'
        '${_dayContentSignature(day)}:'
        'p${previousSig ?? "_"}:'
        'n${nextSig ?? "_"}:'
        'h${settings.timelineHourHeight.toStringAsFixed(2)}:'
        'v${settings.visibleStartHour}-${settings.visibleEndHour}:'
        't${settings.use24HourTime ? 1 : 0}:'
        'c${settings.showCurrentTime ? 1 : 0}:'
        'x${settings.showCancelledItems ? 1 : 0}:'
        'f${settings.contentFilters.hashCode}';
    if (_previewSignature != previewSignature) {
      _previewSignature = previewSignature;
      // Capture the generation that THIS future was started
      // with. The FutureBuilder adopts the result only if the
      // generation still matches the most recent build's
      // generation at completion time. This is the
      // stale-future protection: an older in-flight future
      // cannot overwrite a newer window.
      final startGeneration = _dataRevision;
      _previewGeneration = startGeneration;
      _previewLoad = ref
          .read(plannerControllerProvider.notifier)
          .readDays(<PlannerDate>[previousDate, state.selectedDate, nextDate])
          .then((days) {
            // Validate the result against the active generation
            // before exposing it to the FutureBuilder. The capture
            // is a synchronous microtask after the future
            // resolves, so it never builds widget state mid-frame.
            if (_previewGeneration == startGeneration) {
              _previousDayContentSignature = _dayContentSignature(days[0]);
              _nextDayContentSignature = _dayContentSignature(days[2]);
            }
            return days;
          });
    }

    final hourHeight = settings.timelineHourHeight;
    final firstHour = settings.visibleStartHour;
    final lastHour = settings.visibleEndHour;
    final slotCount = lastHour - firstHour;
    final timelineHeight = slotCount * hourHeight;

    // Refresh-indicator removed: the Planner does not support
    // pull-to-refresh. The previous RefreshIndicator intercepted
    // downward drags in the gesture arena and competed with the
    // two-finger pinch. Its onRefresh was a no-op
    // (selectDate(state.selectedDate)) and is no longer needed.
    return KeyedSubtree(
      key: _dayScrollKey,
      child: SingleChildScrollView(
        key: const Key('planner-day-scroll'),
        controller: _dayScrollController,
        // Two-pointer pinch owns the gesture; while a pinch
        // is active the timeline must not accumulate a
        // vertical scroll offset that would otherwise be
        // driven by the SingleChildScrollView's
        // VerticalDragGestureRecognizer. The dynamic swap
        // from ClampingScrollPhysics to
        // NeverScrollableScrollPhysics is driven by the
        // [_pinchCoordinator] listener installed in
        // [initState] and is the smallest coherent
        // architecture that satisfies the "two-pointer
        // pinch beats ordinary vertical scroll" contract
        // without introducing a second timeline wrapper.
        physics: _pinchCoordinator.isPinchActive
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 96),
        child: Column(
          children: <Widget>[
            if (state.message != null) ...<Widget>[
              _PlannerNotice(message: state.message!),
              const SizedBox(height: 12),
            ],
            FutureBuilder<List<PlannerDay>>(
              future: _previewLoad,
              builder: (context, snapshot) {
                // The FutureBuilder is the single consumer of
                // the cached preview future. While the future
                // is in-flight the preview columns render
                // with `null` data (an empty read-only grid);
                // the centered current page is unaffected
                // because it is driven by `state.day`.
                // When the future resolves, the resolved list
                // is fed straight into the previous/next
                // preview columns. Stale results are dropped
                // by the generation guard inside the future
                // pipeline above — the FutureBuilder adopts
                // the latest in-flight future via the
                // signature key, and the resolution callback
                // only updates the captured previous/next
                // signatures when the in-flight generation
                // still matches the active build's
                // generation. Therefore an older in-flight
                // future cannot overwrite the active preview
                // when a more recent data revision has
                // already started a newer future.
                final previewDays = snapshot.data;
                final previousDay =
                    (previewDays != null && previewDays.length >= 3)
                    ? previewDays[0]
                    : null;
                final nextDay = (previewDays != null && previewDays.length >= 3)
                    ? previewDays[2]
                    : null;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportWidth = constraints.maxWidth;
                    return PlannerInteractiveDayPager(
                      key: const Key('planner-day-pager-viewport'),
                      controller: _pagerController,
                      selectedDate: state.selectedDate,
                      previousDate: previousDate,
                      nextDate: nextDate,
                      previousDay: previousDay,
                      currentDay: day,
                      nextDay: nextDay,
                      today: today,
                      settings: settings,
                      hourHeight: hourHeight,
                      timelineHeight: timelineHeight,
                      viewportWidth: viewportWidth,
                      onSwipePointerDown: _daySwipeCoordinator.onPointerDown,
                      onSwipePointerUp: _daySwipeCoordinator.onPointerUp,
                      onSwipeCancel: _daySwipeCoordinator.claim,
                      onPinchPointerCount: () => _pinchCoordinator.pointerCount,
                      onPinchClearCancel: _pinchCoordinator.clearCancel,
                      onDayChanged: (delta) async {
                        // Selection mode and overflow menus own their own
                        // gesture pipelines; day-swipe is a Day-view-only
                        // affordance and must not interfere with those
                        // interactions. The Day-view is the only context
                        // where this widget tree is built (the other
                        // presentations short-circuit above), so no extra
                        // presentation guard is required.
                        if (delta == 0) {
                          return;
                        }
                        await ref
                            .read(plannerControllerProvider.notifier)
                            .moveDays(delta);
                      },
                      currentTimeListenable: _activeCurrentTimeListenable,
                      currentPage: KeyedSubtree(
                        key: const Key('timed-events-section'),
                        child: _TimedEventTimeline(
                          events: _visibleEvents(day.timedEvents, settings)
                              .where(
                                (event) =>
                                    settings.showCancelledItems ||
                                      event.state !=
                                          PlannerEventState.cancelled,
                              )
                              .toList(growable: false),
                          selectedDate: state.selectedDate,
                          settings: settings,
                          scrollController: _dayScrollController,
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
                          onZoomEnd: (value) =>
                              _persistZoom(ref, settings, value),
                          daySwipeCoordinator: _daySwipeCoordinator,
                          pinchCoordinator: _pinchCoordinator,
                          currentTimeListenable: _activeCurrentTimeListenable,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
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
    // Phase 5 — Slice D removed automatic scroll-to-current-time
    // triggered by date changes. The initial scroll only runs on
    // first mount per session; subsequent date navigation
    // (horizontal swipe, week-strip tap, Go to today, picker
    // selection) preserves the existing vertical viewport.
    //
    // The signature dedup matches every input that would justify a
    // re-scroll so we never compute the same target twice; the
    // separate one-shot [_initialScrollPerformed] flag is the
    // true gate and stays true for the lifetime of this state,
    // so date changes can never re-fire the post-frame jumpTo.
    final signature =
        '${selectedDate.iso8601}:${settings.visibleStartHour}:'
        '${settings.visibleEndHour}:${settings.initialScrollBehavior.name}';
    if (_initialScrollSignature == signature) {
      return;
    }
    _initialScrollSignature = signature;
    if (_initialScrollPerformed) {
      // Subsequent calls debounce via the signature; the
      // one-shot gate short-circuits before scheduling the
      // post-frame jumpTo that would otherwise move the
      // viewport to current-time on every date change.
      return;
    }
    _initialScrollPerformed = true;
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
      // Slice D writes the explicit frame-deferred scroll only
      // on the very first signature occurrence. The signature
      // gate above catches every subsequent invocation, and the
      // one-shot [_initialScrollPerformed] flag covers the case
      // where the same date is re-selected later without a
      // signature change. The additional mount-time guards
      // keep the planner from jumping to current-time after
      // date navigation even if the state is briefly torn down
      // and rebuilt without a different signature.
      if (!mounted || !_initialScrollPerformed) {
        return;
      }
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
      // jumpTo() is a synchronous scroll hint that does not block
      // the gesture pipeline; call it directly. The earlier
      // unawaited() wrapper was rejected by the analyzer because
      // the bound signature returns void in this Flutter SDK.
      _dayScrollController.jumpTo(desired);
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
    final result = await showPlannerSlideDownDatePicker(
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

/// Vertical-dominance ratio: a gesture whose |dy| exceeds
/// |dx| * ratio is treated as a vertical drag (Event resize or
/// timeline scroll) and is not eligible for day navigation. The
/// 1.6 ratio is wide enough that a clean horizontal sweep
/// (dy ≈ 0) commits, while an angled drag that drifts more than
/// ~60% vertical is rejected. The horizontal/vertical
/// arbitration is owned by the [_DaySwipeCoordinator]; the
/// interactive day pager in [PlannerInteractiveDayPager]
/// applies its own direction-lock + horizontal-dominance
/// contract (see [kPlannerPagerDirectionLockDistance] and
/// [kPlannerPagerHorizontalDominanceRatio] in
/// planner_interactive_day_pager.dart).
const double _daySwipeVerticalDominanceRatio = 1.6;

/// Mutable coordinator shared between the swipe detector and the
/// other gesture sources (long-press move, vertical resize drag,
/// pinch zoom) so any of them can cancel an in-progress swipe
/// candidate before it commits a day change. The coordinator lives
/// on the parent state so its lifetime spans a single swipe gesture
/// and is reset on every pointer-down.
///
/// The [addCancelListener] / [removeCancelListener] hooks are an
/// extension hook for the live day pager added in Stage B3-R1
/// Slice D3-A: when a competing recognizer (long-press move,
/// vertical resize, or pinch) calls [cancel], the pager receives
/// a callback so it can drop its in-progress drag session and
/// animate back to the centered resting position. The hook keeps
/// the pager from competing with the existing recognizers in the
/// gesture arena — the recognizer that calls [cancel] still owns
/// the pointer, and the pager simply recenters without driving
/// the live transform further.
class _DaySwipeCoordinator {
  int _pointerCount = 0;
  bool _sawMultiPointer = false;
  bool _verticalDominant = false;
  bool _externalCancel = false;
  final List<VoidCallback> _cancelListeners = <VoidCallback>[];

  void begin() {
    _pointerCount = 0;
    _sawMultiPointer = false;
    _verticalDominant = false;
    _externalCancel = false;
  }

  void onPointerDown() {
    // Reset the gesture state on every fresh down so a
    // sticky `_externalCancel` from a previous gesture (set
    // by the previous gesture's last `cancel()` or `claim()`
    // call) cannot suppress a new swipe candidate. The
    // count itself is then incremented for this new pointer.
    _sawMultiPointer = false;
    _verticalDominant = false;
    _externalCancel = false;
    _pointerCount += 1;
    if (_pointerCount >= 2) {
      _sawMultiPointer = true;
    }
  }

  /// Returns true while the gesture is still eligible to commit a
  /// day change after observing the given accumulated deltas.
  /// `dx` and `dy` are the cumulative screen deltas for the active
  /// pointer since the gesture began.
  bool onPointerMove(double dx, double dy) {
    if (_pointerCount != 1 || _externalCancel) {
      return false;
    }
    if (dy.abs() > dx.abs() * _daySwipeVerticalDominanceRatio) {
      // Vertical-dominant motion (scroll / resize / long-press
      // move) means the swipe candidate has lost; remember the
      // fact so the commit check at pointer-up also rejects
      // the gesture even if the pointer comes back to a flat
      // horizontal track.
      _verticalDominant = true;
      return false;
    }
    return true;
  }

  void onPointerUp() {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
  }

  /// Called by the long-press move, vertical resize drag, and pinch
  /// scale recognizers when one of them claims the gesture. The
  /// pending swipe candidate is then dropped without committing.
  /// Notifies every registered cancel listener so any live-finger
  /// observer (the interactive day pager) can recenter.
  void cancel() {
    if (_externalCancel) {
      return;
    }
    _externalCancel = true;
    for (final listener in List<VoidCallback>.of(_cancelListeners)) {
      listener();
    }
  }

  /// Called by the interactive day pager once it has claimed
  /// the gesture for horizontal paging. Sets the same
  /// [_externalCancel] flag as [cancel] so the timeline's
  /// long-press move, vertical resize drag, and pinch scale
  /// recognizers back off, but does NOT notify the cancel
  /// listener (the pager itself) so the self-trigger does
  /// not feed back into the pager's own recenter.
  void claim() {
    _externalCancel = true;
  }

  /// Subscribe to [cancel] notifications. The listener fires once
  /// per external-cancel transition. Subscription is intentionally
  /// minimal so the coordinator remains dependency-free.
  void addCancelListener(VoidCallback listener) {
    _cancelListeners.add(listener);
  }

  void removeCancelListener(VoidCallback listener) {
    _cancelListeners.remove(listener);
  }

  bool get isActive =>
      _pointerCount == 0 && !_sawMultiPointer && !_verticalDominant;
}

/// Mutable coordinator that tracks the Planner timeline's
/// pinch state. The timeline's pointer Listener increments /
/// decrements the active pointer count; once the count reaches
/// two, the timeline reports the gesture as a pinch and the
/// parent state can use that signal to (a) swap the parent
/// SingleChildScrollView to NeverScrollableScrollPhysics so
/// ordinary vertical scrolling cannot accumulate, (b) suppress
/// Event tap / move / resize and empty-time create handlers
/// for the duration of the pinch and one settle pump, and
/// (c) ensure the day-swipe detector has already been
/// cancelled.
///
/// The coordinator is intentionally decoupled from the
/// [_DaySwipeCoordinator]; the two share no state because
/// their lifetimes and responsibilities differ. The
/// coordinator is reset on the first pointer-down of each
/// fresh gesture, so a previous two-pointer pinch cannot
/// leave stale state behind that would suppress a future
/// one-finger scroll.
class _PinchCoordinator {
  int _pointerCount = 0;
  bool _externalCancel = false;
  // Listeners are notified whenever the pinch state changes
  // (pointer count transitions across 2, or cancel is
  // invoked). The parent state subscribes to rebuild the
  // SingleChildScrollView with the right physics; tests can
  // also subscribe to read the live state.
  final List<VoidCallback> _listeners = <VoidCallback>[];

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  void begin() {
    _pointerCount = 0;
    _externalCancel = false;
  }

  /// Called by the timeline's pointer Listener on every
  /// pointer-down. Returns true when the pointer-down caused
  /// the gesture to transition into the pinch state, so the
  /// caller can perform one-time side effects (e.g. cancel
  /// the day-swipe, capture the pinch baseline) on the exact
  /// frame the second finger lands.
  bool onPointerDown() {
    _pointerCount += 1;
    if (_pointerCount == 2) {
      _notify();
      return true;
    }
    return false;
  }

  /// Called by the timeline's pointer Listener on every
  /// pointer-up. Returns true when the pointer-up caused the
  /// gesture to transition out of the pinch state (count
  /// drops below 2), so the caller can finalize pinch state
  /// and restore ordinary one-finger scrolling.
  bool onPointerUp() {
    if (_pointerCount > 0) {
      _pointerCount -= 1;
    }
    if (_pointerCount < 2) {
      _notify();
      return true;
    }
    return false;
  }

  /// Called by the long-press move, vertical resize drag, and
  /// pinch scale recognizers when one of them claims the
  /// gesture. The pending pinch candidate is then dropped
  /// without committing any further updates.
  void cancel() {
    if (_externalCancel) {
      return;
    }
    _externalCancel = true;
    _notify();
  }

  void clearCancel() {
    if (!_externalCancel) {
      return;
    }
    _externalCancel = false;
    _notify();
  }

  /// True while two or more pointers are on the timeline and
  /// no recognizer has claimed the gesture. The parent state
  /// uses this to swap the SingleChildScrollView to
  /// NeverScrollableScrollPhysics.
  bool get isPinchActive => _pointerCount >= 2 && !_externalCancel;

  int get pointerCount => _pointerCount;
}

final class _TimedEventTimeline extends StatefulWidget {
  const _TimedEventTimeline({
    required this.events,
    required this.selectedDate,
    required this.settings,
    required this.scrollController,
    required this.onCreate,
    required this.onMove,
    required this.onResize,
    required this.selectionMode,
    required this.selectedItems,
    required this.onToggleSelection,
    required this.hourHeight,
    required this.onZoomEnd,
    required this.daySwipeCoordinator,
    required this.pinchCoordinator,
    required this.currentTimeListenable,
  });

  final List<PlannerCalendarItem> events;
  final PlannerDate selectedDate;
  final PlannerSettings settings;
  // Parent-owned SingleChildScrollView controller used for focal-time
  // preservation while pinching. Held here by reference so pinch
  // updates can reposition the viewport without rebuilding the screen.
  final ScrollController scrollController;
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
  // Shared coordinator that lets the timeline's pinch, long-press
  // move, and vertical resize recognizers cancel an in-progress
  // day-swipe candidate before it commits. The detector lives on
  // the parent state, so the timeline only invokes its cancel()
  // hook without owning its lifecycle.
  final _DaySwipeCoordinator daySwipeCoordinator;
  // Shared coordinator that lets the timeline surface report
  // its active pointer count to the parent so the parent can
  // swap the SingleChildScrollView to
  // NeverScrollableScrollPhysics while a two-pointer pinch is
  // in progress. The coordinator lives on the parent state so
  // its lifetime spans the entire Planner route; the timeline
  // only reports pointer-down / pointer-up events without
  // owning its lifecycle.
  final _PinchCoordinator pinchCoordinator;
  // Parent-owned current-time source. The indicator subtree
  // watches this listenable via ValueListenableBuilder so a minute
  // tick only rebuilds the indicator — not the pinch / long-press
  // / resize recognizers or the surrounding gesture surface.
  // The notifier is owned and disposed by [_PlannerScreenState];
  // tests advance it by writing to it directly.
  final ValueListenable<DateTime> currentTimeListenable;

  @override
  State<_TimedEventTimeline> createState() => _TimedEventTimelineState();
}

final class _TimedEventTimelineState extends State<_TimedEventTimeline> {
  static const double _timeColumnWidth = 56;
  static const double _eventGap = 3;
  // Vertical extent of the current-time indicator Row. The Row is
  // centered on the exact current minute within the timeline, so
  // this value defines the band whose center marks the minute.
  // Tall enough to host the 11-px time label and the 8-px dot and
  // 2-px line, with crossAxisAlignment.center centering each on
  // the minute within normal logical-pixel rounding tolerance.
  static const double _currentTimeIndicatorHeight = 12;

  final Map<String, int> _previewStartMinutes = <String, int>{};
  final Map<String, int> _previewEndMinutes = <String, int>{};
  final Map<String, double> _resizeAccumulatedPixels = <String, double>{};
  final Set<String> _persisting = <String>{};
  late double _hourHeight;
  // Pinch focal-time preservation: captured at two-finger scale start
  // and reapplied on every onScaleUpdate so the time under the focal
  // point stays under the same screen-local position as hour height
  // changes. The local Y is measured from the GestureDetector origin,
  // which sits at the top of the timeline surface (inside the
  // scrollable; not the global screen). The focal content Y is the
  // pointer's position in the scrollable's content space (scroll
  // offset + local Y), so dividing by the start pixelsPerMinute gives
  // the focal minute-of-day relative to `_firstHour`.
  double? _zoomStartHeight;
  double? _zoomStartScrollOffset;
  double? _zoomFocalLocalY;
  double? _zoomFocalMinute;

  // Pinch two-pointer priority (Stage B3-R1 Slice D2):
  //
  // The Planner timeline must give an authentic two-pointer
  // pinch authoritative priority over a one-finger vertical
  // scroll. This is achieved by tracking the active pointer
  // count from the moment the first finger lands on the
  // timeline. When the count reaches 2, the timeline switches
  // its SingleChildScrollView child to a
  // `NeverScrollableScrollPhysics()` so the vertical drag
  // recognizer cannot accumulate a scroll offset, and the
  // empty-time / Event-tap / Event-move / Event-resize
  // gesture handlers short-circuit (they observe
  // `_pinchActive` and return immediately). When the count
  // falls below 2, ordinary vertical scrolling and Event
  // interactions are restored, but only after a fresh
  // one-finger gesture begins — stale pinch state cannot
  // trigger a delayed tap or swipe.
  bool _pinchActive = false;
  // Settle-time buffer: after the second pointer lifts and
  // the count returns to 0 or 1, the timeline keeps the
  // suppressions active for a single pump cycle so the gesture
  // arena can fully retire the scale recognizer before a fresh
  // vertical drag or tap is honored. This prevents the
  // observed race where lifting the second finger would allow
  // the remaining finger to immediately commit a vertical
  // scroll or a tap. The buffer is one pump, not a wall-clock
  // delay, so it cannot be classified as an artificial timer.
  bool _postPinchSuppress = false;

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

  /// True while the timeline must refuse to act on a one-finger
  /// gesture because a two-finger pinch is in progress (or the
  /// pinch just ended within the current pump cycle). Event
  /// tap / move / resize and the empty-time create handler all
  /// read this flag at the top of their callback and short-
  /// circuit when it is true.
  bool get _suppressOneFingerInteractions => _pinchActive || _postPinchSuppress;

  @override
  Widget build(BuildContext context) {
    final slotCount = _lastHour - _firstHour;
    final timelineHeight = slotCount * _hourHeight;
    final placements = PlannerTimelineLayout.arrange(widget.events);
    // The current-time read happens inside the
    // ValueListenableBuilder so the indicator's visibility,
    // label, and vertical position all refresh together on every
    // minute tick without rebuilding the pinch / long-press /
    // resize recognizers on this surface.
    return Listener(
      // Pointer-level Listener wraps the entire timeline
      // surface so the active pointer count is tracked from
      // the very first finger-down, not only from the moment
      // the gesture arena promotes a ScaleGestureRecognizer.
      // The Listener does not consume the events; the inner
      // GestureDetector still receives every pointer event for
      // its scale / tap / long-press recognizers. The Listener
      // only feeds [_PinchCoordinator] so the parent state can
      // decide whether to swap the SingleChildScrollView
      // physics to NeverScrollableScrollPhysics.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        final transitioned = widget.pinchCoordinator.onPointerDown();
        if (transitioned) {
          // The second pointer just landed; the pinch now owns
          // the gesture. Cancel the day-swipe candidate (in
          // case the second finger is moving horizontally) and
          // arm the suppressions so a stale one-finger tap or
          // drag cannot commit after the pinch ends. The
          // _PinchCoordinator remains "active" (its
          // _externalCancel flag stays false) so the parent
          // state swaps the SingleChildScrollView physics to
          // NeverScrollableScrollPhysics for the duration of
          // the pinch; the explicit `clearCancel()` call
          // ensures no prior cancel state is lingering.
          widget.daySwipeCoordinator.cancel();
          widget.pinchCoordinator.clearCancel();
          _pinchActive = true;
          _postPinchSuppress = true;
        }
      },
      onPointerUp: (event) {
        final transitioned = widget.pinchCoordinator.onPointerUp();
        if (transitioned) {
          _pinchActive = false;
          // _postPinchSuppress stays true until the next pump
          // cycle, so a stale single-pointer drag that was
          // already in flight cannot commit a vertical scroll
          // or an empty-time tap immediately after the second
          // finger lifted. The flag is cleared by the post-frame
          // callback scheduled in onScaleEnd.
        }
      },
      onPointerCancel: (event) {
        final transitioned = widget.pinchCoordinator.onPointerUp();
        if (transitioned) {
          _pinchActive = false;
        }
      },
      child: GestureDetector(
        key: const Key('planner-zoom-surface'),
        behavior: HitTestBehavior.translucent,
        onScaleStart: (details) {
          // Pinch (two-pointer scale) owns the gesture. The
          // pinch baseline is captured as soon as the
          // recognizer fires with two pointers; Flutter's
          // ScaleGestureRecognizer resets `details.scale` to
          // 1.0 on the first onScaleStart of a multi-pointer
          // gesture, so the captured start height is the
          // pre-pinch effective hour height. The
          // _PinchCoordinator has already ensured the parent
          // SingleChildScrollView is in
          // NeverScrollableScrollPhysics for the duration of
          // the gesture.
          if (details.pointerCount >= 2) {
            widget.daySwipeCoordinator.cancel();
            _zoomStartHeight = _hourHeight;
            // Capture focal-time anchors: the local Y from this
            // GestureDetector's coordinate space and the scroll
            // offset of the parent SingleChildScrollView. The
            // local coordinate is the pointer's position inside
            // the timeline surface (origin at the top of the
            // SizedBox). The scroll offset is read defensively
            // (the controller has clients while mounted inside
            // the scroll view).
            _zoomStartScrollOffset = widget.scrollController.hasClients
                ? widget.scrollController.offset
                : 0;
            _zoomFocalLocalY = details.localFocalPoint.dy;
            final focalContentY =
                (_zoomStartScrollOffset ?? 0) + (_zoomFocalLocalY ?? 0);
            // Convert the content-Y to a focal minute using the
            // *effective* current pixelsPerMinute (the start hour
            // height). This is the minute whose time label was
            // sitting under the focal point when the pinch began
            // and is the value preserved by scroll recomputation
            // on every subsequent scale update.
            final startPixelsPerMinute = _hourHeight / 60;
            _zoomFocalMinute = startPixelsPerMinute > 0
                ? focalContentY / startPixelsPerMinute
                : 0;
            // Clear the one-pump settle flag from any previous
            // pinch: a fresh two-pointer pinch has just begun
            // and its suppressions are explicit (_pinchActive
            // is now true), so the post-pinch buffer is no
            // longer required.
            _postPinchSuppress = false;
          }
        },
        onScaleUpdate: (details) {
          final start = _zoomStartHeight;
          final focalMinute = _zoomFocalMinute;
          final focalLocalY = _zoomFocalLocalY;
          if (start == null ||
              focalMinute == null ||
              focalLocalY == null ||
              details.pointerCount < 2) {
            return;
          }
          // Apply the dead zone around 1.0 and re-anchor the
          // scale baseline to the captured start hour height
          // (not the current hour height) so the response is
          // monotonic and stable across the gesture lifetime.
          final adjustedScale = PlannerZoomPolicy.applyDeadZone(details.scale);
          final newHourHeight = PlannerZoomPolicy.clamp(start * adjustedScale);
          final newPixelsPerMinute = newHourHeight / 60;
          final controller = widget.scrollController;
          // Compute the scroll offset that keeps the captured focal
          // minute directly beneath the same local Y on the timeline
          // surface. Clamp to the controller's valid extent so we
          // cannot overshoot the start or end of the scrollable.
          final desiredFocalContentY = focalMinute * newPixelsPerMinute;
          final desiredOffset = (desiredFocalContentY - focalLocalY).toDouble();
          final hasClients = controller.hasClients;
          final maxExtent = hasClients
              ? controller.position.maxScrollExtent
              : double.infinity;
          final minExtent = hasClients
              ? controller.position.minScrollExtent
              : 0.0;
          final clampedOffset = desiredOffset
              .clamp(minExtent, maxExtent)
              .toDouble();
          setState(() {
            _hourHeight = newHourHeight;
            if (hasClients) {
              controller.jumpTo(clampedOffset);
            }
          });
        },
        onScaleEnd: (_) {
          if (_zoomStartHeight != null) {
            _zoomStartHeight = null;
            _zoomStartScrollOffset = null;
            _zoomFocalLocalY = null;
            _zoomFocalMinute = null;
            widget.onZoomEnd(_hourHeight);
          }
          // Keep the one-pump settle suppression active until
          // the next frame so a stale single-pointer drag that
          // was already in flight cannot immediately commit a
          // vertical scroll or a tap.
          _postPinchSuppress = true;
          _pinchActive = false;
          // Clear the cancel flag so a subsequent fresh
          // two-pointer pinch can claim the gesture again.
          widget.pinchCoordinator.clearCancel();
          // Schedule a single post-frame tick to clear the
          // settle flag once the gesture arena has retired the
          // scale recognizer. Using WidgetsBinding's transient
          // callback keeps this off any wall-clock timer and
          // avoids the artificial-delay anti-pattern.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _postPinchSuppress = false;
          });
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
                        // Empty-time create: suppressed while a
                        // pinch is in progress or during the
                        // one-pump settle window so a stale
                        // finger landing does not open the
                        // Event Type picker after the pinch
                        // ends.
                        if (_suppressOneFingerInteractions) {
                          return;
                        }
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
                      width: _timeColumnWidth,
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
                  for (var hourIndex = 0; hourIndex < slotCount; hourIndex++)
                    for (var quarter = 1; quarter < 4; quarter++)
                      Positioned(
                        key: Key(
                          'planner-quarter-hour-line-'
                          '${_firstHour + hourIndex}-${quarter * 15}',
                        ),
                        top:
                            hourIndex * _hourHeight +
                            quarter *
                                PlannerTimelineGeometry.quarterHourHeight(
                                  _hourHeight,
                                ),
                        left: _timeColumnWidth,
                        right: 0,
                        child: IgnorePointer(
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppTheme.outline.withValues(alpha: 0.45),
                          ),
                        ),
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
                  Positioned.fill(
                    key: const Key('planner-current-time-overlay'),
                    child: IgnorePointer(
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: widget.currentTimeListenable,
                        builder: (context, currentNow, _) {
                          // Current-time overlay: nested-Stack pattern so
                          // both ParentData relationships remain valid.
                          //
                          // * Outer [Positioned.fill] is a direct child of
                          //   the main timeline [Stack] (Positioned MUST
                          //   be laid out by a Stack).
                          // * Inner [Stack] is the builder's return value;
                          //   the inner [Positioned] for the indicator Row
                          //   is a direct child of that inner [Stack],
                          //   keeping ParentData valid when the indicator
                          //   is visible.
                          // * When hidden, the inner [Stack] contains no
                          //   Positioned and is therefore safe to render.
                          //
                          // The ValueListenableBuilder rebuilds only this
                          // overlay subtree on minute ticks; the pinch,
                          // long-press, resize, day-swipe, and event-tap
                          // recognizers are not in the rebuild path.
                          final minuteFromVisibleStart =
                              ((currentNow.hour - _firstHour) * 60) +
                              currentNow.minute;
                          final pixelsPerMinute =
                              PlannerTimelineGeometry.pixelsPerMinute(
                                _hourHeight,
                              );
                          final resolvedMinuteY =
                              minuteFromVisibleStart * pixelsPerMinute;
                          final resolvedIndicatorTop =
                              resolvedMinuteY - _currentTimeIndicatorHeight / 2;
                          final indicatorVisible =
                              widget.settings.showCurrentTime &&
                              widget.selectedDate ==
                                  PlannerDate.fromDateTime(currentNow);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              if (indicatorVisible)
                                Positioned(
                                  key: const Key(
                                    'planner-current-time-indicator',
                                  ),
                                  top: resolvedIndicatorTop,
                                  left: 0,
                                  right: 0,
                                  child: SizedBox(
                                    height: _currentTimeIndicatorHeight,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        SizedBox(
                                          width: _timeColumnWidth - 8,
                                          child: Text(
                                            formatPlannerCurrentTimeLabel(
                                              currentNow,
                                            ),
                                            key: const Key(
                                              'planner-current-time-label',
                                            ),
                                            textAlign: TextAlign.right,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.visible,
                                            style: const TextStyle(
                                              color: AppTheme.rose,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          key: const Key(
                                            'planner-current-time-dot',
                                          ),
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(
                                            left: 0,
                                            right: 0,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.rose,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Expanded(
                                          child: SizedBox(
                                            key: const Key(
                                              'planner-current-time-line',
                                            ),
                                            height: 2,
                                            child: const DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: AppTheme.rose,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  for (final placement in placements)
                    _positionedEvent(placement, constraints.maxWidth),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _positionedEvent(
    PlannerTimelinePlacement placement,
    double totalWidth,
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
    final geometry = PlannerTimelineGeometry.event(
      startMinute: startMinute,
      endMinute: endMinute,
      visibleStartMinute: visibleStart,
      visibleEndMinute: visibleEnd,
      hourHeight: _hourHeight,
    );
    final availableWidth = totalWidth - _timeColumnWidth - 8;
    final columnWidth =
        (availableWidth - _eventGap * (placement.columnCount - 1)) /
        placement.columnCount;
    final left =
        _timeColumnWidth + 5 + placement.column * (columnWidth + _eventGap);
    return Positioned(
      key: Key('planner-timed-event-${event.id}'),
      top: geometry.top,
      left: left,
      width: columnWidth,
      height: geometry.height,
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
          // Long-press move owns the gesture from its first move;
          // cancel any pending horizontal day-swipe so the two
          // recognizers never both claim a single-finger drag.
          // Suppressed while a two-finger pinch is in progress
          // (or in the one-pump settle window) so a stale
          // single-pointer drag that overlapped the pinch cannot
          // commit an Event move after the pinch ends.
          if (_suppressOneFingerInteractions) {
            return;
          }
          widget.daySwipeCoordinator.cancel();
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
        onMoveEnd: () {
          if (_suppressOneFingerInteractions) {
            _clearPreview(event.id);
            return;
          }
          unawaited(_finishMove(event, originalStartMinute));
        },
        onMoveCancel: () => _clearPreview(event.id),
        onResizeStart: () {
          // Vertical resize owns the gesture; cancel any pending
          // horizontal day-swipe so a long-finger drag along the
          // bottom edge never navigates between days. Suppressed
          // during a two-finger pinch and its settle window so a
          // stale single-pointer drag that overlapped the pinch
          // cannot commit an Event resize after the pinch ends.
          if (_suppressOneFingerInteractions) {
            return;
          }
          widget.daySwipeCoordinator.cancel();
          // Resize keeps the original start; ensure no stale start-preview
          // from a previous move leaks into the resize calculation. The
          // accumulator tracks the cumulative vertical drag distance from
          // resize start, so each onResizeUpdate adds to it rather than
          // overwriting the preview with the current incremental delta.
          _previewStartMinutes.remove(event.id);
          _resizeAccumulatedPixels[event.id] = 0;
        },
        onResizeUpdate: (deltaPixels) {
          // First vertical update also pins the gesture to resize.
          if (_suppressOneFingerInteractions) {
            return;
          }
          widget.daySwipeCoordinator.cancel();
          final accumulated =
              (_resizeAccumulatedPixels[event.id] ?? 0) + (deltaPixels);
          _resizeAccumulatedPixels[event.id] = accumulated;
          final rawDelta = (accumulated / _hourHeight * 60).round();
          final deltaMinutes =
              (rawDelta / widget.settings.snapMinutes).round() *
              widget.settings.snapMinutes;
          final nextEnd = (originalEndMinute + deltaMinutes).clamp(
            originalStartMinute + widget.settings.snapMinutes,
            visibleEnd,
          );
          setState(() => _previewEndMinutes[event.id] = nextEnd);
        },
        onResizeEnd: () {
          if (_suppressOneFingerInteractions) {
            _clearPreview(event.id);
            return;
          }
          unawaited(_finishResize(event, originalEndMinute));
        },
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
        _resizeAccumulatedPixels.remove(event.id);
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
      _resizeAccumulatedPixels.remove(eventId);
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
    required this.onResizeStart,
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
  final VoidCallback onResizeStart;
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
                    key: Key('planner-resize-drag-${event.id}'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: interactive
                        ? (_) => onResizeStart()
                        : null,
                    onVerticalDragUpdate: interactive
                        ? (details) => onResizeUpdate(details.primaryDelta ?? 0)
                        : null,
                    onVerticalDragEnd: interactive
                        ? (_) => onResizeEnd()
                        : null,
                    onVerticalDragCancel: interactive ? onResizeCancel : null,
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
              // Always-available resize hit area that overlaps the
              // bottom edge of the block, even on short blocks that
              // cannot fit a visible handle. Sized to the practical
              // minimum touch target (40dp) but constrained to the
              // bottom region so the Event tap area is preserved.
              if (interactive)
                Positioned(
                  key: Key('planner-resize-hit-${event.id}'),
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: PlannerEventBlockLayoutPolicy.resizeHitAreaHeight
                      .clamp(0.0, availableHeight),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    dragStartBehavior: DragStartBehavior.down,
                    onVerticalDragStart: (_) => onResizeStart(),
                    onVerticalDragUpdate: (details) =>
                        onResizeUpdate(details.primaryDelta ?? 0),
                    onVerticalDragEnd: (_) => onResizeEnd(),
                    onVerticalDragCancel: onResizeCancel,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (selectionMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
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
      fontSize: density == Density.veryShort ? 9 : 12,
      height: density == Density.veryShort ? 1.0 : 1.1,
    );
    final timeStyle = TextStyle(
      color: textColor.withValues(alpha: 0.92),
      fontWeight: FontWeight.w600,
      fontSize: density == Density.tall ? 11 : 10,
      height: 1.1,
    );
    final timeText = _formatRange(
      displayStartMinute,
      displayEndMinute,
      use24HourTime,
    );
    final inlineText = '${event.title}  $timeText';
    final verticalPadding = density == Density.veryShort ? 0.0 : 4.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, verticalPadding, 6, verticalPadding),
      child: Column(
        key: const Key('planner-event-block-content'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            content.showTimeInline ? inlineText : event.title,
            style: titleStyle,
            maxLines: content.titleMaxLines,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            key: const Key('planner-event-block-title'),
          ),
          if (content.showTime && !content.showTimeInline)
            Padding(
              padding: EdgeInsets.only(top: density == Density.tall ? 2 : 1),
              child: Text(
                timeText,
                key: const Key('planner-event-block-time'),
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
                isReported: event.hasOutcomeReport,
                linkedTaskCount: event.linkedTaskIds.length,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatRange(int start, int end, bool use24HourTime) {
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
    required this.isReported,
    required this.linkedTaskCount,
  });

  final Color textColor;
  final bool isBackup;
  final bool awaitingReport;
  final bool isReported;
  final int linkedTaskCount;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    if (awaitingReport) {
      icon = Icons.assignment_late_outlined;
      label = 'Awaiting Report';
    } else if (isReported) {
      icon = Icons.check_circle_outline;
      label = 'Completed';
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

/// Format a [DateTime] (interpreted as a local wall-clock time) to
/// the planner's required 12-hour current-time label: `h:mm a`,
/// with no leading zero on the hour, two digits for minutes,
/// uppercase AM/PM, and no seconds or timezone suffix. Centralised
/// here so both the production widget and the focused current-time
/// tests can pin the exact format without duplicating arithmetic.
String formatPlannerCurrentTimeLabel(DateTime now) {
  final hour24 = now.hour;
  final minute = now.minute;
  final displayHour = hour24 == 0
      ? 12
      : hour24 > 12
      ? hour24 - 12
      : hour24;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
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
