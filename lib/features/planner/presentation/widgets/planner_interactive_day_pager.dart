// Planner interactive day pager (Stage B3-R1 Slice D3-A1).
//
// Three-day horizontal pager that lets the user page through
// yesterday, today, and tomorrow with a finger-following drag
// while preserving the Planner's single vertical ScrollController
// and the locked pinch coordinator from D2.
//
// Layout (single-offset model):
//
//   ClipRect
//     └── Stack (viewport-wide, height = timelineHeight)
//           └── Positioned (left: 0, width: viewportWidth * 3)
//                 └── Transform.translate(offset: (translationX, 0))
//                       └── Row (3 children, each viewportWidth wide)
//                             ├── previous-day page   (read-only preview)
//                             ├── current-day  page   (interactive)
//                             └── next-day     page   (read-only preview)
//
// The Row begins at horizontal position 0. At rest the
// Transform.translate is `translationX == -viewportWidth`, which
// puts the second Row child (the current-day page) in the
// visible viewport without ever straddling the centerline.
//
// During a left drag liveDragOffset is negative so the
// Transform translation becomes more negative than the rest
// value of `-viewportWidth`; the entire Row shifts leftward,
// the current-day column slides off the left edge of the
// ClipRect, and the next-day column enters from the right.
//
// During a right drag liveDragOffset is positive so the
// translation becomes less negative than the rest value; the
// Row shifts rightward, the current-day column slides off the
// right edge, and the previous-day column enters from the
// left.
//
// `liveDragOffset` is maintained as the live, finger-relative
// delta and stored as `0` at rest. The visible translation is
// always `-viewportWidth + liveDragOffset`, so the only
// interpretation any code path needs is:
//
//   - at rest: translationX = -viewportWidth
//   - left drag in progress: liveDragOffset is negative
//   - right drag in progress: liveDragOffset is positive
//   - left commit target: liveDragOffset = -viewportWidth
//   - right commit target: liveDragOffset = +viewportWidth
//
// After a successful commit and the parent's selectedDate
// rebuild the Row is reset to `liveDragOffset == 0`. Since the
// parent passes a different `currentPage` widget whose dates
// have already advanced, no second visible slide is needed.
//
// Adjacent pages are wrapped in `IgnorePointer` so their
// surfaces cannot open Event details, move or resize Events,
// or create empty-time Events. Only the centered current page
// owns the existing pinch recognizer; the D2 pinch coordinator
// remains authoritative regardless of which column the pointers
// land on.
//
// DayFlow is referenced only as an interaction concept (side-by-
// side pages, finger-following drag, settle one page on release,
// recenter on date change). No code, layout, or styling is
// copied from that source.

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_shared_viewport.dart';

/// Minimum logical-pixel travel before a horizontal gesture
/// can be considered for page navigation. Phase 8 minimum.
const double kPlannerPagerMinDistance = 64;

/// Explicit named velocity contract: release velocity in
/// logical PIXELS PER SECOND at pointer-up that allows a
/// deliberately fast fling shorter than the distance threshold
/// to commit one day. The Phase 4 contract is unambiguous:
/// `0.7 logical pixels per millisecond` == `700 logical pixels
/// per second`. Tests reference the named constant directly so
/// future value changes cannot silently shift the contract.
const double kPlannerPagerCommitVelocityPixelsPerSecond = 700.0;

/// Internal storage unit for [commitVelocity] (logical pixels
/// per millisecond). Derived once from
/// [kPlannerPagerCommitVelocityPixelsPerSecond] for tight-loop
/// comparisons; the published contract remains pixels/second.
final double _commitVelocityPixelsPerMillisecond =
    kPlannerPagerCommitVelocityPixelsPerSecond / 1000.0;

/// Direction-lock distance (logical pixels) before the pager
/// claims the gesture for horizontal paging. While within
/// this distance of the start, the underlying vertical scroll
/// recognizer is still allowed to operate.
const double kPlannerPagerDirectionLockDistance = 10;

/// Horizontal-dominance ratio: once the gesture has moved
/// further than the direction-lock distance, the pager only
/// takes over when |dx| > |dy| * 1.10.
const double kPlannerPagerHorizontalDominanceRatio = 1.10;

