import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/security/auth_token_store.dart';
import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/privacy/data/drift_privacy_repository.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/application/startup_repository.dart';
import 'package:rmplanner/features/startup/data/drift_startup_repository.dart';
import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';

final class FixedClock implements AppClock {
  const FixedClock(this.value);

  final DateTime value;

  @override
  DateTime nowUtc() => value;
}

final class SequenceIdentifierSource implements IdentifierSource {
  SequenceIdentifierSource(this._values);

  final List<String> _values;
  int _index = 0;

  @override
  String nextUuid() {
    if (_index >= _values.length) {
      throw StateError('No test identifier remains');
    }
    return _values[_index++];
  }
}

final class FixedPrivacyGate implements PrivacyGate {
  FixedPrivacyGate({this.unlockRequired = false});

  bool unlockRequired;

  @override
  Future<bool> isUnlockRequired() async => unlockRequired;

  @override
  void markLocked() {
    unlockRequired = true;
  }

  @override
  void markUnlocked() {
    unlockRequired = false;
  }
}

final class FakeDeviceAuthenticator implements DeviceAuthenticator {
  FakeDeviceAuthenticator({
    this.availabilityResult = DeviceAuthenticationAvailability.available,
    this.authenticationResult = DeviceAuthenticationResult.authenticated,
  });

  DeviceAuthenticationAvailability availabilityResult;
  DeviceAuthenticationResult authenticationResult;
  int authenticationAttempts = 0;

  @override
  Future<DeviceAuthenticationResult> authenticate() async {
    authenticationAttempts += 1;
    return authenticationResult;
  }

  @override
  Future<DeviceAuthenticationAvailability> availability() async {
    return availabilityResult;
  }
}

final class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway({
    Map<OptionalPermission, OperatingSystemPermissionState>? states,
    this.settingsOpened = true,
  }) : states =
           states ?? <OptionalPermission, OperatingSystemPermissionState>{};

  final Map<OptionalPermission, OperatingSystemPermissionState> states;
  bool settingsOpened;

  @override
  Future<bool> openSystemSettings() async => settingsOpened;

  @override
  Future<OperatingSystemPermissionState> status(
    OptionalPermission permission,
  ) async {
    return states[permission] ?? OperatingSystemPermissionState.denied;
  }
}

final class MemorySecureStorageDriver implements SecureStorageDriver {
  final Map<String, String> values = <String, String>{};
  Object? writeFailure;

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }
    values[key] = value;
  }
}

final class TestPrivacyDependencies {
  TestPrivacyDependencies({
    required AppDatabase database,
    FakeDeviceAuthenticator? authenticator,
    FakePermissionGateway? permissionGateway,
  }) : repository = DriftPrivacyRepository(
         database: database,
         clock: FixedClock(DateTime.utc(2026, 7, 26, 12)),
       ),
       authenticator = authenticator ?? FakeDeviceAuthenticator(),
       permissionGateway = permissionGateway ?? FakePermissionGateway(),
       secureStorage = MemorySecureStorageDriver() {
    gate = SessionPrivacyGate(settingsReader: repository);
  }

  final DriftPrivacyRepository repository;
  late final SessionPrivacyGate gate;
  final FakeDeviceAuthenticator authenticator;
  final FakePermissionGateway permissionGateway;
  final MemorySecureStorageDriver secureStorage;

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        privacyRepositoryProvider.overrideWithValue(repository),
        privacyGateProvider.overrideWithValue(gate),
        deviceAuthenticatorProvider.overrideWithValue(authenticator),
        permissionGatewayProvider.overrideWithValue(permissionGateway),
        authTokenStoreProvider.overrideWithValue(
          SecureAuthTokenStore(secureStorage),
        ),
      ],
    );
  }

  Widget buildApp({
    required AppEnvironment environment,
    required SanitizedDiagnostics diagnostics,
    required StartupRepository startupRepository,
  }) {
    return ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        diagnosticsProvider.overrideWithValue(diagnostics),
        startupRepositoryProvider.overrideWithValue(startupRepository),
        privacyRepositoryProvider.overrideWithValue(repository),
        privacyGateProvider.overrideWithValue(gate),
        deviceAuthenticatorProvider.overrideWithValue(authenticator),
        permissionGatewayProvider.overrideWithValue(permissionGateway),
        authTokenStoreProvider.overrideWithValue(
          SecureAuthTokenStore(secureStorage),
        ),
      ],
      child: const NextTransferApp(),
    );
  }
}

final class FailingStartupRepository implements StartupRepository {
  const FailingStartupRepository();

  @override
  Future<OnboardingCheckpoint> beginOrResumeOnboarding() async {
    throw StateError('Injected startup failure');
  }

  @override
  Future<LocalProfile> completeOnboarding() async {
    throw StateError('Injected startup failure');
  }

  @override
  Future<StartupSnapshot> resolveStartup() async {
    throw StateError('Injected startup failure');
  }

  @override
  Future<OnboardingCheckpoint> saveOnboardingDraft(String? displayName) async {
    throw StateError('Injected startup failure');
  }

  @override
  Future<LocalProfile> updateDisplayName(String? displayName) async {
    throw StateError('Injected startup failure');
  }
}

AppDatabase openMemoryDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

DriftStartupRepository buildTestRepository({
  required AppDatabase database,
  PrivacyGate? privacyGate,
  SanitizedDiagnostics? diagnostics,
  IdentifierSource? identifierSource,
}) {
  return DriftStartupRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 26, 12)),
    identifierSource:
        identifierSource ??
        SequenceIdentifierSource(<String>[
          '11111111-1111-4111-8111-111111111111',
        ]),
    privacyGate: privacyGate ?? FixedPrivacyGate(),
    diagnostics: diagnostics ?? SanitizedDiagnostics(),
  );
}
