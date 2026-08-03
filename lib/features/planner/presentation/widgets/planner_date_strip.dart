import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// A finite, indexed date model for the Planner's horizontally browsable
/// date strip. The range matches the date picker bounds and is large enough
/// that normal historical and future navigation does not rebuild a tiny
/// rolling week window.
const PlannerDate kPlannerDateStripFirstDate = PlannerDate(
  year: 1900,
  month: 1,
  day: 1,
);
const PlannerDate kPlannerDateStripLastDate = PlannerDate(
  year: 2200,
  month: 12,
  day: 31,
);

/// Command surface used by the day pager to prepare the strip's internal
/// scroll position before the normalized pager progress is recentered.
///
/// The jump is intentionally one synchronous offset adjustment, not an
/// animation. The pager calls it while the destination page is fully exposed;
/// it then resets progress and commits the selected date in the same event
/// turn. That keeps the strip's visual hand-off seamless without a second
/// animation or a frame showing the old selection.
final class PlannerDateStripController {
  void Function(int)? _preparePagerCommit;

  void prepareForPagerCommit(int delta) {
    if (delta != -1 && delta != 1) {
      return;
    }
    _preparePagerCommit?.call(delta);
  }

  void _attach(void Function(int) callback) {
    _preparePagerCommit = callback;
  }

  void _detach(void Function(int) callback) {
    if (identical(_preparePagerCommit, callback)) {
      _preparePagerCommit = null;
    }
  }
}

final class PlannerDateStrip extends StatefulWidget {
  const PlannerDateStrip({
    super.key,
    required this.selectedDate,
    required this.onSelected,
    this.firstDate = kPlannerDateStripFirstDate,
    this.lastDate = kPlannerDateStripLastDate,
    this.pagerProgress,
    this.controller,
  });

  final PlannerDate selectedDate;
  final ValueChanged<PlannerDate> onSelected;
  final PlannerDate firstDate;
  final PlannerDate lastDate;

  /// One normalized pager progress value shared with the timeline pager:
  /// `0` is centered, negative values expose the next date, and positive
  /// values expose the previous date. The date items are transformed from
  /// this value only; the ListView and its cached children are not rebuilt for
  /// each pointer frame.
  final ValueListenable<double>? pagerProgress;

  /// Optional command surface used to preserve the strip's scroll position
  /// across a successful one-day pager commit.
  final PlannerDateStripController? controller;

  /// Compact fixed cell width. The strip keeps the same cell geometry at all
  /// selection states and leaves the top-bar calendar control independent.
  static const double itemExtent = 52;
  // Keep the date cells fixed-width while reducing the vertical footprint so
  // the first timeline hour has a clean, unobscured leading edge.
  static const double stripHeight = 36;

  @override
  State<PlannerDateStrip> createState() => _PlannerDateStripState();
}

