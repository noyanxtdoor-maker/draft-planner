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
  final sheetController = DraggableScrollableController();
  const minChildSize = 0.36;
  const maxChildSize = 0.94;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 260),
      reverseDuration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (sheetContext) {
      final sheet = DraggableScrollableSheet(
        key: const Key('calendar-event-draggable-sheet'),
        controller: sheetController,
        initialChildSize: 0.40,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        expand: false,
        builder: (context, scrollController) => sourceTaskId == null
            ? CalendarEventFormScreen.create(
                initialDate: date,
                initialEventType: eventType,
                initialStartMinute: startMinute,
                initialIndicatorKey: indicatorKey,
                initialEventTypeId: eventType.id,
                sheetPresentation: true,
                sheetScrollController: scrollController,
                sheetController: sheetController,
                sheetMinChildSize: minChildSize,
                sheetMaxChildSize: maxChildSize,
              )
            : CalendarEventFormScreen.createFromTask(
                sourceTaskId: sourceTaskId,
                initialDate: date,
                initialEventType: eventType,
                initialStartMinute: startMinute,
                initialIndicatorKey: indicatorKey,
                initialEventTypeId: eventType.id,
                sheetPresentation: true,
                sheetScrollController: scrollController,
                sheetController: sheetController,
                sheetMinChildSize: minChildSize,
                sheetMaxChildSize: maxChildSize,
              ),
      );
      final routeAnimation = ModalRoute.of(sheetContext)?.animation;
      if (routeAnimation == null) {
        return sheet;
      }
      return FadeTransition(
        key: const Key('calendar-event-form-entrance-fade'),
        opacity: CurvedAnimation(
          parent: routeAnimation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: sheet,
      );
    },
  ).whenComplete(sheetController.dispose);
}
