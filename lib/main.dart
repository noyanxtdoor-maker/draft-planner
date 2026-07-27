import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/data/drift_startup_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.fromDartDefines();
  final diagnostics = SanitizedDiagnostics(
    emitToDebugConsole: environment.name == AppEnvironmentName.local,
  );
  final database = AppDatabase.defaults();
  final startupRepository = DriftStartupRepository(
    database: database,
    clock: const SystemAppClock(),
    identifierSource: const UuidIdentifierSource(),
    privacyGate: const UnconfiguredPrivacyGate(),
    diagnostics: diagnostics,
  );

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        diagnosticsProvider.overrideWithValue(diagnostics),
        startupRepositoryProvider.overrideWithValue(startupRepository),
      ],
      child: const NextTransferApp(),
    ),
  );
}
