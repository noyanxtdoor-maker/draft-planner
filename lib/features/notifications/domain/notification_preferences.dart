enum QuietHoursDisposition { deliverNow, delayUntilEnd, suppress }

final class QuietHoursSettings {
  const QuietHoursSettings({
    required this.enabled,
    this.startMinute,
    this.endMinute,
  });

  const QuietHoursSettings.disabled()
    : enabled = false,
      startMinute = null,
      endMinute = null;

  final bool enabled;
  final int? startMinute;
  final int? endMinute;

  void validate() {
    if (!enabled) return;
    final start = startMinute;
    final end = endMinute;
    if (start == null || end == null) {
      throw ArgumentError('Enabled quiet hours require start and end times.');
    }
    if (start < 0 || start > 1439 || end < 0 || end > 1439) {
      throw ArgumentError('Quiet-hours minutes must be between 0 and 1439.');
    }
    if (start == end) {
      throw ArgumentError('Quiet-hours start and end must differ.');
    }
  }

  bool isInQuietHours(int localMinute) {
    if (localMinute < 0 || localMinute > 1439) {
      throw ArgumentError.value(localMinute, 'localMinute');
    }
    if (!enabled) return false;
    validate();
    final start = startMinute!;
    final end = endMinute!;
    return start < end
        ? localMinute >= start && localMinute < end
        : localMinute >= start || localMinute < end;
  }

  QuietHoursDisposition dispositionAt(
    int localMinute, {
    required bool remainsRelevantAtEnd,
  }) {
    if (!isInQuietHours(localMinute)) return QuietHoursDisposition.deliverNow;
    return remainsRelevantAtEnd
        ? QuietHoursDisposition.delayUntilEnd
        : QuietHoursDisposition.suppress;
  }

  @override
  bool operator ==(Object other) =>
      other is QuietHoursSettings &&
      enabled == other.enabled &&
      startMinute == other.startMinute &&
      endMinute == other.endMinute;

  @override
  int get hashCode => Object.hash(enabled, startMinute, endMinute);
}

final class NotificationPreferences {
  const NotificationPreferences({
    required this.systemNotificationsEnabled,
    required this.eventRemindersEnabled,
    required this.taskRemindersEnabled,
    this.weeklyReviewRemindersEnabled = false,
    this.awaitingReportRemindersEnabled = false,
    this.goalCompletionNotificationsEnabled = false,
    this.inAppGoalCelebrationsEnabled = true,
    required this.defaultTaskReminderMinutes,
    this.snoozeDurationMinutes = 10,
    required this.quietHours,
  });

  const NotificationPreferences.defaults()
    : systemNotificationsEnabled = false,
      eventRemindersEnabled = false,
      taskRemindersEnabled = false,
      weeklyReviewRemindersEnabled = false,
      awaitingReportRemindersEnabled = false,
      goalCompletionNotificationsEnabled = false,
      inAppGoalCelebrationsEnabled = true,
      defaultTaskReminderMinutes = null,
      snoozeDurationMinutes = 10,
      quietHours = const QuietHoursSettings.disabled();

  /// Next Transfer's master preference. This is intentionally distinct from
  /// the factual Android permission state, which is queried at runtime.
  final bool systemNotificationsEnabled;
  final bool eventRemindersEnabled;
  final bool taskRemindersEnabled;
  final bool weeklyReviewRemindersEnabled;
  final bool awaitingReportRemindersEnabled;
  final bool goalCompletionNotificationsEnabled;
  final bool inAppGoalCelebrationsEnabled;
  final int? defaultTaskReminderMinutes;
  final int snoozeDurationMinutes;
  final QuietHoursSettings quietHours;

