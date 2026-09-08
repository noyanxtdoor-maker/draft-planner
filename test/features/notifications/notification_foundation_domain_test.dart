import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/core/notifications/notification_preview_policy.dart';
import 'package:rmplanner/core/notifications/notification_response_controller.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:rmplanner/features/privacy/domain/privacy_settings.dart';

void main() {
  test(
    'master notification policy keeps saved category choices but gates effective state',
    () {
      const enabled = NotificationPreferences(
        systemNotificationsEnabled: true,
        eventRemindersEnabled: true,
        taskRemindersEnabled: true,
        defaultTaskReminderMinutes: null,
        quietHours: QuietHoursSettings.disabled(),
      );

      expect(
        enabled.effectiveSystemEnabled(androidPermissionGranted: true),
        isTrue,
      );
      expect(
        enabled.effectiveEventEnabled(androidPermissionGranted: true),
        isTrue,
      );
      expect(
        enabled.effectiveTaskEnabled(androidPermissionGranted: true),
        isTrue,
      );
      expect(
        enabled.effectiveEventEnabled(androidPermissionGranted: false),
        isFalse,
      );
      expect(
        enabled
            .copyWith(systemNotificationsEnabled: false)
            .eventRemindersEnabled,
        isTrue,
        reason:
            'the saved category preference must not be erased by master Off',
      );
      expect(
        enabled
            .copyWith(systemNotificationsEnabled: false)
            .effectiveTaskEnabled(androidPermissionGranted: true),
        isFalse,
      );
    },
  );

  test('Quiet Hours validates range and interprets overnight windows', () {
    const quiet = QuietHoursSettings(
      enabled: true,
      startMinute: 1320,
      endMinute: 420,
    );
    expect(quiet.isInQuietHours(1380), isTrue);
    expect(quiet.isInQuietHours(360), isTrue);
    expect(quiet.isInQuietHours(720), isFalse);
    expect(
      const QuietHoursSettings(
        enabled: true,
        startMinute: -1,
        endMinute: 60,
      ).validate,
      throwsArgumentError,
    );
    expect(
      const NotificationPreferences(
        systemNotificationsEnabled: false,
        eventRemindersEnabled: false,
        taskRemindersEnabled: false,
        defaultTaskReminderMinutes: -1,
        quietHours: QuietHoursSettings.disabled(),
      ).validate,
      throwsArgumentError,
    );
  });

  test('payload is versioned ID-only and rejects malformed identities', () {
    const intent = NotificationResponseIntent(
      profileId: 'profile-1',
      sourceKind: NotificationSourceKind.calendarEvent,
      sourceId: 'event-1',
      occurrenceId: 'occurrence-1',
      action: NotificationResponseAction.open,
    );
    final encoded = NotificationPayloadCodec.encode(intent);
    expect(NotificationPayloadCodec.tryDecode(encoded), intent);
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    expect(json.keys.toSet(), <String>{
      'version',
      'profileId',
      'sourceKind',
      'sourceId',
      'occurrenceId',
      'action',
    });
    expect(NotificationPayloadCodec.tryDecode('{bad'), isNull);
    expect(
      NotificationPayloadCodec.tryDecode(
        jsonEncode(<String, Object?>{...json, 'version': 999}),
      ),
      isNull,
    );
    expect(
      NotificationPayloadCodec.tryDecode(
        jsonEncode(<String, Object?>{...json}..remove('sourceId')),
      ),
      isNull,
    );
    expect(
      NotificationPayloadCodec.tryDecode(
        jsonEncode(<String, Object?>{...json, 'body': 'private'}),
      ),
      isNull,
    );
  });

  test('Privacy Lock forces Generic without overwriting saved Detailed', () {
    const saved = PrivacySettings(
      lockEnabled: true,
      notificationPreviewMode: NotificationPreviewMode.showContent,
    );
    expect(
      resolveNotificationPreviewMode(
        settings: saved,
        privacyProtectionRequired: true,
      ),
      EffectiveNotificationPreviewMode.generic,
    );
    expect(saved.notificationPreviewMode, NotificationPreviewMode.showContent);
    expect(
      resolveNotificationPreviewMode(
        settings: saved,
        privacyProtectionRequired: false,
      ),
      EffectiveNotificationPreviewMode.detailed,
    );
  });

  test('response controller separates cold and warm typed responses', () async {
    final controller = NotificationResponseController();
    addTearDown(controller.dispose);
    const intent = NotificationResponseIntent(
      profileId: 'profile-1',
      sourceKind: NotificationSourceKind.task,
      sourceId: 'task-1',
      occurrenceId: 'series',
      action: NotificationResponseAction.open,
    );
    controller.capture(
      payload: NotificationPayloadCodec.encode(intent),
      initial: true,
    );
    controller.capture(payload: '{bad');
    expect(controller.takeInitial(), intent);
    expect(controller.takeInitial(), isNull);

    final warm = controller.responses.first;
    controller.capture(
      payload: NotificationPayloadCodec.encode(intent),
      actionId: 'snooze',
    );
    expect((await warm).action, NotificationResponseAction.snooze);
  });
}