/// Fraction of viewport width whose release past the threshold
/// is sufficient to commit one day. Phase 8 default.
const double kPlannerPagerDistanceFraction = 0.22;

/// Absolute floor for the distance threshold in logical pixels.
/// Phase 8 minimum.
const double kPlannerPagerAbsoluteMinDistance = 72.0;

/// Settle animation duration, per Phase 9.
const Duration kPlannerPagerSettleDuration = Duration(milliseconds: 240);

/// Narrow command surface that the parent Planner screen uses to
/// invoke the pager from outside its widget tree.
///
/// The controller replaces the previous unsafe
/// `GlobalKey<State> _pagerKey` design. The pager's own
/// [State] class is library-private
/// (`_PlannerInteractiveDayPagerState`); the controller exposes
/// only a single recenter command so the parent does not need
/// any type from the private State, dynamic invocation, or a
/// `BuildContext` lookup. Attach happens automatically via
/// [PlannerInteractiveDayPager] when it mounts; the pager
/// detaches itself when it disposes.
///
/// The controller is intentionally not a [ChangeNotifier] —
/// it is a plain mutable object that the parent reads/writes
/// synchronously. The pager's animation and rebuild lifecycle
/// remain driven by the pager's own animation controller, so
/// no external listener bookkeeping is required.
class PlannerInteractiveDayPagerController {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  /// Normalized live pager progress shared with the Planner date strip.
  ///
  /// `0` is the centered current page, `-1` fully exposes the next page, and
  /// `+1` fully exposes the previous page. The pager owns writes; consumers
  /// such as the date strip only listen and transform from this value.
  ValueListenable<double> get progress => _progress;

  void _setProgress(double value) {
    _progress.value = value.clamp(-1.0, 1.0).toDouble();
  }

  /// The most recently attached recenter callback. The pager
  /// holds a private implementation in
  /// [_PlannerInteractiveDayPagerState]; the controller does
  /// not know about the State type.
  VoidCallback? _recenter;

  /// The pager's [recenterFromExternalCancel] entry point.
  ///
  /// The parent registers this method with the
  /// `_DaySwipeCoordinator` cancel listener so a competing
  /// recognizer (long-press move, vertical drag, pinch scale)
  /// can drop a pending pager gesture and animate back to the
  /// centered resting position.
  ///
  /// The method is a no-op when:
  ///   * the pager has not been attached yet (first build has
  ///     not happened);
  ///   * the pager has been disposed (the attached reference
  ///     is cleared on disposal).
  void recenterFromExternalCancel() {
    _recenter?.call();
  }

  /// Wire the controller's recenter callback. Called from the
  /// pager's [State.initState] and [State.didUpdateWidget] when
  /// the same controller instance is provided; called from
  /// [State.dispose] when the widget is torn down. The
  /// controller does not own any timers or listeners, so there
  /// is nothing to release in [dispose].
  void _attach(VoidCallback callback) {
    _recenter = callback;
  }

  /// Drop the recenter callback. Called from [State.dispose].
  /// Subsequent calls to [recenterFromExternalCancel] are
  /// silent no-ops until a new pager attaches.
  void _detach(VoidCallback callback) {
    if (identical(_recenter, callback)) {
      _recenter = null;
    }
  }

  /// Release the notifier owned by this controller. The Planner screen owns
  /// the controller for the route lifetime; standalone pager tests may also
  /// call this when they create a controller explicitly.
  void dispose() {
    _recenter = null;
    _progress.dispose();
  }
}

/// Vertical extent of the current-time indicator Row. Must
/// match the locked constant in the existing planner code.
const double kPlannerPagerCurrentTimeIndicatorHeight = 12;

/// Time-column width (must match the locked constant in the
/// existing `_TimedEventTimeline` widget).
const double kPlannerPagerTimeColumnWidth = 56;

