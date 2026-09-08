import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/background/background_work_gateway.dart';
import 'package:rmplanner/core/background/workmanager_background_work_gateway.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/notifications/flutter_local_notifications_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/notifications/application/notification_privacy_refresh_provider.dart';
import 'package:rmplanner/features/notifications/application/notification_providers.dart';
import 'package:rmplanner/features/notifications/application/reminder_reconciler.dart';
import 'package:rmplanner/features/notifications/data/drift_notification_foundation_repository.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/data/drift_privacy_repository.dart';
import 'package:rmplanner/features/privacy/data/permission_handler_gateway.dart';

@pragma('vm:entry-point')
void nextTransferReminderAction(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final intent = NotificationPayloadCodec.tryDecode(
    response.payload,
    actionId: response.actionId,
  );
  if (intent?.action != NotificationResponseAction.snooze) return;
  await enqueueReminderSnooze(
    snooze: intent,
    actionAtUtc: DateTime.now().toUtc(),
  );
}

Future<void> enqueueReminderSnooze({
  required NotificationResponseIntent? snooze,
  required DateTime actionAtUtc,
  Future<bool> Function(NotificationResponseIntent, DateTime)? applySnooze,
  BackgroundWorkGateway backgroundWork =
      const WorkmanagerBackgroundWorkGateway(),
}) async {
  if (snooze == null ||
      snooze.action != NotificationResponseAction.snooze ||
      snooze.occurrenceId == null ||
      (snooze.sourceKind != NotificationSourceKind.calendarEvent &&
          snooze.sourceKind != NotificationSourceKind.task)) {
    return;
  }
  // The notification response isolate is already running. Persist and schedule
  // now: WorkManager's opportunistic startup/retry can outlast a 1-minute Snooze.
  // The same transaction and generation checks serialize simultaneous taps.
  final applied =
      await (applySnooze ??
          (intent, at) => runReminderRuntime(snooze: intent, actionAtUtc: at))(
        snooze,
        actionAtUtc,
      );
  if (applied) return;
  // Only a retryable runtime failure needs deferred background execution.
  await backgroundWork.enqueueUnique(
    BackgroundWorkSpec(
      uniqueName:
          'nt.snooze.${snooze.sourceId}.${snooze.occurrenceId}.${snooze.generation}',
      taskName: 'nt.reminder.snooze',
      inputData: {
        'profile_id': snooze.profileId,
        'source_kind': snooze.sourceKind.name,
        'source_id': snooze.sourceId,
        'occurrence_id': snooze.occurrenceId,
        'generation': snooze.generation,
        'action_utc_ms': actionAtUtc.millisecondsSinceEpoch,
      },
    ),
  );
}

/// Uses the same source-specific application reconciliation paths as the UI.
/// No onboarding, authentication, navigation, or source-domain mutation occurs.
Future<bool> runReminderRuntime({
  String? deliveryKey,
  DateTime? scheduledAtUtc,
  NotificationResponseIntent? snooze,
  DateTime? actionAtUtc,
}) async {
  if (deliveryKey != null &&
      scheduledAtUtc != null &&
      scheduledAtUtc.isAfter(DateTime.now().toUtc())) {
    return false; // WorkManager retry after a backward clock adjustment.
  }
  final database = AppDatabase.defaults();
  ProviderContainer? container;
  try {
    const clock = SystemAppClock();
    final profiles = await (database.select(
      database.localProfiles,
    )..where((table) => table.slot.equals('primary'))).get();
    if (profiles.length != 1) return true;
    final profileId = profiles.single.id;
    if (snooze != null && snooze.profileId != profileId) return true;
    final zones = await IanaCalendarEventTimeZones.forDevice();
    final repository = DriftNotificationFoundationRepository(
      database: database,
      clock: clock,
    );
    final deliveryWork = deliveryKey == null
        ? null
        : await repository.readWorkRequest(deliveryKey);
    final gateway = FlutterLocalNotificationsGateway(
      runningDeliveryPlatformId: deliveryWork?.platformNotificationId,
    );
    await gateway.initialize();
    final events = DriftCalendarEventRepository(
      database: database,
      clock: clock,
      timeZones: zones,
    );
    container = ProviderContainer(
      overrides: [
        reminderRuntimeProfileIdProvider.overrideWithValue(profileId),
        notificationFoundationRepositoryProvider.overrideWithValue(repository),
        notificationGatewayProvider.overrideWithValue(gateway),
        reminderReconcilerProvider.overrideWithValue(
          ReminderReconciler(
            repository: repository,
            gateway: gateway,
            clock: clock,
            deliveryKey: deliveryKey,
            deliveryScheduledAtUtc: scheduledAtUtc,
            snoozeIntent: snooze,
            actionAtUtc: actionAtUtc,
            deviceLocation: zones.deviceLocation,
          ),
        ),
        calendarEventRepositoryProvider.overrideWithValue(events),
        eventTypeRepositoryProvider.overrideWithValue(
          DriftEventTypeRepository(database: database, clock: clock),
        ),
        plannerRepositoryProvider.overrideWithValue(
          DriftPlannerRepository(
            database: database,
            clock: clock,
            calendarSource: events,
          ),
        ),
        privacyRepositoryProvider.overrideWithValue(
          DriftPrivacyRepository(database: database, clock: clock),
        ),
        permissionGatewayProvider.overrideWithValue(
          const PermissionHandlerGateway(),
        ),
      ],
    );
    await database.transaction(() async {
      // Acquire the SQLite writer lock without modifying any source row.
      // Concurrent headless recovery/actions retry instead of double-delivering.
      await database.customStatement(
        'UPDATE background_work_requests SET attempt_count = attempt_count WHERE 0',
      );
      await container!.read(reconcileRemindersProvider)();
    });
    return true;
  } on Object {
    return false;
  } finally {
    container?.dispose();
    await database.close();
  }
}
