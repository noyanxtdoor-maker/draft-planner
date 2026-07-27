import 'package:drift/native.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/core/time/app_clock.dart';
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
  const FixedPrivacyGate({this.unlockRequired = false});

  final bool unlockRequired;

  @override
  Future<bool> isUnlockRequired() async => unlockRequired;
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
  PrivacyGate privacyGate = const FixedPrivacyGate(),
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
    privacyGate: privacyGate,
    diagnostics: diagnostics ?? SanitizedDiagnostics(),
  );
}
