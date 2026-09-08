import 'package:rmplanner/core/background/background_work_request.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:rmplanner/features/notifications/domain/reminder_policy.dart';

abstract interface class NotificationFoundationRepository {
  Future<NotificationPreferences> readPreferences({required String profileId});

  Future<NotificationPreferences> savePreferences({
    required String profileId,
    required NotificationPreferences preferences,
  });

  Future<List<ReminderPolicy>> readPolicies({
    required String profileId,
    required ReminderSourceKind sourceKind,
    required String sourceId,
  });

  Future<ReminderPolicy> upsertPolicy(ReminderPolicy policy);

  Future<void> deletePolicy({
    required String profileId,
    required ReminderSourceKind sourceKind,
    required String sourceId,
    required String occurrenceId,
  });

  Future<BackgroundWorkRequest?> readWorkRequest(String stableKey);

  Future<List<BackgroundWorkRequest>> readReminderWork({
    required String profileId,
    required ReminderSourceKind sourceKind,
    required DateTime windowStartUtc,
    required DateTime windowEndUtc,
    String? sourceId,
  });

  Future<BackgroundWorkRequest> upsertWorkRequest(
    BackgroundWorkRequest request,
  );

  Future<void> recordAttempt({
    required String stableKey,
    required BackgroundWorkState nextState,
    String? failureCategory,
    DateTime? nextEligibleAtUtc,
  });

  Future<void> recordSnooze({
    required String stableKey,
    required DateTime untilUtc,
  });

  Future<int> allocatePlatformNotificationId(String stableKey);

  Future<int> countPendingWork({required String profileId});
}