final class _PlannerDateStripState extends State<PlannerDateStrip>
    with SingleTickerProviderStateMixin {
  static const double _edgePadding = 2;
  static const Duration _selectionAnimationDuration = Duration(
    milliseconds: 220,
  );
  static const Curve _selectionAnimationCurve = Curves.easeOutCubic;

  late final ScrollController _scrollController;
  late final AnimationController _selectionController;
  bool _initialPositioned = false;
  bool _visibilityScheduled = false;
  bool _pendingAnimatedVisibility = false;
  bool _pendingCenterVisibility = false;
  bool _pagerCommitPrepared = false;
  int? _selectionFromIndex;
  int? _selectionToIndex;
  bool _selectionStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectionController = AnimationController(
      vsync: this,
      duration: _selectionAnimationDuration,
    )..addStatusListener(_onSelectionAnimationStatus);
    widget.controller?._attach(_prepareForPagerCommit);
    _scheduleSelectedDateVisibility(animate: false, center: true);
  }

  @override
  void didUpdateWidget(covariant PlannerDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(_prepareForPagerCommit);
      widget.controller?._attach(_prepareForPagerCommit);
    }
    if (oldWidget.selectedDate != widget.selectedDate) {
      final pagerCommit = _pagerCommitPrepared;
      _pagerCommitPrepared = false;
      final oldIndex = _serialDay(
        oldWidget.selectedDate,
      ).clamp(0, _itemCount - 1).toInt();
      final newIndex = _selectedIndex();
      final tapAnimationOwnsTransition =
          _selectionFromIndex != null && _selectionToIndex == newIndex;
      if (pagerCommit) {
        _stopSelectionAnimation();
      } else if (!tapAnimationOwnsTransition && oldIndex != newIndex) {
        _startSelectionAnimation(from: oldIndex, to: newIndex);
      }
      _scheduleSelectedDateVisibility(animate: !pagerCommit, center: false);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(_prepareForPagerCommit);
    _selectionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSelectionAnimationStatus(AnimationStatus status) {
    if (!mounted || status != AnimationStatus.completed) {
      return;
    }
    setState(() {
      _selectionFromIndex = null;
      _selectionToIndex = null;
    });
  }

  void _stopSelectionAnimation() {
    _selectionController.stop();
    _selectionFromIndex = null;
    _selectionToIndex = null;
    _selectionStartScheduled = false;
  }

  void _startSelectionAnimation({required int from, required int to}) {
    if (from == to) {
      _stopSelectionAnimation();
      return;
    }
    _selectionFromIndex = from;
    _selectionToIndex = to;
    if (_selectionStartScheduled) {
      return;
    }
    _selectionStartScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionStartScheduled = false;
      if (!mounted || _selectionFromIndex != from || _selectionToIndex != to) {
        return;
      }
      unawaited(_selectionController.forward(from: 0));
    });
  }

  void _onDateSelected(PlannerDate date) {
    final target = _serialDay(date).clamp(0, _itemCount - 1).toInt();
    final from =
        _selectionFromIndex != null &&
            _selectionToIndex != null &&
            _selectionController.isAnimating
        ? (_selectionFromIndex! +
              (_selectionToIndex! - _selectionFromIndex!) *
                  _selectionController.value)
        : _selectedIndex().toDouble();
    _selectionFromIndex = from.round();
    _selectionToIndex = target;
    if (from.round() == target) {
      _stopSelectionAnimation();
    } else {
      _startSelectionAnimation(from: from.round(), to: target);
    }
    widget.onSelected(date);
  }

  int get _itemCount =>
      _serialDay(widget.lastDate) - _serialDay(widget.firstDate) + 1;

  int _serialDay(PlannerDate date) {
    return DateTime.utc(date.year, date.month, date.day)
        .difference(
          DateTime.utc(
            widget.firstDate.year,
            widget.firstDate.month,
            widget.firstDate.day,
          ),
        )
        .inDays;
  }

  PlannerDate _dateAt(int index) => widget.firstDate.addDays(index);

  int _selectedIndex() {
    final index = _serialDay(widget.selectedDate);
    return index.clamp(0, _itemCount - 1).toInt();
  }

  double _clampOffset(double offset) {
    if (!_scrollController.hasClients) {
      return offset;
    }
    return offset
        .clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        )
        .toDouble();
  }

  double _centeredOffset(int index) {
    final viewport = _scrollController.position.viewportDimension;
    return _clampOffset(
      index * PlannerDateStrip.itemExtent -
          (viewport - PlannerDateStrip.itemExtent) / 2,
    );
  }

  double? _visibilityOffset(int index) {
    final current = _scrollController.position.pixels;
    final viewport = _scrollController.position.viewportDimension;
    final leading = index * PlannerDateStrip.itemExtent;
    final trailing = leading + PlannerDateStrip.itemExtent;
    if (leading >= current + _edgePadding &&
        trailing <= current + viewport - _edgePadding) {
      return null;
    }
    if (leading < current + _edgePadding) {
      return _clampOffset(leading - _edgePadding);
    }
    return _clampOffset(trailing - viewport + _edgePadding);
  }

  void _prepareForPagerCommit(int delta) {
    if (!mounted) {
      return;
    }
    _pagerCommitPrepared = true;
    if (!_scrollController.hasClients) {
      _scheduleSelectedDateVisibility(animate: false, center: true);
      return;
    }
    final target = _clampOffset(
      _scrollController.position.pixels + delta * PlannerDateStrip.itemExtent,
    );
    if ((target - _scrollController.position.pixels).abs() >= 0.5) {
      _scrollController.jumpTo(target);
    }
  }

  void _scheduleSelectedDateVisibility({
    required bool animate,
    required bool center,
  }) {
    _pendingAnimatedVisibility = _pendingAnimatedVisibility || animate;
    _pendingCenterVisibility = _pendingCenterVisibility || center;
    if (_visibilityScheduled) {
      return;
    }
    _visibilityScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityScheduled = false;
      if (!mounted) {
        return;
      }
      if (!_scrollController.hasClients) {
        _scheduleSelectedDateVisibility(animate: animate, center: center);
        return;
      }
      final shouldAnimate = _pendingAnimatedVisibility;
      final shouldCenter = _pendingCenterVisibility;
      _pendingAnimatedVisibility = false;
      _pendingCenterVisibility = false;
      final index = _selectedIndex();
      if (!_initialPositioned) {
        _scrollController.jumpTo(_centeredOffset(index));
        _initialPositioned = true;
        return;
      }
      final target = shouldCenter
          ? _centeredOffset(index)
          : _visibilityOffset(index);
      if (target == null ||
          (target - _scrollController.position.pixels).abs() < 0.5) {
        return;
      }
      if (shouldAnimate) {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: _selectionAnimationDuration,
            curve: _selectionAnimationCurve,
          ),
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Widget _buildDateList(BuildContext context, double height) {
    return ListView.builder(
      key: const Key('planner-date-strip-scroll'),
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      itemCount: _itemCount,
      itemExtent: PlannerDateStrip.itemExtent,
      itemBuilder: (context, index) {
        final date = _dateAt(index);
        return _PlannerDateStripDayButton(
          date: date,
          selected: date == widget.selectedDate,
          onSelected: _onDateSelected,
          height: height,
        );
      },
    );
  }

  Widget _buildProgressDrivenDateList(BuildContext context, double height) {
    final dateList = _buildDateList(context, height);
    final progress = widget.pagerProgress;
    final listenables = <Listenable>[_scrollController, _selectionController];
    if (progress != null) {
      listenables.add(progress);
    }
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      child: dateList,
      builder: (context, child) {
        final pagerValue = progress?.value ?? 0;
        return Transform.translate(
          key: const Key('planner-date-strip-live-transform'),
          offset: Offset(pagerValue * PlannerDateStrip.itemExtent, 0),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('planner-week-strip'),
      width: double.infinity,
      height: PlannerDateStrip.stripHeight + 2,
      child: DecoratedBox(
        key: const Key('planner-date-strip-surface'),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(bottom: BorderSide(color: AppTheme.outline, width: 1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: SizedBox(
            height: PlannerDateStrip.stripHeight,
            child: ClipRect(
              child: _buildProgressDrivenDateList(
                context,
                PlannerDateStrip.stripHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _PlannerDateStripDayButton extends StatelessWidget {
  const _PlannerDateStripDayButton({
    required this.date,
    required this.selected,
    required this.onSelected,
    required this.height,
  });

  final PlannerDate date;
  final bool selected;
  final ValueChanged<PlannerDate> onSelected;
  final double height;

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
    final color = selected ? AppTheme.rose : const Color(0xB8FFFFFF);
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
        child: SizedBox(
          width: PlannerDateStrip.itemExtent,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _labels[date.weekday - 1],
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: color,
                      ),
                    ),
                    Text(
                      '${date.day}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
