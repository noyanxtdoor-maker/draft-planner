import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/notifications/application/notification_providers.dart';
import 'package:rmplanner/features/notifications/application/planning_reminder_reconciler.dart';
import 'package:rmplanner/features/notifications/application/reconcile_reminders.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

typedef NotificationPrivacyRefresh = Future<void> Function();

/// One canonical Event-and-Task content refresh. Privacy settings invoke this
/// only after their durable write succeeds.
final reconcileRemindersProvider = Provider<ReconcileReminders>((ref) {
  return ReconcileReminders(
    reconcileEvents: () => ref
        .read(calendarEventControllerProvider.notifier)
        .reconcileEventHorizon(refreshContent: true),
    reconcileTasks: () => ref
        .read(plannerControllerProvider.notifier)
        .reconcileTaskReminderHorizon(refreshContent: true),
    reconcilePlanning: () async {
      final startup = ref.read(startupControllerProvider);
      if (startup is! StartupReady) return;
      final permission = await ref
          .read(permissionGatewayProvider)
          .status(OptionalPermission.notifications);
      await PlanningReminderReconciler(
        weeklyPlans: ref.read(weeklyPlanningRepositoryProvider),
        events: ref.read(calendarEventRepositoryProvider),
        repository: ref.read(notificationFoundationRepositoryProvider),
        reminders: ref.read(reminderReconcilerProvider),
        permission: permission,
        privacy: await ref.read(privacyRepositoryProvider).readSettings(),
      ).reconcile(profileId: startup.profile.id);
    },
  );
});

final notificationPrivacyRefreshProvider = Provider<NotificationPrivacyRefresh>(
  (ref) =>
      () => ref.read(reconcileRemindersProvider)(),
);
