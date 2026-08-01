// Slice D — shared calendar-icon definition.
//
// Phase 8 consolidates the calendar-icon design across the app. The
// Planner "Go to today" button must visually reuse the same calendar
// icon shown by the Home top bar. Concentrating the resolved icon
// data (glyph, size, defaults) here means the Planner and the Home
// surfaces share one definition; assertions then compare IconData
// equality rather than approximated widget trees.
//
// Historical reference: Home previously exposed `Icons.today_outlined`
// in its top-bar `IconButton` for "Open today in Planner". The
// Planner "Go to today" button previously used `Icons.calendar_month`.
// Slice D replaces the Planner glyph with the Home glyph so the two
// affordances reference one design. The color contrast (pink when
// selected date is today; on-surface otherwise) follows the existing
// Slice C contract.

import 'package:flutter/material.dart';

/// Resolve the calendar icon glyph and size used everywhere the
/// application surfaces the "today" affordance.
///
/// Single source of truth: both the Planner `planner-today-button`
/// and any future Home-side reference resolve to the same [IconData]
/// instance through this function. Tests pin equality by importing
/// and comparing the resolved value.
({IconData glyph, double size}) resolvePlannerCalendarIcon({double size = 22}) {
  return (glyph: Icons.today_outlined, size: size);
}

/// "Go to today" control surface.
///
/// Shared widget that renders the calendar icon inside the slice
/// established by [SurfaceTint.iconPadding]. The widget is the
/// painter; the parent supplies the semantic label, the tap
/// callback, the focused [Key], and the accent color that the
/// Slice C contract drives (pink when the selected date is today,
/// on-surface otherwise).
final class PlannerCalendarButtonSurface extends StatelessWidget {
  const PlannerCalendarButtonSurface({
    required this.onTap,
    required this.color,
    super.key,
  });

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolved = resolvePlannerCalendarIcon();
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        key: const Key('planner-today-button'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          key: const Key('planner-calendar-button'),
          width: 44,
          height: 44,
          child: Center(
            child: Icon(resolved.glyph, color: color, size: resolved.size),
          ),
        ),
      ),
    );
  }
}
