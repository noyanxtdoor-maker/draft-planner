import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_form_screen.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';

final class CalendarEventCreationContext {
  const CalendarEventCreationContext({
    required this.source,
    required this.destinationPath,
    required this.date,
    this.startMinute,
    this.indicatorKey,
    this.recommendedEventTypeId,
    this.sourceTaskId,
  });

  final String source;
  final String destinationPath;
  final PlannerDate date;
  final int? startMinute;
  final String? indicatorKey;
  final String? recommendedEventTypeId;
  final String? sourceTaskId;
}

Future<T?> launchCalendarEventCreation<T>(
  BuildContext context,
  WidgetRef ref,
  CalendarEventCreationContext creationContext,
) async {
  final selected = await showEventTypePicker(
    context: context,
    ref: ref,
    recommendedEventTypeId: creationContext.recommendedEventTypeId,
    recommendedIndicatorKey: creationContext.indicatorKey,
  );
  if (selected == null || !context.mounted) {
    return null;
  }
  return showCalendarEventFormSheet<T>(
    context: context,
    eventType: selected,
    date: creationContext.date,
    startMinute: creationContext.startMinute,
    indicatorKey: creationContext.indicatorKey,
    sourceTaskId: creationContext.sourceTaskId,
  );
}

Future<T?> showCalendarEventFormSheet<T>({
  required BuildContext context,
  required EventType eventType,
  required PlannerDate date,
  int? startMinute,
  String? indicatorKey,
  String? sourceTaskId,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (sheetContext) => DraggableScrollableSheet(
      key: const Key('calendar-event-draggable-sheet'),
      initialChildSize: 0.86,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => sourceTaskId == null
          ? CalendarEventFormScreen.create(
              initialDate: date,
              initialStartMinute: startMinute,
              initialIndicatorKey: indicatorKey,
              initialEventTypeId: eventType.id,
              sheetPresentation: true,
              sheetScrollController: scrollController,
            )
          : CalendarEventFormScreen.createFromTask(
              sourceTaskId: sourceTaskId,
              initialDate: date,
              initialStartMinute: startMinute,
              initialIndicatorKey: indicatorKey,
              initialEventTypeId: eventType.id,
              sheetPresentation: true,
              sheetScrollController: scrollController,
            ),
    ),
  );
}
