import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/background/background_work_gateway.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/notifications/notification_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/features/notifications/application/notification_providers.dart';
import 'package:rmplanner/features/notifications/data/drift_notification_foundation_repository.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test(
    'startup/load never requests permission or schedules domain work',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startupRepository = buildTestRepository(database: database);
      await startupRepository.completeOnboarding();
      final privacy = TestPrivacyDependencies(
        database: database,
        permissionGateway: FakePermissionGateway(
          requestResult: OperatingSystemPermissionState.denied,
        ),
      );
      final notifications = _FakeNotificationGateway();
      final background = _FakeBackgroundGateway();
      final container = ProviderContainer(
        overrides: <Override>[
          startupRepositoryProvider.overrideWithValue(startupRepository),
          diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
          privacyRepositoryProvider.overrideWithValue(privacy.repository),
          permissionGatewayProvider.overrideWithValue(
            privacy.permissionGateway,
          ),
          notificationFoundationRepositoryProvider.overrideWithValue(
            DriftNotificationFoundationRepository(
              database: database,
              clock: FixedClock(DateTime.utc(2026, 9, 5)),
            ),
          ),
          notificationGatewayProvider.overrideWithValue(notifications),
          backgroundWorkGatewayProvider.overrideWithValue(background),
        ],
      );
      addTearDown(container.dispose);
      await container.read(startupControllerProvider.notifier).initialize();
      final controller = container.read(
        notificationSettingsControllerProvider.notifier,
      );
      await controller.load();

      expect(privacy.permissionGateway.requestCount, 0);
      expect(notifications.scheduleCount, 0);
      expect(background.enqueueCount, 0);

      await controller.setEventRemindersEnabled(true);
      await controller.setTaskRemindersEnabled(true);
      expect(notifications.scheduleCount, 0);
      expect(background.enqueueCount, 0);

      await controller.requestPermission();
      expect(privacy.permissionGateway.requestCount, 1);
      expect(
        container.read(notificationSettingsControllerProvider).permission,
        OperatingSystemPermissionState.denied,
      );
      expect(
        (await privacy.repository.readPermissionAudit(
          OptionalPermission.notifications,
        )).requestedByApp,
        isTrue,
      );
      expect(
        container
            .read(notificationSettingsControllerProvider)
            .preferences
            .eventRemindersEnabled,
        isTrue,
      );
    },
  );
}

final class _FakeNotificationGateway implements NotificationGateway {
  int scheduleCount = 0;

  @override
  Stream<NotificationResponseIntent> get responses => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    scheduleCount += 1;
  }

  @override
  Future<void> cancel(int platformId) async {}

  @override
  Future<List<PendingLocalNotification>> pending() async => const [];

  @override
  NotificationResponseIntent? takeInitialResponse() => null;
}

final class _FakeBackgroundGateway implements BackgroundWorkGateway {
  int enqueueCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> enqueueUnique(BackgroundWorkSpec work) async {
    enqueueCount += 1;
  }

  @override
  Future<void> cancelUnique(String uniqueName) async {}

  @override
  Future<BackgroundGatewayWorkState> inspect(String uniqueName) async =>
      BackgroundGatewayWorkState.absent;
}
