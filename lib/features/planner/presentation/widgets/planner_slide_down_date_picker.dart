// In-place Planner Date picker presentation.
//
// The Planner owns this overlay in its existing Stack. It is intentionally
// not a Navigator route: the Planner, date strip, viewport, zoom, and scroll
// state remain mounted and visually unchanged while the transparent barrier
// owns input.

import 'dart:async';

import 'package:flutter/material.dart';

final class PlannerDatePickerOverlay extends StatefulWidget {
  const PlannerDatePickerOverlay({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onCancel,
    required this.onConfirm,
    this.helpText = 'Select Planner date',
    super.key,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final VoidCallback onCancel;
  final ValueChanged<DateTime> onConfirm;
  final String helpText;

  @override
  State<PlannerDatePickerOverlay> createState() =>
      _PlannerDatePickerOverlayState();
}

final class _PlannerDatePickerOverlayState
    extends State<PlannerDatePickerOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 240);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late DateTime _selectedDate = widget.initialDate;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_closing) {
      return;
    }
    _closing = true;
    unawaited(
      _controller.reverse().whenComplete(() {
        if (mounted) {
          widget.onCancel();
        }
      }),
    );
  }

  void _confirm() {
    if (_closing) {
      return;
    }
    _closing = true;
    unawaited(
      _controller.reverse().whenComplete(() {
        if (mounted) {
          widget.onConfirm(_selectedDate);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topOffset = media.padding.top + kToolbarHeight;
    final maxHeight = (media.size.height - topOffset - 16).clamp(0.0, 640.0);

    return Positioned.fill(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            _dismiss();
          }
        },
        child: Stack(
          children: <Widget>[
            ModalBarrier(
              key: const Key('planner-date-picker-barrier'),
              color: Colors.transparent,
              dismissible: true,
              onDismiss: _dismiss,
              semanticsLabel: MaterialLocalizations.of(
                context,
              ).modalBarrierDismissLabel,
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: topOffset),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -1),
                    end: Offset.zero,
                  ).animate(_animation),
                  child: FadeTransition(
                    opacity: _animation,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: _PlannerDatePickerPanel(
                        initialDate: widget.initialDate,
                        selectedDate: _selectedDate,
                        firstDate: widget.firstDate,
                        lastDate: widget.lastDate,
                        helpText: widget.helpText,
                        onDateChanged: (value) => setState(() {
                          _selectedDate = value;
                        }),
                        onCancel: _dismiss,
                        onConfirm: _confirm,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PlannerDatePickerPanel extends StatelessWidget {
  const _PlannerDatePickerPanel({
    required this.initialDate,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
    required this.onDateChanged,
    required this.onCancel,
    required this.onConfirm,
  });

  final DateTime initialDate;
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('planner-date-picker-panel'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CalendarDatePicker(
            initialDate: initialDate,
            currentDate: selectedDate,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateChanged: onDateChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  key: const Key('planner-date-picker-cancel'),
                  onPressed: onCancel,
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  key: const Key('planner-date-picker-confirm'),
                  onPressed: onConfirm,
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const Key plannerDatePickerPanelKey = Key('planner-date-picker-panel');

/// Presents the same in-place Planner calendar for a draft-owned date.
///
/// The Planner keeps [PlannerDatePickerOverlay] mounted in its existing Stack;
/// forms use this transparent route wrapper so the exact panel, animation,
/// SafeArea offset, and Cancel/OK semantics are shared without changing the
/// Planner's selected date or viewport.
Future<DateTime?> showSharedPlannerDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  String helpText = 'Select Planner date',
}) {
  final navigator = Navigator.of(context);
  return showGeneralDialog<DateTime?>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, _, _) => Stack(
      children: <Widget>[
        PlannerDatePickerOverlay(
          initialDate: initialDate,
          firstDate: firstDate ?? DateTime(1900),
          lastDate: lastDate ?? DateTime(2200, 12, 31),
          helpText: helpText,
          onCancel: () => navigator.pop(),
          onConfirm: (value) => navigator.pop(value),
        ),
      ],
    ),
  );
}
