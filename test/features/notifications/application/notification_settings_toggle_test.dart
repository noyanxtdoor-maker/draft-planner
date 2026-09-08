import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart'
    hide NotificationPreferences;
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/notifications/notification_gateway.dart';
import 'package:rmplanner/core/notifications/notification_payload.dart';
import 'package:rmplanner/features/notifications/application/notification_privacy_refresh_provider.dart';
import 'package:rmplanner/features/notifications/application/notification_providers.dart';
import 'package:rmplanner/features/notifications/application/reconcile_reminders.dart';
import 'package:rmplanner/features/notifications/data/drift_notification_foundation_repository.dart';
import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test(
    'permission request and master complete before a blocked Event horizon',
    () async {
      final h = await Harness.create();
      h.permission.result = OperatingSystemPermissionState.granted;
      final gate = Completer<void>();
      h.eventGate = gate.future;
      await h.controller
          .setSystemNotificationsEnabled(true)
          .timeout(const Duration(seconds: 1));
      expect(h.permission.requests, 1);
      expect(h.state.preferences.systemNotificationsEnabled, isTrue);
      expect((await h.saved()).systemNotificationsEnabled, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(h.events, 1);
      gate.complete();
      await h.finishRecovery();
      expect(h.events, 1);
      expect(h.tasks, 1);
      // Baseline blocked the request for the entire 300ms injected delay and
      // executed two Event passes. The fixed interaction does not await either.
    },
  );

  test(
    'OFF reflects immediately, persists and cancels before full recovery',
    () async {
      final h = await Harness.create(granted: true, enabled: true);
      h.gateway.pendingIds.addAll([11, 22]);
      final gate = Completer<void>();
      h.eventGate = gate.future;
      final off = h.controller.setSystemNotificationsEnabled(false);
      expect(h.state.preferences.systemNotificationsEnabled, isFalse);
      await off;
      expect((await h.saved()).systemNotificationsEnabled, isFalse);
      expect(h.gateway.cancelled, [11, 22]);
      expect(h.permission.requests, 0);
      expect(h.permission.settings, 0);
      expect(h.permission.current, OperatingSystemPermissionState.granted);
      gate.complete();
      await h.finishRecovery();
      expect(h.events, 1);
    },
  );

  test(
    'granted ON skips permission and settings, categories stay independent',
    () async {
      final h = await Harness.create(granted: true);
      await h.controller.setSystemNotificationsEnabled(true);
      await h.finishRecovery();
      expect(h.permission.requests, 0);
      expect(h.permission.settings, 0);
      expect((await h.saved()).systemNotificationsEnabled, isTrue);
      expect(h.events, 1);
      await h.controller.setEventRemindersEnabled(false);
      await h.controller.setTaskRemindersEnabled(false);
      expect(h.state.preferences.eventRemindersEnabled, isFalse);
      expect(h.state.preferences.taskRemindersEnabled, isFalse);
      await h.controller.setEventRemindersEnabled(true);
      expect(h.state.preferences.taskRemindersEnabled, isFalse);
      await h.controller.setTaskRemindersEnabled(true);
      expect((await h.saved()).eventRemindersEnabled, isTrue);
      expect((await h.saved()).taskRemindersEnabled, isTrue);
      await h.finishRecovery();
    },
  );

  test(
    'denial persists OFF and does not open settings unnecessarily',
    () async {
      final h = await Harness.create(enabled: true);
      await h.controller.setSystemNotificationsEnabled(true);
      expect(h.permission.requests, 1);
      expect(h.permission.settings, 0);
      expect((await h.saved()).systemNotificationsEnabled, isFalse);
      expect(
        h.state.preferences.effectiveSystemEnabled(
          androidPermissionGranted: false,
        ),
        isFalse,
      );
      await h.finishRecovery();
      expect(h.events, 1);
    },
  );

  test(
    'external revocation is checked even when cached state was granted',
    () async {
      final h = await Harness.create(granted: true, enabled: true);
      h.permission.current = OperatingSystemPermissionState.denied;
      h.permission.result = OperatingSystemPermissionState.granted;
      await h.controller.setSystemNotificationsEnabled(true);
      expect(h.permission.requests, 1);
      expect((await h.saved()).systemNotificationsEnabled, isTrue);
      await h.finishRecovery();
      expect(h.events, 1);
    },
  );

  test(
    'blocked prompt falls back safely and grant on return enables master',
    () async {
      final h = await Harness.create();
      h.permission.current = OperatingSystemPermissionState.permanentlyDenied;
      await h.controller.setSystemNotificationsEnabled(true);
      expect(h.permission.requests, 0);
      expect(h.permission.settings, 1);
      expect((await h.saved()).systemNotificationsEnabled, isFalse);
      await h.finishRecovery();
      h.permission.current = OperatingSystemPermissionState.granted;
      await h.controller.load();
      expect((await h.saved()).systemNotificationsEnabled, isTrue);
      expect(h.permission.requests, 0);
      await h.finishRecovery();
    },
  );

  test(
    'request becoming permanently denied opens the supported fallback',
    () async {
      final h = await Harness.create();
      h.permission.result = OperatingSystemPermissionState.permanentlyDenied;
      await h.controller.setSystemNotificationsEnabled(true);
      expect(h.permission.requests, 1);
      expect(h.permission.settings, 1);
      expect((await h.saved()).systemNotificationsEnabled, isFalse);
      await h.finishRecovery();
    },
  );

  test(
    'permission lifecycle recovery and preference trigger share one pass',
    () async {
      final h = await Harness.create();
      final permissionGate = Completer<OperatingSystemPermissionState>();
      h.permission.gate = permissionGate.future;
      final toggle = h.controller.setSystemNotificationsEnabled(true);
      while (h.permission.requests == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final resumed = h.recovery();
      await h.controller.load();
      await Future<void>.delayed(Duration.zero);
      expect(h.events, 0);
      permissionGate.complete(OperatingSystemPermissionState.granted);
      await toggle;
      await resumed;
      expect(h.events, 1);
      expect(h.tasks, 1);
      expect((await h.saved()).systemNotificationsEnabled, isTrue);
    },
  );

  test('rapid OFF ON OFF keeps the last durable and visible choice', () async {
    final h = await Harness.create(granted: true, enabled: true);
    await Future.wait([
      h.controller.setSystemNotificationsEnabled(false),
      h.controller.setSystemNotificationsEnabled(true),
      h.controller.setSystemNotificationsEnabled(false),
    ]);
    expect(h.state.preferences.systemNotificationsEnabled, isFalse);
    expect((await h.saved()).systemNotificationsEnabled, isFalse);
    expect(h.permission.requests, 0);
    await h.finishRecovery();
  });

  test(
    'recovery failure does not roll back saved preference or poison retry',
    () async {
      final h = await Harness.create(granted: true);
      h.failRecovery = true;
      await h.controller.setSystemNotificationsEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect((await h.saved()).systemNotificationsEnabled, isTrue);
      expect(h.state.message, isNull);
      h.failRecovery = false;
      await h.recovery();
      expect(h.tasks, 1);
    },
  );
}

final class Harness {
  Harness(this.db, this.repository, this.profileId, this.permission);
  final AppDatabase db;
  final DriftNotificationFoundationRepository repository;
  final String profileId;
  final TestPermission permission;
  final TestNotifications gateway = TestNotifications();
  late final ProviderContainer container;
  late final ReconcileReminders recovery;
  Future<void>? eventGate;
  int events = 0;
  int tasks = 0;
  bool failRecovery = false;
  NotificationSettingsController get controller =>
      container.read(notificationSettingsControllerProvider.notifier);
  NotificationSettingsState get state =>
      container.read(notificationSettingsControllerProvider);
  Future<NotificationPreferences> saved() =>
      repository.readPreferences(profileId: profileId);

  static Future<Harness> create({
    bool granted = false,
    bool enabled = false,
  }) async {
    final db = openMemoryDatabase();
    final startup = buildTestRepository(database: db);
    final profile = await startup.completeOnboarding();
    final repository = DriftNotificationFoundationRepository(
      database: db,
      clock: FixedClock(DateTime.utc(2026, 9, 8)),
    );
    await repository.savePreferences(
      profileId: profile.id,
      preferences: const NotificationPreferences.defaults().copyWith(
        systemNotificationsEnabled: enabled,
        eventRemindersEnabled: true,
        taskRemindersEnabled: true,
      ),
    );
    final permission = TestPermission()
      ..current = granted
          ? OperatingSystemPermissionState.granted
          : OperatingSystemPermissionState.denied;
    final privacy = TestPrivacyDependencies(database: db);
    final h = Harness(db, repository, profile.id, permission);
    h.recovery = ReconcileReminders(
      reconcileEvents: () async {
        h.events++;
        if (h.failRecovery) throw StateError('recovery unavailable');
        await h.eventGate;
      },
      reconcileTasks: () async {
        h.tasks++;
      },
    );
    h.container = ProviderContainer(
      overrides: [
        startupRepositoryProvider.overrideWithValue(startup),
        diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
        privacyRepositoryProvider.overrideWithValue(privacy.repository),
        permissionGatewayProvider.overrideWithValue(permission),
        notificationFoundationRepositoryProvider.overrideWithValue(repository),
        notificationGatewayProvider.overrideWithValue(h.gateway),
        reconcileRemindersProvider.overrideWithValue(h.recovery),
      ],
    );
    await h.container.read(startupControllerProvider.notifier).initialize();
    await h.controller.load();
    addTearDown(() async {
      h.container.dispose();
      await db.close();
    });
    return h;
  }

  Future<void> finishRecovery() async {
    // Allow the queued pass to finish without adding another recovery trigger.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

final class TestPermission implements PermissionGateway {
  OperatingSystemPermissionState current =
      OperatingSystemPermissionState.denied;
  OperatingSystemPermissionState result = OperatingSystemPermissionState.denied;
  Future<OperatingSystemPermissionState>? gate;
  int requests = 0;
  int settings = 0;
  @override
  Future<OperatingSystemPermissionState> status(
    OptionalPermission permission,
  ) async => current;
  @override
  Future<OperatingSystemPermissionState> request(
    OptionalPermission permission,
  ) async {
    requests++;
    current = await (gate ?? Future.value(result));
    return current;
  }

  @override
  Future<bool> openSystemSettings() async {
    settings++;
    return true;
  }
}

final class TestNotifications implements NotificationGateway {
  final List<int> pendingIds = [];
  final List<int> cancelled = [];
  @override
  Stream<NotificationResponseIntent> get responses => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> schedule(LocalNotificationRequest request) async {}
  @override
  Future<void> cancel(int platformId) async {
    cancelled.add(platformId);
    pendingIds.remove(platformId);
  }

  @override
  Future<List<PendingLocalNotification>> pending() async =>
      pendingIds.map((id) => PendingLocalNotification(platformId: id)).toList();
  @override
  NotificationResponseIntent? takeInitialResponse() => null;
}
