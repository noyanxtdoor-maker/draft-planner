import 'package:rmplanner/features/planner/domain/planner_view.dart';

enum PlannerInitialScrollBehavior { currentTime, visibleStart, dayStart }

enum EventCreationPresentation { fullScreen, sheet }

final class PlannerSettings {
  const PlannerSettings({
    required this.defaultDurationMinutes,
    required this.visibleStartHour,
    required this.visibleEndHour,
    required this.use24HourTime,
    required this.snapMinutes,
    required this.showCurrentTime,
    required this.initialScrollBehavior,
    required this.creationPresentation,
    required this.quickEditEnabled,
    required this.showCompletedItems,
    required this.showCancelledItems,
    required this.weekStartDay,
    required this.preferredPresentation,
    required this.contentFilters,
    required this.timelineHourHeight,
    this.defaultEventTypeId,
    this.defaultReminderMinutes,
  });

  const PlannerSettings.defaults()
    : defaultEventTypeId = null,
      defaultDurationMinutes = 60,
      defaultReminderMinutes = null,
      visibleStartHour = 6,
      visibleEndHour = 22,
      use24HourTime = false,
      snapMinutes = 15,
      showCurrentTime = true,
      initialScrollBehavior = PlannerInitialScrollBehavior.currentTime,
      creationPresentation = EventCreationPresentation.sheet,
      quickEditEnabled = true,
      showCompletedItems = true,
      showCancelledItems = false,
      weekStartDay = DateTime.monday,
      preferredPresentation = PlannerPresentation.day,
      contentFilters = const PlannerContentFilters.defaults(),
      timelineHourHeight = PlannerZoomPolicy.normalHourHeight;

  final String? defaultEventTypeId;
  final int defaultDurationMinutes;
  final int? defaultReminderMinutes;
  final int visibleStartHour;
  final int visibleEndHour;
  final bool use24HourTime;
  final int snapMinutes;
  final bool showCurrentTime;
  final PlannerInitialScrollBehavior initialScrollBehavior;
  final EventCreationPresentation creationPresentation;
  final bool quickEditEnabled;
  final bool showCompletedItems;
  final bool showCancelledItems;
  final int weekStartDay;
  final PlannerPresentation preferredPresentation;
  final PlannerContentFilters contentFilters;
  final double timelineHourHeight;

  PlannerSettings copyWith({
    String? defaultEventTypeId,
    bool clearDefaultEventType = false,
    int? defaultDurationMinutes,
    int? defaultReminderMinutes,
    bool clearDefaultReminder = false,
    int? visibleStartHour,
    int? visibleEndHour,
    bool? use24HourTime,
    int? snapMinutes,
    bool? showCurrentTime,
    PlannerInitialScrollBehavior? initialScrollBehavior,
    EventCreationPresentation? creationPresentation,
    bool? quickEditEnabled,
    bool? showCompletedItems,
    bool? showCancelledItems,
    int? weekStartDay,
    PlannerPresentation? preferredPresentation,
    PlannerContentFilters? contentFilters,
    double? timelineHourHeight,
  }) {
    return PlannerSettings(
      defaultEventTypeId: clearDefaultEventType
          ? null
          : defaultEventTypeId ?? this.defaultEventTypeId,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      defaultReminderMinutes: clearDefaultReminder
          ? null
          : defaultReminderMinutes ?? this.defaultReminderMinutes,
      visibleStartHour: visibleStartHour ?? this.visibleStartHour,
      visibleEndHour: visibleEndHour ?? this.visibleEndHour,
      use24HourTime: use24HourTime ?? this.use24HourTime,
      snapMinutes: snapMinutes ?? this.snapMinutes,
      showCurrentTime: showCurrentTime ?? this.showCurrentTime,
      initialScrollBehavior:
          initialScrollBehavior ?? this.initialScrollBehavior,
      creationPresentation: creationPresentation ?? this.creationPresentation,
      quickEditEnabled: quickEditEnabled ?? this.quickEditEnabled,
      showCompletedItems: showCompletedItems ?? this.showCompletedItems,
      showCancelledItems: showCancelledItems ?? this.showCancelledItems,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      preferredPresentation:
          preferredPresentation ?? this.preferredPresentation,
      contentFilters: contentFilters ?? this.contentFilters,
      timelineHourHeight: PlannerZoomPolicy.clamp(
        timelineHourHeight ?? this.timelineHourHeight,
      ),
    );
  }

  void validate() {
    if (defaultDurationMinutes < 15 || defaultDurationMinutes > 24 * 60) {
      throw ArgumentError.value(
        defaultDurationMinutes,
        'defaultDurationMinutes',
      );
    }
    if (visibleStartHour < 0 ||
        visibleStartHour > 23 ||
        visibleEndHour < 1 ||
        visibleEndHour > 24 ||
        visibleEndHour <= visibleStartHour) {
      throw ArgumentError('Visible end hour must be after start hour.');
    }
    if (!const <int>{5, 10, 15, 30, 60}.contains(snapMinutes)) {
      throw ArgumentError.value(snapMinutes, 'snapMinutes');
    }
    if (weekStartDay < DateTime.monday || weekStartDay > DateTime.sunday) {
      throw ArgumentError.value(weekStartDay, 'weekStartDay');
    }
    if (timelineHourHeight < PlannerZoomPolicy.minimumHourHeight ||
        timelineHourHeight > PlannerZoomPolicy.maximumHourHeight) {
      throw ArgumentError.value(timelineHourHeight, 'timelineHourHeight');
    }
  }
}
