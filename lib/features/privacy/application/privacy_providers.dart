import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/core/security/auth_token_store.dart';
import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/features/notifications/application/notification_privacy_refresh_provider.dart';
import 'package:rmplanner/features/privacy/application/privacy_repository.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/privacy/domain/privacy_settings.dart';

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  throw StateError('PrivacyRepository must be overridden at the app root');
});

final privacyGateProvider = Provider<PrivacyGate>((ref) {
  throw StateError('PrivacyGate must be overridden at the app root');
});

final deviceAuthenticatorProvider = Provider<DeviceAuthenticator>((ref) {
  throw StateError('DeviceAuthenticator must be overridden at the app root');
});

final monotonicClockProvider = Provider<MonotonicClock>((ref) {
  return StopwatchMonotonicClock();
});

final permissionGatewayProvider = Provider<PermissionGateway>((ref) {
  throw StateError('PermissionGateway must be overridden at the app root');
});

final authTokenStoreProvider = Provider<AuthTokenStore>((ref) {
  throw StateError('AuthTokenStore must be overridden at the app root');
});

enum PrivacyLockStatus {
  loading,
  disabled,
  locked,
  authenticating,
  unlocked,
  authenticationFailed,
  unavailable,
}

final class PrivacyState {
  const PrivacyState({
    required this.status,
    required this.settings,
    this.message,
  });

  const PrivacyState.loading()
    : status = PrivacyLockStatus.loading,
      settings = const PrivacySettings.defaults(),
      message = null;

  final PrivacyLockStatus status;
  final PrivacySettings settings;
  final String? message;

  bool get isBusy =>
      status == PrivacyLockStatus.loading ||
      status == PrivacyLockStatus.authenticating;

