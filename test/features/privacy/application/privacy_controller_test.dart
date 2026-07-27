import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test(
    'AC-W-003..005: enable, relock, unlock, and disable use OS auth',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final dependencies = TestPrivacyDependencies(database: database);
      final container = dependencies.createContainer();
      addTearDown(container.dispose);

      final controller = container.read(privacyControllerProvider.notifier);
      await controller.initialize();
      expect(
        container.read(privacyControllerProvider).status,
        PrivacyLockStatus.disabled,
      );

      expect(await controller.enableLock(), isTrue);
      expect(
        container.read(privacyControllerProvider).status,
        PrivacyLockStatus.unlocked,
      );
      expect(
        (await dependencies.repository.readSettings()).lockEnabled,
        isTrue,
      );

      expect(controller.lockForBackground(), isTrue);
      expect(
        container.read(privacyControllerProvider).status,
        PrivacyLockStatus.locked,
      );
      expect(await dependencies.gate.isUnlockRequired(), isTrue);

      expect(await controller.authenticate(), isTrue);
      expect(await dependencies.gate.isUnlockRequired(), isFalse);

      expect(await controller.disableLock(), isTrue);
      expect(
        (await dependencies.repository.readSettings()).lockEnabled,
        isFalse,
      );
      expect(dependencies.authenticator.authenticationAttempts, 3);
    },
  );

  test(
    'AC-W-004,005: auth failure keeps data and lock configuration intact',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final authenticator = FakeDeviceAuthenticator();
      final dependencies = TestPrivacyDependencies(
        database: database,
        authenticator: authenticator,
      );
      final container = dependencies.createContainer();
      addTearDown(container.dispose);
      final controller = container.read(privacyControllerProvider.notifier);
      await controller.initialize();
      await controller.enableLock();
      controller.lockForBackground();

      authenticator.authenticationResult = DeviceAuthenticationResult.failed;
      expect(await controller.authenticate(), isFalse);
      expect(
        (await dependencies.repository.readSettings()).lockEnabled,
        isTrue,
      );
      expect(
        container.read(privacyControllerProvider).message,
        contains('remains locked'),
      );
    },
  );

  test('AC-W-003: unavailable device auth cannot enable lock', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final dependencies = TestPrivacyDependencies(
      database: database,
      authenticator: FakeDeviceAuthenticator(
        availabilityResult: DeviceAuthenticationAvailability.unavailable,
      ),
    );
    final container = dependencies.createContainer();
    addTearDown(container.dispose);
    final controller = container.read(privacyControllerProvider.notifier);
    await controller.initialize();

    expect(await controller.enableLock(), isFalse);
    expect((await dependencies.repository.readSettings()).lockEnabled, isFalse);
  });

  test('AC-W-001,002,018,019: status is observed without requesting', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final gateway = FakePermissionGateway();
    final dependencies = TestPrivacyDependencies(
      database: database,
      permissionGateway: gateway,
    );
    final container = dependencies.createContainer();
    addTearDown(container.dispose);

    var summaries = await container.read(permissionSummariesProvider.future);
    expect(
      summaries.map((item) => item.state),
      everyElement(PermissionState.notRequested),
    );

    await dependencies.repository.recordPermissionRequested(
      OptionalPermission.contacts,
    );
    container.invalidate(permissionSummariesProvider);
    summaries = await container.read(permissionSummariesProvider.future);
    expect(
      summaries
          .singleWhere((item) => item.permission == OptionalPermission.contacts)
          .state,
      PermissionState.denied,
    );

    gateway.states[OptionalPermission.contacts] =
        OperatingSystemPermissionState.granted;
    container.invalidate(permissionSummariesProvider);
    await container.read(permissionSummariesProvider.future);
    gateway.states[OptionalPermission.contacts] =
        OperatingSystemPermissionState.denied;
    container.invalidate(permissionSummariesProvider);
    summaries = await container.read(permissionSummariesProvider.future);
    expect(
      summaries
          .singleWhere((item) => item.permission == OptionalPermission.contacts)
          .state,
      PermissionState.revoked,
    );
  });
}
