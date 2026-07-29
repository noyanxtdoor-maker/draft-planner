enum EventTypeIcon {
  calendar,
  temple,
  scripture,
  exercise,
  budget,
  job,
  connection,
  appointment,
  work,
  personal,
}

final class EventType {
  const EventType({
    required this.id,
    required this.stableKey,
    required this.label,
    required this.icon,
    required this.colorValue,
    required this.isSystem,
    required this.isArchived,
    required this.reportRequiredDefault,
    required this.defaultDurationMinutes,
    required this.position,
    required this.mappingVersion,
    required this.indicatorKeys,
    this.defaultReminderMinutes,
  });

  final String id;
  final String stableKey;
  final String label;
  final EventTypeIcon icon;
  final int colorValue;
  final bool isSystem;
  final bool isArchived;
  final bool reportRequiredDefault;
  final int defaultDurationMinutes;
  final int? defaultReminderMinutes;
  final int position;
  final int mappingVersion;
  final Set<String> indicatorKeys;

  bool get hasExactIndicatorMapping => indicatorKeys.length == 1;

  String? get exactIndicatorKey =>
      hasExactIndicatorMapping ? indicatorKeys.single : null;
}

final class EventTypeDraft {
  const EventTypeDraft({
    required this.id,
    required this.label,
    required this.icon,
    required this.colorValue,
    required this.reportRequiredDefault,
    required this.defaultDurationMinutes,
    required this.indicatorKeys,
    this.defaultReminderMinutes,
  });

  final String id;
  final String label;
  final EventTypeIcon icon;
  final int colorValue;
  final bool reportRequiredDefault;
  final int defaultDurationMinutes;
  final int? defaultReminderMinutes;
  final Set<String> indicatorKeys;
}

abstract final class SystemEventTypeKeys {
  static const String general = 'general';
  static const String templeVisit = 'temple_visit';
  static const String scriptureStudy = 'scripture_study';
  static const String exercise = 'exercise';
  static const String budgetReview = 'budget_review';
  static const String jobApplication = 'job_application';
  static const String meaningfulConnection = 'meaningful_connection';
  static const String appointment = 'appointment';
  static const String work = 'work';
  static const String personal = 'personal';
}

abstract final class SystemEventTypeIds {
  static const String general = '30a9e940-d60b-5aad-b6d2-c8d593207cd7';
  static const String templeVisit = '7bc431df-5342-58b1-afd2-637b51cc7a31';
  static const String scriptureStudy = '87c117aa-3e02-5c44-9bc0-0cf15939c5c2';
  static const String exercise = 'e4e41e9e-c028-5c73-b2a9-9d08ff3ca092';
  static const String budgetReview = 'd4d30b5d-d8cb-57d4-a103-f7f507b00f9e';
  static const String jobApplication = '4b5de2bd-a9fb-5bf1-924a-cd9c5790dfd8';
  static const String meaningfulConnection =
      '86a4b5d2-d67f-5437-8a68-1202af4d58a7';
  static const String appointment = 'dc4880b7-80c7-54c2-b84f-28241bccb25c';
  static const String work = 'd14bc2d7-7ab6-5c70-afd6-a27770e567a4';
  static const String personal = 'c820ba2c-4455-5d91-b852-f5727bdb7a07';
}

const systemEventTypeIndicatorKeys = <String, String>{
  SystemEventTypeKeys.templeVisit: 'temple_visit',
  SystemEventTypeKeys.scriptureStudy: 'scripture_study',
  SystemEventTypeKeys.exercise: 'exercise',
  SystemEventTypeKeys.budgetReview: 'budget_review',
  SystemEventTypeKeys.jobApplication: 'job_applications',
  SystemEventTypeKeys.meaningfulConnection: 'meaningful_connections',
};