/// Format a `DateTime` to the 12-hour AM/PM string the
/// centered column's current-time label uses. Replicated
/// inline because the same formatter is private to the
/// planner screen module; the formatted text is the only
/// fact that crosses the module boundary.
String _formatCurrentTimeLabel(DateTime now) {
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

String _hourLabel(int hour24, bool use24HourTime) {
  if (use24HourTime) {
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

/// Active session of a horizontal page gesture.
class _PageDragSession {
  _PageDragSession({required this.startPosition, required this.startTime});

  final Offset startPosition;
  final Duration startTime;

  /// True once the pager has accepted ownership of the gesture
  /// (direction locked + horizontal dominance). Before true,
  /// the parent recognizer (vertical scroll, pinch, long-press,
  /// resize) keeps operating and the pager does not paint a
  /// translated transform.
  bool horizontalIntentLocked = false;

  /// Latest accumulated dx in logical pixels. Drives the
  /// live Transform.translate (via
  /// `-viewportWidth + sessionDx`).
  double sessionDx = 0;
}

/// Optional plug-points so the parent can wire the pager into
/// the existing `_DaySwipeCoordinator` and `_PinchCoordinator`
/// without exporting the underlying types. Each callback is
/// invoked once per relevant pointer event; the parent decides
/// how to forward to its private coordinators.
typedef SwipeCoordinatorOnDown = void Function();
typedef SwipeCoordinatorOnUp = void Function();
typedef SwipeCoordinatorCancel = void Function();

/// Reports the active pointer count after the parent's pinch
/// coordinator has been updated. Values `>= 2` indicate pinch
/// authority. Returning the count (rather than a one-shot
/// transition flag) lets the pager detect simultaneous and
/// racing pointer-down events without depending on whether
/// the parent's Listener ran before or after this widget's
/// Listener.
typedef PinchCoordinatorOnCount = int Function();
typedef PinchCoordinatorClearCancel = void Function();

/// State for the pager. Owns the settle animation and the
/// per-gesture drag session. Library-private: only the
/// [PlannerInteractiveDayPager] widget and its in-file
/// controller can reference this type. External callers
/// communicate with the pager through
/// [PlannerInteractiveDayPagerController.recenterFromExternalCancel].
class _PlannerInteractiveDayPagerState extends State<PlannerInteractiveDayPager>
    with SingleTickerProviderStateMixin {
  _PageDragSession? _dragSession;

  /// The settle animation. Created eagerly in [initState] so
  /// [dispose] is the sole owner of its lifetime; the previous
  /// `late final` initializer would lazily construct the
  /// controller the first time `_settle` was touched, and that
  /// could land during teardown when [vsync] access through
  /// the deactivated element tree is unsafe.
  AnimationController? _settle;

  /// Pixel view of the controller's normalized progress. The controller is
  /// the single authoritative value; this getter only converts it to the
  /// current viewport's logical pixels for the existing settlement math and
  /// compatibility accessors.
  double get _liveDragOffset =>
      widget.controller.progress.value * widget.viewportWidth;

  void _setLiveDragOffset(double value) {
    if (widget.viewportWidth <= 0) {
      widget.controller._setProgress(0);
      return;
    }
    widget.controller._setProgress(value / widget.viewportWidth);
  }

  /// True while the settle animation is running. During this
  /// window a fresh pointer-down is rejected so a mid-settle
  /// flick cannot chain into a second commit.
  bool _settling = false;

  /// Live drag-offset accessor for tests. Not part of the
  /// public production contract.
  double get liveDragOffsetForTest =>
      widget.controller.progress.value * widget.viewportWidth;

  /// External cancel entry point. The parent registers this
  /// with the shared `_DaySwipeCoordinator`'s cancel-listener
  /// so a competing recognizer (long-press, vertical drag,
  /// pinch scale) can drop a pending pager gesture and
  /// animate back to center. No-op when no session is
  /// active or the pager is already centered. Safe to call
  /// after [dispose] because it short-circuits on `!mounted`.
  void recenterFromExternalCancel() {
    if (!mounted) {
      return;
    }
    _dragSession = null;
    if (_settling) {
      return;
    }
    if (_liveDragOffset.abs() < 0.5) {
      if (_liveDragOffset != 0) {
        setState(() {
          _setLiveDragOffset(0);
        });
      }
      return;
    }
    unawaited(_animateRecenter());
  }

  @override
  void initState() {
    super.initState();
    widget.controller._setProgress(0);
    _settle = AnimationController(
      vsync: this,
      duration: kPlannerPagerSettleDuration,
    );
    widget.controller._attach(recenterFromExternalCancel);
    widget.onPinchClearCancel();
  }

  @override
  void didUpdateWidget(covariant PlannerInteractiveDayPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(recenterFromExternalCancel);
      widget.controller._attach(recenterFromExternalCancel);
    }
    if (oldWidget.viewportWidth != widget.viewportWidth) {
      // Keep the transform aligned to the visible window when
      // the layout changes (rotation, resize). The pager only
      // needs to ensure the centered column stays centered.
      if (!_settling && _dragSession == null) {
        _setLiveDragOffset(0);
      }
    }
    if (oldWidget.selectedDate != widget.selectedDate) {
      // Parent has rebuilt with the new date — reset the
      // transform so the (now-different) currentPage is
      // recentered without a second visible slide.
      if (!_settling && _dragSession == null) {
        _setLiveDragOffset(0);
      }
    }
  }

  @override
  void dispose() {
    widget.controller._detach(recenterFromExternalCancel);
    _settle?.dispose();
    _settle = null;
    super.dispose();
  }

  double _commitDistanceThreshold(double viewportWidth) {
    final fraction = viewportWidth * kPlannerPagerDistanceFraction;
    return fraction > kPlannerPagerAbsoluteMinDistance
        ? fraction
        : kPlannerPagerAbsoluteMinDistance;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_settling) {
      return;
    }
    widget.onSwipePointerDown();
    final pinchCount = widget.onPinchPointerCount();
    if (pinchCount >= 2) {
      // Pinch owns the gesture. Drop any in-progress drag
      // session and stay centered. The parent observer will
      // rebuild the SingleChildScrollView physics through its
      // own pinch listener.
      _dragSession = null;
      if (_liveDragOffset != 0) {
        unawaited(_animateRecenter());
      }
      return;
    }
    _dragSession = _PageDragSession(
      startPosition: event.position,
      startTime: event.timeStamp,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final session = _dragSession;
    if (session == null) {
      return;
    }
    // A second pointer may have arrived between the previous
    // move and this one. The pinch coordinator's listener
    // lives inside the centered current page, which is
    // deeper in the tree than the pager, so its pointer-down
    // can dispatch after the pager's on the same frame.
    // Re-checking the count here means a pinch that arrives
    // late still wins the gesture.
    if (widget.onPinchPointerCount() >= 2) {
      _dragSession = null;
      if (_liveDragOffset != 0) {
        unawaited(_animateRecenter());
      }
      return;
    }
    final dx = event.position.dx - session.startPosition.dx;
    final dy = event.position.dy - session.startPosition.dy;
    final dxAbs = dx.abs();
    final dyAbs = dy.abs();
    if (!session.horizontalIntentLocked) {
      if (dxAbs < kPlannerPagerDirectionLockDistance &&
          dyAbs < kPlannerPagerDirectionLockDistance) {
        return;
      }
      if (dxAbs <= dyAbs * kPlannerPagerHorizontalDominanceRatio) {
        // Vertical-dominant motion; the parent recognizer
        // (vertical scroll / pinch / long-press / resize) owns
        // the gesture. Drop the session and stay centered.
        _dragSession = null;
        return;
      }
      // Horizontal paging has won the arena for this gesture.
      // Cancel the shared swipe coordinator so the long-press
      // move / resize / pinch hooks cannot also claim the
      // pointer.
      widget.onSwipeCancel();
      session.horizontalIntentLocked = true;
    }
    final maxOffset = widget.viewportWidth;
    final clampedDx = dx.clamp(-maxOffset, maxOffset);
    session.sessionDx = clampedDx;
    setState(() {
      _setLiveDragOffset(clampedDx);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    widget.onSwipePointerUp();
    widget.onPinchClearCancel();
    final session = _dragSession;
    if (session == null) {
      return;
    }
    _dragSession = null;
    if (!session.horizontalIntentLocked) {
      setState(() {
        _setLiveDragOffset(0);
      });
      return;
    }
    final dx = session.sessionDx;
    final elapsedMicroseconds =
        (event.timeStamp - session.startTime).inMicroseconds;
    final velocityX = elapsedMicroseconds == 0
        ? 0.0
        : (dx.abs() / (elapsedMicroseconds / 1000.0));
    final distanceThreshold = _commitDistanceThreshold(widget.viewportWidth);
    final passesDistance =
        dx.abs() >= distanceThreshold && dx.abs() >= kPlannerPagerMinDistance;
    final passesVelocity =
        velocityX >= _commitVelocityPixelsPerMillisecond && dx.abs() > 0;
    if ((passesDistance || passesVelocity) && dx != 0) {
      unawaited(_animateCommit(dx < 0 ? 1 : -1));
      return;
    }
    unawaited(_animateRecenter());
  }

  void _onPointerCancel(PointerCancelEvent event) {
    widget.onSwipePointerUp();
    widget.onPinchClearCancel();
    if (_dragSession == null) {
      return;
    }
    _dragSession = null;
    unawaited(_animateRecenter());
  }

  Future<void> _animateCommit(int delta) async {
    assert(delta == 1 || delta == -1);
    // Target the resting translation for the destination page
    // before the parent rebuild swaps the previous/current/next
    // dates. With the spec's coordinate model
    // (`translationX = -viewportWidth + liveDragOffset`), the
    // resting translation for the next page centered is
    // `-2 * viewportWidth` so `liveDragOffset` must equal
    // `-viewportWidth` at the end of a left commit
    // (`delta == +1`). Symmetrically a right commit
    // (`delta == -1`) lands on `liveDragOffset == +viewportWidth`.
    final target = delta < 0 ? widget.viewportWidth : -widget.viewportWidth;
    final from = _liveDragOffset;
    _settling = true;
    final settle = _settle!;
    final tween = Tween<double>(begin: from, end: target);
    final curved = CurvedAnimation(parent: settle, curve: Curves.easeOutCubic);
    final animation = tween.animate(curved);
    void listener() {
      if (!mounted) {
        return;
      }
      setState(() {
        _setLiveDragOffset(animation.value);
      });
    }

    animation.addListener(listener);
    try {
      settle.reset();
      await settle.forward().orCancel;
    } catch (_) {
      animation.removeListener(listener);
      rethrow;
    }
    animation.removeListener(listener);
    if (!mounted) {
      return;
    }
    // Keep the destination page fully exposed until the parent has prepared
    // the authoritative page data. The parent publishes selectedDate only
    // after that read completes; this prevents a new page key from painting
    // the previous day's schedule while the pager recenters.
    final commit = widget.onDayChanged(delta);
    try {
      if (commit is Future<void>) {
        await commit;
      }
    } on Object {
      // A failed adjacent read leaves the current page authoritative. Return
      // the settled translation to center without preparing the date strip
      // or publishing a second callback.
      if (mounted) {
        await _animateRecenter();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    // The strip and pager now hand off in one event turn: adjust its cached
    // scroll offset, recenter normalized progress, and expose the committed
    // page together. There is no second catch-up animation.
    widget.onPagerCommitPrepared?.call(delta);
    setState(() {
      _setLiveDragOffset(0);
    });
    _settling = false;
  }

  Future<void> _animateRecenter() async {
    final from = _liveDragOffset;
    if (from.abs() < 0.5) {
      setState(() {
        _setLiveDragOffset(0);
      });
      return;
    }
    _settling = true;
    final settle = _settle!;
    final tween = Tween<double>(begin: from, end: 0);
    final curved = CurvedAnimation(parent: settle, curve: Curves.easeOutCubic);
    final animation = tween.animate(curved);
    void listener() {
      if (!mounted) {
        return;
      }
      setState(() {
        _setLiveDragOffset(animation.value);
      });
    }

    animation.addListener(listener);
    try {
      settle.reset();
      await settle.forward().orCancel;
    } catch (_) {
      animation.removeListener(listener);
      rethrow;
    }
    animation.removeListener(listener);
    _settling = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _setLiveDragOffset(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final translationX = -viewportWidth + _liveDragOffset;
          return SizedBox(
            width: viewportWidth,
            height: widget.timelineHeight,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  Positioned(
                    key: const Key('planner-day-pager-strip-host'),
                    left: 0,
                    top: 0,
                    width: viewportWidth * 3,
                    height: widget.timelineHeight,
                    child: Transform.translate(
                      offset: Offset(translationX, 0),
                      key: const Key('planner-day-pager-strip'),
                      child: Row(
                        children: <Widget>[
                          _PagerPreviewColumn(
                            key: Key(
                              'planner-day-page-${widget.previousDate.iso8601}',
                            ),
                            pageDate: widget.previousDate,
                            pageDay: widget.previousDay,
                            settings: widget.settings,
                            hourHeight: widget.hourHeight,
                            width: viewportWidth,
                            isToday: widget.today == widget.previousDate,
                            currentTimeListenable: widget.currentTimeListenable,
                          ),
                          KeyedSubtree(
                            key: Key(
                              'planner-day-page-${widget.selectedDate.iso8601}',
                            ),
                            child: SizedBox(
                              width: viewportWidth,
                              height: widget.timelineHeight,
                              child: widget.currentPage,
                            ),
                          ),
                          _PagerPreviewColumn(
                            key: Key(
                              'planner-day-page-${widget.nextDate.iso8601}',
                            ),
                            pageDate: widget.nextDate,
                            pageDay: widget.nextDay,
                            settings: widget.settings,
                            hourHeight: widget.hourHeight,
                            width: viewportWidth,
                            isToday: widget.today == widget.nextDate,
                            currentTimeListenable: widget.currentTimeListenable,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Public entry point. Sits inside the Planner's
/// SingleChildScrollView above the existing
/// `_TimedEventTimeline`.
class PlannerInteractiveDayPager extends StatefulWidget {
  PlannerInteractiveDayPager({
    super.key,
    required this.selectedDate,
    required this.previousDate,
    required this.nextDate,
    required this.previousDay,
    required this.currentDay,
    required this.nextDay,
    required this.today,
    required this.settings,
    required this.hourHeight,
    required this.timelineHeight,
    required this.viewportWidth,
    required this.onSwipePointerDown,
    required this.onSwipePointerUp,
    required this.onSwipeCancel,
    required this.onPinchPointerCount,
    required this.onPinchClearCancel,
    required this.onDayChanged,
    this.onPagerCommitPrepared,
    required this.currentPage,
    required this.currentTimeListenable,
    PlannerInteractiveDayPagerController? controller,
  }) : controller = controller ?? PlannerInteractiveDayPagerController();

  final PlannerDate selectedDate;
  final PlannerDate previousDate;
  final PlannerDate nextDate;
  final PlannerDate today;

  /// Read-only snapshots for the previous, current, and next
  /// days. Preview snapshots must not be written to Drift
  /// from this widget — Phase 14.
  final PlannerDay? previousDay;
  final PlannerDay? currentDay;
  final PlannerDay? nextDay;

  final PlannerSettings settings;
  final double hourHeight;
  final double timelineHeight;
  final double viewportWidth;

  /// Authoritative current-time source shared with the
  /// centered timeline. The preview columns use this
  /// listenable to render the current-time indicator so the
  /// centered page and the preview pages read from the same
  /// instant — production keeps a minute-boundary Timer; the
  /// focused tests inject a deterministic
  /// [ValueListenable] to drive ownership, geometry, and
  /// midnight transition checks.
  final ValueListenable<DateTime> currentTimeListenable;

  /// External command surface. The parent may either pass its
  /// own controller instance (so a long-lived
  /// [PlannerInteractiveDayPagerController] can hold a stable
  /// reference to the live pager) or omit it (the pager
  /// creates an internal one for tests). The screen owns a
  /// single long-lived controller instance for the lifetime
  /// of the Planner route.
  final PlannerInteractiveDayPagerController controller;

  final SwipeCoordinatorOnDown onSwipePointerDown;
  final SwipeCoordinatorOnUp onSwipePointerUp;
  final SwipeCoordinatorCancel onSwipeCancel;

  final PinchCoordinatorOnCount onPinchPointerCount;
  final PinchCoordinatorClearCancel onPinchClearCancel;

  /// Fired exactly once per successful commit, with `+1` for a
  /// left swipe (next day) and `-1` for a right swipe (previous
  /// day). The parent wires this to
  /// `PlannerController.moveDays(delta)`.
  final FutureOr<void> Function(int) onDayChanged;

  /// Called once after a successful settlement reaches its destination and
  /// before progress is reset. The date strip uses this one synchronous hook
  /// to advance its cached scroll offset by one cell; cancellation never calls
  /// it.
  final FutureOr<void> Function(int)? onPagerCommitPrepared;

  /// The interactive current page (typically the existing
  /// `_TimedEventTimeline` widget). Receives pointer events
  /// for normal vertical scrolling and pinch when the pager is
  /// at rest or vertically-dominant.
  final Widget currentPage;

  /// Build a viewport snapshot for tests and the surrounding
  /// state. Reads from the planner's existing facts only — no
  /// derived controllers, no Drift writes.
  PlannerSharedViewport captureViewport({
    required ScrollController scrollController,
  }) {
    return PlannerSharedViewport.from(
      hourHeight: hourHeight,
      scrollController: scrollController,
      settings: settings,
      viewportHeight: timelineHeight,
    );
  }

  @override
  State<PlannerInteractiveDayPager> createState() =>
      _PlannerInteractiveDayPagerState();
}

/// Read-only preview column used for the previous and next day
/// pages. Renders a static hour grid and a representation of
/// the day's Calendar Events using the same vertical layout as
/// the centered timeline, without any recognizers that could
/// open Event details or commit a mutation.
class _PagerPreviewColumn extends StatelessWidget {
  const _PagerPreviewColumn({
    super.key,
    required this.pageDate,
    required this.pageDay,
    required this.settings,
    required this.hourHeight,
    required this.width,
    required this.isToday,
    required this.currentTimeListenable,
  });

  final PlannerDate pageDate;
  final PlannerDay? pageDay;
  final PlannerSettings settings;
  final double hourHeight;
  final double width;
  final bool isToday;

  /// Authoritative current-time source shared with the
  /// centered timeline. The preview column uses this
  /// listenable (not `DateTime.now()` directly) so the
  /// centered indicator and the preview indicators render
  /// from the same instant.
  final ValueListenable<DateTime> currentTimeListenable;

  @override
  Widget build(BuildContext context) {
    final firstHour = settings.visibleStartHour;
    final lastHour = settings.visibleEndHour;
    final slotCount = lastHour - firstHour;
    final pixelsPerMinute = PlannerTimelineGeometry.pixelsPerMinute(hourHeight);
    final visibleStart = firstHour * 60;
    final visibleEnd = lastHour * 60;
    final events = (pageDay?.timedEvents ?? const <PlannerCalendarItem>[])
        .where(
          (event) =>
              event.startLocal != null &&
              event.endLocal != null &&
              (settings.showCancelledItems ||
                  event.state != PlannerEventState.cancelled),
        )
        .toList(growable: false);
    final placements = PlannerTimelineLayout.arrange(events);
    final contentWidth = width - kPlannerPagerTimeColumnWidth - 8.0;
    return SizedBox(
      width: width,
      height: slotCount * hourHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var index = 0; index <= slotCount; index++) ...<Widget>[
            Positioned(
              top: index * hourHeight - 7,
              left: 0,
              width: kPlannerPagerTimeColumnWidth,
              child: Text(
                _hourLabel(firstHour + index, settings.use24HourTime),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xB3FFFFFF),
                ),
              ),
            ),
            Positioned(
              key: Key('planner-pager-full-hour-line-${firstHour + index}'),
              top: index * hourHeight,
              left: kPlannerPagerTimeColumnWidth,
              right: 0,
              child: const Divider(height: 1, color: AppTheme.outline),
            ),
          ],
          for (final placement in placements)
            _positionedPreviewEvent(
              placement: placement,
              contentWidth: contentWidth,
              pixelsPerMinute: pixelsPerMinute,
              visibleStart: visibleStart,
              visibleEnd: visibleEnd,
            ),
          // Preview columns are read-only. The actual
          // pointer suppression lives on each preview
          // block (every `_positionedPreviewEvent` wraps
          // its `DecoratedBox` in `IgnorePointer`) and on
          // the current-time `Row`. A bare
          // `Positioned.fill(child: IgnorePointer(child:
          // SizedBox.expand()))` would only disable its
          // own subtree — it does NOT block pointer events
          // from reaching the Event blocks drawn behind
          // it in this Stack, so it is intentionally not
          // used as a structural guard.
          //
          // Current-time indicator: read from the same
          // authoritative source as the centered timeline
          // so a focused test can drive minute, hour, and
          // date transitions deterministically. The
          // ValueListenableBuilder rebuilds only this
          // subtree on a minute tick.
          if (settings.showCurrentTime && isToday)
            ValueListenableBuilder<DateTime>(
              valueListenable: currentTimeListenable,
              builder: (context, now, _) {
                return _positionedCurrentTime(
                  now: now,
                  pixelsPerMinute: pixelsPerMinute,
                  visibleStart: visibleStart,
                  visibleEnd: visibleEnd,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _positionedPreviewEvent({
    required PlannerTimelinePlacement placement,
    required double contentWidth,
    required double pixelsPerMinute,
    required int visibleStart,
    required int visibleEnd,
  }) {
    final event = placement.event;
    final start = event.startLocal!;
    final end = event.endLocal!;
    final startMinute = start.hour * 60 + start.minute;
    final endMinute = end.hour * 60 + end.minute;
    final geometry = PlannerTimelineGeometry.event(
      startMinute: startMinute,
      endMinute: endMinute,
      visibleStartMinute: visibleStart,
      visibleEndMinute: visibleEnd,
      hourHeight: hourHeight,
    );
    final columnGap = (placement.columnCount > 1 ? 3.0 : 0.0);
    final blockWidth =
        (contentWidth - columnGap * (placement.columnCount - 1)) /
        placement.columnCount;
    final left =
        kPlannerPagerTimeColumnWidth +
        5 +
        placement.column * (blockWidth + columnGap);
    return Positioned(
      key: Key('planner-pager-preview-event-${event.id}'),
      top: geometry.top,
      left: left,
      width: blockWidth,
      height: geometry.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(event.activityTypeColorValue ?? 0xFFE91E63),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionedCurrentTime({
    required DateTime now,
    required double pixelsPerMinute,
    required int visibleStart,
    required int visibleEnd,
  }) {
    if (settings.showCurrentTime != true) {
      return const SizedBox.shrink();
    }
    final current = PlannerDate.fromDateTime(now);
    if (current != pageDate) {
      return const SizedBox.shrink();
    }
    if (now.hour < settings.visibleStartHour ||
        now.hour >= settings.visibleEndHour) {
      return const SizedBox.shrink();
    }
    final minuteFromVisibleStart =
        ((now.hour - settings.visibleStartHour) * 60) + now.minute;
    final resolvedMinuteY = minuteFromVisibleStart * pixelsPerMinute;
    final resolvedIndicatorTop =
        resolvedMinuteY - kPlannerPagerCurrentTimeIndicatorHeight / 2;
    return Positioned(
      key: const Key('planner-current-time-indicator'),
      top: resolvedIndicatorTop,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: kPlannerPagerCurrentTimeIndicatorHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: kPlannerPagerTimeColumnWidth - 8,
                child: Text(
                  _formatCurrentTimeLabel(now),
                  key: const Key('planner-current-time-label'),
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
                key: const Key('planner-current-time-dot'),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.rose,
                  shape: BoxShape.circle,
                ),
              ),
              const Expanded(
                child: SizedBox(
                  key: Key('planner-current-time-line'),
                  height: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppTheme.rose),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reference the [PlannerSharedViewport.empty] constant so the
/// shared-viewport file is reachable from anywhere that imports
/// this pager; useful for focused tests that build both widgets
/// in the same harness.
// ignore: unused_element
const PlannerSharedViewport _kEmpty = PlannerSharedViewport.empty;
