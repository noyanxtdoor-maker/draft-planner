import 'package:rmplanner/core/background/background_work_request.dart';
import 'package:rmplanner/core/notifications/canonical_reminder_delivery_gateway.dart';
import 'package:rmplanner/core/notifications/notification_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/core/notifications/notification_preview_policy.dart';
import 'package:rmplanner/features/goals/application/goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/notifications/application/notification_foundation_repository.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/privacy/domain/privacy_settings.dart';

/// Projects an already-committed achievement receipt.  It deliberately has no
/// completion method: background/startup recovery may deliver a receipt once,
/// but it cannot create or infer an achievement from Goal progress.
final class GoalAchievementDelivery {
  const GoalAchievementDelivery({
    required this.goals,
    required this.lifecycle,
    required this.foundation,
    required this.gateway,
    required this.permission,
    required this.privacy,
  });

  final GoalRepository goals;
  final GoalLifecycleRepository lifecycle;
  final NotificationFoundationRepository foundation;
  final NotificationGateway gateway;
  final OperatingSystemPermissionState permission;
  final PrivacySettings privacy;

  Future<void> deliverUndelivered({required String profileId}) async {
    final preferences = await foundation.readPreferences(profileId: profileId);
    if (!preferences.effectiveGoalCompletionNotificationsEnabled(
      androidPermissionGranted:
          permission == OperatingSystemPermissionState.granted,
    )) {
      return;
    }
    for (final achievement in await lifecycle.readUndeliveredGoalAchievements(
      profileId,
    )) {
      await _deliver(profileId: profileId, achievement: achievement);
    }
  }

  Future<void> _deliver({
    required String profileId,
    required GoalAchievement achievement,
  }) async {
    final goal = await goals.readGoal(
      profileId: profileId,
      goalId: achievement.goalId,
    );
    final detailed =
        resolveNotificationPreviewMode(
          settings: privacy,
          privacyProtectionRequired: privacy.lockEnabled,
        ) ==
        EffectiveNotificationPreviewMode.detailed;
    final stableKey = 'achievement:${achievement.id}:system';
    final now = DateTime.now().toUtc();
    final durable = await foundation.upsertWorkRequest(
      BackgroundWorkRequest(
        stableKey: stableKey,
        profileId: profileId,
        category: BackgroundWorkCategory.notificationFoundation,
        ownerKind: BackgroundWorkOwnerKind.profile,
        ownerId: achievement.goalId,
        occurrenceId: achievement.id,
        sourceRevision: achievement.completionGeneration.toString(),
        scheduledForUtc: now,
        state: BackgroundWorkState.queued,
        attemptCount: 0,
        snoozeCount: 0,
        createdAtUtc: now,
        updatedAtUtc: now,
      ),
    );
    final platformId =
        durable.platformNotificationId ??
        await foundation.allocatePlatformNotificationId(stableKey);
    final request = LocalNotificationRequest(
      platformId: platformId,
      stableKey: stableKey,
      channel: NotificationChannelKind.planning,
      scheduledAtUtc: now,
      title: detailed ? '🎉 Goal completed' : '🔔 Next Transfer',
      body: detailed && goal != null
          ? 'Congratulations on completing "${goal.title}".'
          : detailed
          ? 'Congratulations on completing this goal.'
          : 'You have a new notification.',
      responseIntent: NotificationResponseIntent(
        profileId: profileId,
        sourceKind: NotificationSourceKind.goalAchievement,
        sourceId: achievement.goalId,
        occurrenceId: achievement.id,
        generation: achievement.completionGeneration,
        action: NotificationResponseAction.open,
      ),
    );
    if (gateway is CanonicalReminderDeliveryGateway) {
      await (gateway as CanonicalReminderDeliveryGateway).showCanonicalReminder(
        request,
      );
    } else {
      await gateway.schedule(request);
    }
    await lifecycle.markGoalAchievementNotificationDelivered(
      profileId: profileId,
      achievementId: achievement.id,
    );
    await foundation.upsertWorkRequest(
      durable.copyWith(
        state: BackgroundWorkState.completed,
        platformNotificationId: platformId,
        completedAtUtc: now,
        updatedAtUtc: now,
      ),
    );
  }
}
