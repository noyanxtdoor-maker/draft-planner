import 'dart:async';

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

final class PlannerDateStrip extends StatefulWidget {
  const PlannerDateStrip({
    super.key,
    required this.selectedDate,
    required this.onSelected,
    this.firstDate = kPlannerDateStripFirstDate,
    this.lastDate = kPlannerDateStripLastDate,
  });

  final PlannerDate selectedDate;
  final ValueChanged<PlannerDate> onSelected;
  final PlannerDate firstDate;
  final PlannerDate lastDate;

  /// Stable item width keeps index-to-offset calculations predictable while
  /// the selected date moves by one day after a pager commit.
  static const double itemExtent = 72;

  @override
  State<PlannerDateStrip> createState() => _PlannerDateStripState();
}

final class _PlannerDateStripState extends State<PlannerDateStrip> {
  static const double _edgePadding = 2;
  static const Duration _selectionAnimationDuration = Duration(
    milliseconds: 220,
  );
  static const Curve _selectionAnimationCurve = Curves.easeOutCubic;

  late final ScrollController _scrollController;
  bool _initialPositioned = false;
  bool _visibilityScheduled = false;
  bool _pendingAnimatedVisibility = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scheduleSelectedDateVisibility(animate: false);
  }

  @override
  void didUpdateWidget(covariant PlannerDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _scheduleSelectedDateVisibility(animate: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  void _scheduleSelectedDateVisibility({required bool animate}) {
    _pendingAnimatedVisibility = _pendingAnimatedVisibility || animate;
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
        _scheduleSelectedDateVisibility(animate: animate);
        return;
      }
      final shouldAnimate = _pendingAnimatedVisibility;
      _pendingAnimatedVisibility = false;
      final index = _selectedIndex();
      if (!_initialPositioned) {
        _scrollController.jumpTo(_centeredOffset(index));
        _initialPositioned = true;
        return;
      }
      final target = _visibilityOffset(index);
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

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // The two stacked labels do not scale linearly under Flutter's
    // nonlinear text scaler. Preserve the compact 54px strip at the
    // default scale, then reserve extra cross-axis space for the
    // combined label heights as accessibility text grows.
    final stripContentHeight = (54.0 + (textScale - 1).clamp(0.0, 2.0) * 90)
        .clamp(54.0, 150.0);
    return Container(
      key: const Key('planner-week-strip'),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: stripContentHeight,
        child: ListView.builder(
          key: const Key('planner-date-strip-scroll'),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          itemCount: _itemCount,
          itemExtent: PlannerDateStrip.itemExtent,
          itemBuilder: (context, index) {
            final date = _dateAt(index);
            return _PlannerDateStripDayButton(
              date: date,
              selected: date == widget.selectedDate,
              onSelected: widget.onSelected,
              height: stripContentHeight,
            );
          },
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
          height: height,
          padding: const EdgeInsets.symmetric(vertical: 4),
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