  NotificationPreferences copyWith({
    bool? systemNotificationsEnabled,
    bool? eventRemindersEnabled,
    bool? taskRemindersEnabled,
    bool? weeklyReviewRemindersEnabled,
    bool? awaitingReportRemindersEnabled,
    bool? goalCompletionNotificationsEnabled,
    bool? inAppGoalCelebrationsEnabled,
    int? defaultTaskReminderMinutes,
    bool clearDefaultTaskReminder = false,
    int? snoozeDurationMinutes,
    QuietHoursSettings? quietHours,
  }) => NotificationPreferences(
    systemNotificationsEnabled:
        systemNotificationsEnabled ?? this.systemNotificationsEnabled,
    eventRemindersEnabled: eventRemindersEnabled ?? this.eventRemindersEnabled,
    taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
    weeklyReviewRemindersEnabled:
        weeklyReviewRemindersEnabled ?? this.weeklyReviewRemindersEnabled,
    awaitingReportRemindersEnabled:
        awaitingReportRemindersEnabled ?? this.awaitingReportRemindersEnabled,
    goalCompletionNotificationsEnabled:
        goalCompletionNotificationsEnabled ??
        this.goalCompletionNotificationsEnabled,
    inAppGoalCelebrationsEnabled:
        inAppGoalCelebrationsEnabled ?? this.inAppGoalCelebrationsEnabled,
    defaultTaskReminderMinutes: clearDefaultTaskReminder
        ? null
        : defaultTaskReminderMinutes ?? this.defaultTaskReminderMinutes,
    snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
    quietHours: quietHours ?? this.quietHours,
  );

  void validate() {
    final taskOffset = defaultTaskReminderMinutes;
    if (taskOffset != null && taskOffset < 0) {
      throw ArgumentError.value(taskOffset, 'defaultTaskReminderMinutes');
    }
    if (snoozeDurationMinutes < 1 || snoozeDurationMinutes > 10080) {
      throw ArgumentError.value(snoozeDurationMinutes, 'snoozeDurationMinutes');
    }
    quietHours.validate();
  }

  bool effectiveSystemEnabled({required bool androidPermissionGranted}) =>
      systemNotificationsEnabled && androidPermissionGranted;

  bool effectiveEventEnabled({required bool androidPermissionGranted}) =>
      effectiveSystemEnabled(
        androidPermissionGranted: androidPermissionGranted,
      ) &&
      eventRemindersEnabled;

  bool effectiveTaskEnabled({required bool androidPermissionGranted}) =>
      effectiveSystemEnabled(
        androidPermissionGranted: androidPermissionGranted,
      ) &&
      taskRemindersEnabled;

  bool effectiveWeeklyReviewEnabled({required bool androidPermissionGranted}) =>
      effectiveSystemEnabled(
        androidPermissionGranted: androidPermissionGranted,
      ) &&
      weeklyReviewRemindersEnabled;

  bool effectiveAwaitingReportEnabled({
    required bool androidPermissionGranted,
  }) =>
      effectiveSystemEnabled(
        androidPermissionGranted: androidPermissionGranted,
      ) &&
      awaitingReportRemindersEnabled;

  bool effectiveGoalCompletionNotificationsEnabled({
    required bool androidPermissionGranted,
  }) =>
      effectiveSystemEnabled(
        androidPermissionGranted: androidPermissionGranted,
      ) &&
      goalCompletionNotificationsEnabled;

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      systemNotificationsEnabled == other.systemNotificationsEnabled &&
      eventRemindersEnabled == other.eventRemindersEnabled &&
      taskRemindersEnabled == other.taskRemindersEnabled &&
      weeklyReviewRemindersEnabled == other.weeklyReviewRemindersEnabled &&
      awaitingReportRemindersEnabled == other.awaitingReportRemindersEnabled &&
      goalCompletionNotificationsEnabled ==
          other.goalCompletionNotificationsEnabled &&
      inAppGoalCelebrationsEnabled == other.inAppGoalCelebrationsEnabled &&
      defaultTaskReminderMinutes == other.defaultTaskReminderMinutes &&
      snoozeDurationMinutes == other.snoozeDurationMinutes &&
      quietHours == other.quietHours;

  @override
  int get hashCode => Object.hash(
    systemNotificationsEnabled,
    eventRemindersEnabled,
    taskRemindersEnabled,
    weeklyReviewRemindersEnabled,
    awaitingReportRemindersEnabled,
    goalCompletionNotificationsEnabled,
    inAppGoalCelebrationsEnabled,
    defaultTaskReminderMinutes,
    snoozeDurationMinutes,
    quietHours,
  );
}

const int recommendedEventReminderMinutes = 15;
