import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

abstract final class RouteNames {
  static const String startup = 'startup';
  static const String onboarding = 'onboarding';
  static const String recovery = 'recovery';
  static const String protectedContent = 'protected-content';
  static const String home = 'home';
  static const String planner = 'planner';
  static const String more = 'more';
  static const String settings = 'settings';
  static const String colors = 'colors';
  static const String plannerEventColors = 'planner-event-colors';
  static const String taskCreate = 'task-create';
  static const String taskDetail = 'task-detail';
  static const String taskEdit = 'task-edit';
  static const String taskLinkEvent = 'task-link-event';
  static const String taskCreateEvent = 'task-create-event';
  static const String calendarEventCreate = 'calendar-event-create';
  static const String calendarEventDetail = 'calendar-event-detail';
  static const String calendarEventEdit = 'calendar-event-edit';
  static const String calendarEventReschedule = 'calendar-event-reschedule';
  static const String calendarEventLinkTask = 'calendar-event-link-task';
  static const String activityHistory = 'activity-history';
  static const String plannerSettings = 'planner-settings';
  static const String eventTypes = 'event-types';
  static const String eventTypeCreate = 'event-type-create';
  static const String eventTypeEdit = 'event-type-edit';
  static const String indicatorDetail = 'indicator-detail';
  static const String weeklyPlanning = 'weekly-planning';
  static const String weeklyPlanningTargets = 'weekly-planning-targets';
  static const String weeklyPlanningReview = 'weekly-planning-review';
  static const String weeklyPlanningHistory = 'weekly-planning-history';
  static const String privacyCenter = 'privacy-center';
  static const String permissions = 'permissions';
  static const String diagnosticPreview = 'diagnostic-preview';
}

abstract final class RoutePaths {
  static const String startup = '/startup';
  static const String onboarding = '/onboarding';
  static const String recovery = '/recovery';
  static const String protectedContent = '/protected';
  static const String home = '/home';
  static const String planner = '/planner';
  static const String more = '/more';
  static const String settings = '/more/settings';
  static const String colors = '/more/settings/colors';
  static const String plannerEventColors =
      '/more/settings/colors/planner-event-colors';
  static const String tasks = '/tasks';
  static const String taskCreate = '/tasks/new';
  static const String calendarEvents = '/events';
  static const String calendarEventCreate = '/events/new';
  static const String activityHistory = '/activity-history';
  static const String plannerSettings = '/planner/settings';
  static const String eventTypes = '/planner/settings/event-types';
  static const String eventTypeCreate = '/planner/settings/event-types/new';
  static const String progress = '/progress';
  static const String weeklyPlanning = '/planner/weekly-planning';
  static const String weeklyPlanningTargetsPath =
      '/planner/weekly-planning/targets';
  static const String weeklyPlanningHistory =
      '/planner/weekly-planning/history';
  static const String privacyCenter = '/privacy';
  static const String permissions = '/privacy/permissions';
  static const String diagnosticPreview = '/privacy/diagnostics';

  static String calendarEventDetail(String eventId, PlannerDate originalDate) {
    return '$calendarEvents/$eventId/${originalDate.iso8601}';
  }

  static String calendarEventEdit(
    String eventId,
    PlannerDate originalDate,
    CalendarEventEditScope scope,
  ) {
    return '${calendarEventDetail(eventId, originalDate)}/edit'
        '?scope=${scope.name}';
  }

  static String calendarEventReschedule(
    String eventId,
    PlannerDate originalDate,
    CalendarEventEditScope scope,
  ) {
    return '${calendarEventDetail(eventId, originalDate)}/reschedule'
        '?scope=${scope.name}';
  }

  static String indicatorDetail(String indicatorKey, PlannerDate periodStart) {
    return '$progress/metric/$indicatorKey?week=${periodStart.iso8601}';
  }

  static String weeklyPlanningTargets(
    PlannerDate periodStart, {
    String? indicatorKey,
  }) {
    final indicator = indicatorKey == null ? '' : '&indicator=$indicatorKey';
    return '$weeklyPlanningTargetsPath?week=${periodStart.iso8601}$indicator';
  }

  static String weeklyPlanningFor(PlannerDate periodStart) {
    return '$weeklyPlanning?week=${periodStart.iso8601}';
  }

  static String weeklyPlanningReview(String planId) {
    return '$weeklyPlanning/$planId/review';
  }
}