  PrivacyState copyWith({
    PrivacyLockStatus? status,
    PrivacySettings? settings,
    String? message,
    bool clearMessage = false,
  }) {
    return PrivacyState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

final privacyControllerProvider =
    NotifierProvider<PrivacyController, PrivacyState>(PrivacyController.new);

final class PrivacyController extends Notifier<PrivacyState> {
  Future<void>? _initialization;
  int _lockGeneration = 0;

  PrivacyRepository get _repository => ref.read(privacyRepositoryProvider);
  PrivacyGate get _gate => ref.read(privacyGateProvider);
  DeviceAuthenticator get _authenticator =>
      ref.read(deviceAuthenticatorProvider);

  @override
  PrivacyState build() {
    unawaited(initialize());
    return const PrivacyState.loading();
  }

  Future<void> initialize() async {
    final existing = _initialization;
    if (existing != null) {
      await existing;
      return;
    }
    final future = _initialize();
    _initialization = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      final settings = await _repository.readSettings();
      if (settings.lockEnabled) {
        _gate.markLocked();
      }
      final availability = await _authenticator.availability();
      state = PrivacyState(
        status: settings.lockEnabled
            ? PrivacyLockStatus.locked
            : PrivacyLockStatus.disabled,
        settings: settings,
        message:
            settings.lockEnabled &&
                availability == DeviceAuthenticationAvailability.unavailable
            ? 'Device authentication is unavailable. Configure a screen lock '
                  'in Android Settings, then try again.'
            : null,
      );
    } on Object {
      state = const PrivacyState(
        status: PrivacyLockStatus.unavailable,
        settings: PrivacySettings.defaults(),
        message: 'Privacy settings could not be opened.',
      );
    }
  }

  Future<bool> authenticate() async {
    if (!state.settings.lockEnabled) {
      _gate.markUnlocked();
      state = state.copyWith(
        status: PrivacyLockStatus.disabled,
        clearMessage: true,
      );
      return true;
    }
    return _runAuthentication();
  }

  Future<bool> enableLock() async {
    if (state.settings.lockEnabled || state.isBusy) {
      return state.settings.lockEnabled;
    }
    final generation = _lockGeneration;
    final availability = await _authenticator.availability();
    if (generation != _lockGeneration) {
      return false;
    }
    if (availability == DeviceAuthenticationAvailability.unavailable) {
      state = state.copyWith(
        status: PrivacyLockStatus.unavailable,
        message: 'Set up an Android screen lock before enabling Privacy Lock.',
      );
      return false;
    }
    final authenticated = await _authenticateDevice();
    if (!authenticated || generation != _lockGeneration) {
      if (state.status != PrivacyLockStatus.unavailable) {
        if (generation != _lockGeneration) {
          _gate.markLocked();
          state = state.copyWith(
            status: PrivacyLockStatus.locked,
            clearMessage: true,
          );
          return false;
        }
        state = state.copyWith(
          message:
              'Authentication did not complete. Privacy Lock was not '
              'enabled.',
        );
      }
      return false;
    }
    try {
      final settings = await _repository.setLockEnabled(true);
      _gate.markUnlocked();
      state = PrivacyState(
        status: PrivacyLockStatus.unlocked,
        settings: settings,
      );
      await _refreshNotificationPrivacy();
      return true;
    } on Object {
      state = state.copyWith(
        status: PrivacyLockStatus.authenticationFailed,
        message:
            'Privacy Lock was not enabled because its setting could not '
            'be saved.',
      );
      return false;
    }
  }

  Future<bool> disableLock() async {
    if (!state.settings.lockEnabled || state.isBusy) {
      return !state.settings.lockEnabled;
    }
    final generation = _lockGeneration;
    final authenticated = await _authenticateDevice();
    if (!authenticated || generation != _lockGeneration) {
      if (generation != _lockGeneration) {
        _gate.markLocked();
        state = state.copyWith(
          status: PrivacyLockStatus.locked,
          clearMessage: true,
        );
      }
      return false;
    }
    try {
      final settings = await _repository.setLockEnabled(false);
      _gate.markUnlocked();
      state = PrivacyState(
        status: PrivacyLockStatus.disabled,
        settings: settings,
      );
      await _refreshNotificationPrivacy();
      return true;
    } on Object {
      _gate.markLocked();
      state = state.copyWith(
        status: PrivacyLockStatus.authenticationFailed,
        message:
            'Privacy Lock remains enabled because its setting could not '
            'be changed.',
      );
      return false;
    }
  }

  Future<void> setNotificationPreviewMode(NotificationPreviewMode mode) async {
    if (state.settings.notificationPreviewMode == mode) return;
    try {
      final settings = await _repository.setNotificationPreviewMode(mode);
      state = state.copyWith(settings: settings, clearMessage: true);
      await _refreshNotificationPrivacy();
    } on Object {
      state = state.copyWith(
        message: 'Notification privacy could not be updated.',
      );
    }
  }

  Future<void> _refreshNotificationPrivacy() async {
    try {
      await ref.read(notificationPrivacyRefreshProvider)();
    } on Object {
      // The privacy preference is already durable. A platform refresh failure
      // must not roll it back or overwrite the saved preview mode; the next
      // reconciliation remains safe and idempotent.
    }
  }

  bool lockForBackground() {
    if (!state.settings.lockEnabled) {
      return false;
    }
    if (state.status == PrivacyLockStatus.locked) {
      return false;
    }
    _lockGeneration += 1;
    _gate.markLocked();
    state = state.copyWith(
      status: PrivacyLockStatus.locked,
      clearMessage: true,
    );
    return true;
  }

  Future<bool> _runAuthentication() async {
    final generation = _lockGeneration;
    final authenticated = await _authenticateDevice();
    if (authenticated && generation == _lockGeneration) {
      _gate.markUnlocked();
      state = state.copyWith(
        status: PrivacyLockStatus.unlocked,
        clearMessage: true,
      );
    } else if (!authenticated) {
      _gate.markLocked();
    }
    return authenticated && generation == _lockGeneration;
  }

  Future<bool> _authenticateDevice() async {
    state = state.copyWith(
      status: PrivacyLockStatus.authenticating,
      clearMessage: true,
    );
    final result = await _authenticator.authenticate();
    switch (result) {
      case DeviceAuthenticationResult.authenticated:
        return true;
      case DeviceAuthenticationResult.canceled:
        state = state.copyWith(
          status: PrivacyLockStatus.authenticationFailed,
          message: 'Authentication was canceled. Your data remains locked.',
        );
        return false;
      case DeviceAuthenticationResult.temporarilyLocked:
        state = state.copyWith(
          status: PrivacyLockStatus.authenticationFailed,
          message:
              'Android temporarily blocked authentication. Wait or use '
              'your device credential, then try again.',
        );
        return false;
      case DeviceAuthenticationResult.unavailable:
        state = state.copyWith(
          status: PrivacyLockStatus.unavailable,
          message:
              'Device authentication is unavailable. Configure a screen '
              'lock in Android Settings, then try again.',
        );
        return false;
      case DeviceAuthenticationResult.failed:
        state = state.copyWith(
          status: PrivacyLockStatus.authenticationFailed,
          message: 'Authentication failed. Your data remains locked.',
        );
        return false;
    }
  }
}

final permissionSummariesProvider = FutureProvider<List<PermissionSummary>>((
  ref,
) async {
  final repository = ref.watch(privacyRepositoryProvider);
  final gateway = ref.watch(permissionGatewayProvider);
  final summaries = <PermissionSummary>[];

  for (final permission in OptionalPermissionCatalog.values) {
    final osState = await gateway.status(permission);
    final audit = await repository.readPermissionAudit(permission);
    if (osState == OperatingSystemPermissionState.granted) {
      await repository.recordPermissionGranted(permission);
    }
    summaries.add(
      PermissionSummary(
        permission: permission,
        title: OptionalPermissionCatalog.title(permission),
        purpose: OptionalPermissionCatalog.purpose(permission),
        state: _resolvePermissionState(osState, audit),
      ),
    );
  }
  return List<PermissionSummary>.unmodifiable(summaries);
});

PermissionState _resolvePermissionState(
  OperatingSystemPermissionState osState,
  PermissionAudit audit,
) {
  return switch (osState) {
    OperatingSystemPermissionState.granted => PermissionState.granted,
    OperatingSystemPermissionState.restricted ||
    OperatingSystemPermissionState.unavailable => PermissionState.unavailable,
    OperatingSystemPermissionState.denied ||
    OperatingSystemPermissionState.permanentlyDenied =>
      audit.everGranted
          ? PermissionState.revoked
          : audit.requestedByApp
          ? PermissionState.denied
          : PermissionState.notRequested,
  };
}
