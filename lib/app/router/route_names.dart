import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

abstract final class RouteNames {
  static const String startup = 'startup';
  static const String onboarding = 'onboarding';
  static const String recovery = 'recovery';
  static const String protectedContent = 'protected-content';
  static const String home = 'home';
  static const String planner = 'planner';
  static const String taskCreate = 'task-create';
  static const String taskDetail = 'task-detail';
  static const String taskEdit = 'task-edit';
  static const String taskLinkEvent = 'task-link-event';
  static const String taskCreateEvent = 'task-create-event';
  static const String taskReport = 'task-report';
  static const String calendarEventCreate = 'calendar-event-create';
  static const String calendarEventDetail = 'calendar-event-detail';
  static const String calendarEventEdit = 'calendar-event-edit';
  static const String calendarEventReschedule = 'calendar-event-reschedule';
  static const String calendarEventLinkTask = 'calendar-event-link-task';
  static const String calendarEventReport = 'calendar-event-report';
  static const String outcomeReportCreate = 'outcome-report-create';
  static const String outcomeReportCorrection = 'outcome-report-correction';
  static const String activityHistory = 'activity-history';
  static const String indicatorDetail = 'indicator-detail';
  static const String weeklyPlanningTargets = 'weekly-planning-targets';
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
  static const String tasks = '/tasks';
  static const String taskCreate = '/tasks/new';
  static const String calendarEvents = '/events';
  static const String calendarEventCreate = '/events/new';
  static const String reports = '/reports';
  static const String outcomeReportCreate = '/reports/new';
  static const String activityHistory = '/activity-history';
  static const String progress = '/progress';
  static const String weeklyPlanning = '/planner/weekly-planning';
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

  static String taskReport(String taskId) {
    return '$tasks/$taskId/report';
  }

  static String calendarEventReport(String eventId, PlannerDate originalDate) {
    return '${calendarEventDetail(eventId, originalDate)}/report';
  }

  static String outcomeReportCorrection(String reportId) {
    return '$reports/$reportId/correct';
  }

  static String indicatorDetail(String indicatorKey, PlannerDate periodStart) {
    return '$progress/metric/$indicatorKey?week=${periodStart.iso8601}';
  }

  static String weeklyPlanningTargets(
    PlannerDate periodStart, {
    String? indicatorKey,
  }) {
    final indicator = indicatorKey == null ? '' : '&indicator=$indicatorKey';
    return '$weeklyPlanning?week=${periodStart.iso8601}$indicator';
  }
}
