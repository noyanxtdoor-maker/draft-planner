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

  /// The first six Event Types are the only ones whose WLI relationship and
  /// reporting requirement are system-owned. Their stable IDs and mappings
  /// must remain intact when their display labels are renamed.
  bool get isLockedWliType =>
      isSystem &&
      exactIndicatorKey != null &&
      SystemEventTypeKeys.lockedWliTypeKeys.contains(stableKey);

  /// Event Types shown by the new-event picker and the default-type setting.
  /// Legacy system rows remain in storage for existing events and history.
  bool get isCreationVisible =>
      !isArchived &&
      // Retired M6 per-Goal types remain readable for historical Events, but
      // cannot be selected for new work under the canonical slot model.
      !stableKey.startsWith('goal:') &&
      (!isSystem ||
          SystemEventTypeKeys.approvedCreationKeys.contains(stableKey));

  bool get isLegacySystemType =>
      isSystem && !SystemEventTypeKeys.approvedCreationKeys.contains(stableKey);
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
  static const String other = 'other';
  static const String teaching = 'teaching';
  static const String finding = 'finding';
  static const String meeting = 'meeting';
  static const String studyOrPlan = 'study_or_plan';
  static const String service = 'service';
  static const String templeVisit = 'temple_visit';
  static const String scriptureStudy = 'scripture_study';
  static const String exercise = 'exercise';
  static const String budgetReview = 'budget_review';
  static const String jobApplication = 'job_application';
  static const String meaningfulConnection = 'meaningful_connection';
  static const String contact = 'contact';
  static const String appointment = 'appointment';
  static const String work = 'work';
  static const String travel = 'travel';
  static const String meal = 'meal';
  static const String personal = 'personal';

  static const Set<String> lockedWliTypeKeys = <String>{
    jobApplication,
    scriptureStudy,
    exercise,
    budgetReview,
    meaningfulConnection,
    templeVisit,
  };

  static const List<String> approvedCreationOrder = <String>[
    jobApplication,
    scriptureStudy,
    exercise,
    budgetReview,
    meaningfulConnection,
    templeVisit,
    contact,
    meeting,
    studyOrPlan,
    service,
    work,
    travel,
    meal,
    other,
  ];

  static const Set<String> approvedCreationKeys = <String>{
    ...approvedCreationOrder,
  };
}

abstract final class SystemEventTypeIds {
  static const String general = '30a9e940-d60b-5aad-b6d2-c8d593207cd7';
  static const String other = 'f0b6a2a4-9f33-5c9d-9c44-1d35ab6a10d1';
  static const String teaching = 'f1c7b3b5-a044-5d9e-a355-2e46bc7b21e2';
  static const String finding = 'f2d8c4c6-b155-5eaf-b466-3f57cd8c32f3';
  static const String meeting = 'f3e9d5d7-c266-5fb0-c577-4068de9d4304';
  static const String studyOrPlan = 'f4fad6e8-d377-50c1-d688-5179efae5415';
  static const String service = 'f5abd7f9-e488-51d2-e799-628af0fb6526';
  static const String templeVisit = '7bc431df-5342-58b1-afd2-637b51cc7a31';
  static const String scriptureStudy = '87c117aa-3e02-5c44-9bc0-0cf15939c5c2';
  static const String exercise = 'e4e41e9e-c028-5c73-b2a9-9d08ff3ca092';
  static const String budgetReview = 'd4d30b5d-d8cb-57d4-a103-f7f507b00f9e';
  static const String jobApplication = '4b5de2bd-a9fb-5bf1-924a-cd9c5790dfd8';
  static const String meaningfulConnection =
      '86a4b5d2-d67f-5437-8a68-1202af4d58a7';
  static const String contact = '6e54f5c9-30e1-5fb0-9a4f-4c53a4f835d1';
  static const String appointment = 'dc4880b7-80c7-54c2-b84f-28241bccb25c';
  static const String work = 'd14bc2d7-7ab6-5c70-afd6-a27770e567a4';
  static const String travel = 'f6bce8fa-f599-52e3-f8aa-739b0f1c7637';
  static const String meal = 'f7cdf9fb-0aaa-53f4-a9bb-84ac102d8748';
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
