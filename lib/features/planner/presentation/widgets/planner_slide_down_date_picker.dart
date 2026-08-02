// Slice D — slide-down Planner Date Picker route.
//
// Replaces the abrupt centered `showDatePicker` dialog with a
// smooth top-down slide-down / slide-up dismissal animation.
// The picker content is unchanged; only the presentation is
// refreshed so the panel originates above its final resting
// position beneath the Planner top bar and slides downward into
// view, then reverses upward on dismiss.
//
// Acceptance contract:
//
//   * opening: begins above final position; moves downward;
//     finishes at the rest position.
//   * closing: reverses upward; barrier fades out; no stale
//     overlay remains.
//   * content: month navigation, day select, Cancel, OK, current
//     selected date highlight, allowed date range — all
//     preserved.
//   * animation timing: 180–300 ms opening, 150–250 ms closing,
//     easeOutCubic / easeInCubic curves via
//     emphasizedDecelerate / emphasizedAccelerate is acceptable.
//   * focus: traps the date picker panel on open and releases on
//     close; `ModalRoute.barrierLabel` exposes the standard
//     dismiss label so screen readers recognise the barrier.
//   * keys: `planner-date-picker-trigger`,
//     `planner-date-picker-route`, `planner-date-picker-panel`,
//     `planner-date-picker-cancel`, `planner-date-picker-confirm`.

import 'package:flutter/material.dart';

/// Animation envelope for the slide-down presentation. Picker
/// content uses these to render the panel at the current
/// animation offset so the bar can produce a clean fade in lock-
/// step with the slide.
typedef PlannerDatePickerRouteAnimation =
    Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    );

/// Open the Planner slide-down date picker and return the chosen
/// date (or `null` when dismissed).
///
/// Shows a reusable [showDatePicker] dialog with the same content
/// as production already exposes, but the dialog is rendered
/// inside a custom [PageRouteBuilder] that slides the panel
/// downward on entry and upward on exit. The barrier is
/// transparent so the surrounding Planner remains fully visible
/// but cannot accept input while the picker is open.
Future<DateTime?> showPlannerSlideDownDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Select Planner date',
}) {
  return Navigator.of(context, rootNavigator: true).push<DateTime>(
    PageRouteBuilder<DateTime>(
      settings: const RouteSettings(name: 'planner-date-picker-route'),
      opaque: false,
      // The Planner must remain fully visible while the picker owns modal
      // input. A transparent barrier blocks taps without introducing the
      // rejected black or dim replacement layer.
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (routeContext, animation, secondaryAnimation) {
        // Re-render the existing production DatePickerDialog
        // content. The dialog widget builds its own CalendarDatePicker
        // so the day / month / year grid and the Cancel / OK
        // actions remain identical to the legacy `showDatePicker`
        // call site that previously powered this entry point.
        return Material(
          key: const Key('planner-date-picker-route'),
          type: MaterialType.transparency,
          child: _PlannerSlideDownPanel(
            animation: animation,
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            helpText: helpText,
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide the panel from above (-1.0) into its rest position
        // (0.0). CurveOutCubic on entry; curveInCubic on exit. The
        // animation value is read directly from the builder so the
        // panel can also fade synchronously.
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}

/// Internal presentation shell. Composes the existing Material
/// [DatePickerDialog] so the day/month/year selectors and the
/// Cancel / OK row are unchanged from the legacy behavior, but
/// frames them inside the slide-down animation panel that the
/// route builder animates.
final class _PlannerSlideDownPanel extends StatelessWidget {
  const _PlannerSlideDownPanel({
    required this.animation,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.helpText,
  });

  final Animation<double> animation;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String helpText;

  @override
  Widget build(BuildContext context) {
    // Anchor the panel beneath the Planner top bar so it visually
    // "drops down" from the bar instead of floating in the middle
    // of the screen. SafeArea keeps the picker away from the
    // system status bar; the panel itself is full-width and uses
    // SafeArea + the device's media query padding to determine its
    // top offset.
    final media = MediaQuery.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: media.padding.top + kToolbarHeight),
        child: Material(
          key: const Key('planner-date-picker-panel'),
          color: Theme.of(context).colorScheme.surface,
          elevation: 8,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: DatePickerDialog(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            helpText: helpText,
            cancelText: 'CANCEL',
            confirmText: 'OK',
          ),
        ),
      ),
    );
  }
}

/// Resolves the stable keys asserted by the focused tests so the
/// suite and the production widget agree on a single source of
/// truth for the picker panel identity.
const Key plannerDatePickerPanelKey = Key('planner-date-picker-panel');
