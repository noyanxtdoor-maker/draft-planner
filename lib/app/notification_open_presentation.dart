// Planner-first notification OPEN presentation.
//
// Owner-approved UX law: a notification OPEN must feel like "the notification
// brought me to this item in Planner". Routing lands on the Planner tab inside
// the MainShell (so status/navigation insets and shell chrome match a normal
// Planner visit) and the exact canonical preview widgets used by normal
// Planner taps are presented:
//   * Event -> CalendarEventDetailScreen(sheetPresentation: true), the shared
//     SharedPlannerPreviewSheet presenter used by showCalendarEventDetailSheet.
//   * Task  -> TaskPreviewSheet, the shared SharedPlannerPreviewSheet presenter
//     used by showTaskPreview.
// The geometry below mirrors those two show* functions exactly (fractional
// height, shared max width, same barrier), so notification entry and Planner
// entry are ONE presenter with ONE inset behavior.
import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_detail_screen.dart';
import 'package:rmplanner/features/planner/presentation/task_preview_sheet.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_detail_primitives.dart';

/// Presents the canonical Planner Event preview over the active shell.
Future<void> showNotificationEventPreview(
  BuildContext context, {
  required String eventId,
  required PlannerDate originalDate,
  String? initialHeading,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Event details',
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (sheetContext) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Align(
        alignment: AlignmentDirectional.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kPlannerPreviewSheetMaxWidth,
            ),
            child: CalendarEventDetailScreen(
              eventId: eventId,
              originalDate: originalDate,
              sheetPresentation: true,
              initialHeading: initialHeading,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Presents the canonical Planner Task preview over the active shell.
Future<void> showNotificationTaskPreview(
  BuildContext context, {
  required String taskId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Task details',
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (sheetContext) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Align(
        alignment: AlignmentDirectional.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kPlannerPreviewSheetMaxWidth,
            ),
            child: TaskPreviewSheet(taskId: taskId),
          ),
        ),
      ),
    ),
  );
}
