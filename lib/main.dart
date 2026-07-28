import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/security/auth_token_store.dart';
import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/task_event_link_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/data/drift_privacy_repository.dart';
import 'package:rmplanner/features/privacy/data/local_auth_device_authenticator.dart';
import 'package:rmplanner/features/privacy/data/permission_handler_gateway.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/data/drift_startup_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = AppEnvironment.fromDartDefines();
  final diagnostics = SanitizedDiagnostics(
    emitToDebugConsole: environment.name == AppEnvironmentName.local,
  );
  final database = AppDatabase.defaults();
  const clock = SystemAppClock();
  final privacyRepository = DriftPrivacyRepository(
    database: database,
    clock: clock,
  );
  final privacyGate = SessionPrivacyGate(settingsReader: privacyRepository);
  final authTokenStore = SecureAuthTokenStore(FlutterSecureStorageDriver());
  final calendarEventTimeZones = await IanaCalendarEventTimeZones.forDevice();
  final taskEventLinkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: clock,
  );
  final outcomeReportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: clock,
  );
  final calendarEventRepository = DriftCalendarEventRepository(
    database: database,
    clock: clock,
    timeZones: calendarEventTimeZones,
    taskContextSource: taskEventLinkRepository,
    linkContextTransfer: taskEventLinkRepository,
    reportSource: outcomeReportingRepository,
  );
  final plannerRepository = DriftPlannerRepository(
    database: database,
    clock: clock,
    calendarSource: calendarEventRepository,
    taskContextSource: taskEventLinkRepository,
    historicalEffectReader: outcomeReportingRepository,
  );
  final taskEventLinkCoordinator = DriftTaskEventLinkCoordinator(
    database: database,
    calendarEvents: calendarEventRepository,
    links: taskEventLinkRepository,
  );
  final startupRepository = DriftStartupRepository(
    database: database,
    clock: clock,
    identifierSource: const UuidIdentifierSource(),
    privacyGate: privacyGate,
    diagnostics: diagnostics,
  );

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
        diagnosticsProvider.overrideWithValue(diagnostics),
        startupRepositoryProvider.overrideWithValue(startupRepository),
        privacyRepositoryProvider.overrideWithValue(privacyRepository),
        privacyGateProvider.overrideWithValue(privacyGate),
        deviceAuthenticatorProvider.overrideWithValue(
          LocalAuthDeviceAuthenticator(),
        ),
        permissionGatewayProvider.overrideWithValue(
          const PermissionHandlerGateway(),
        ),
        authTokenStoreProvider.overrideWithValue(authTokenStore),
        calendarEventRepositoryProvider.overrideWithValue(
          calendarEventRepository,
        ),
        outcomeReportingRepositoryProvider.overrideWithValue(
          outcomeReportingRepository,
        ),
        plannerRepositoryProvider.overrideWithValue(plannerRepository),
        taskEventLinkRepositoryProvider.overrideWithValue(
          taskEventLinkRepository,
        ),
        taskEventLinkCoordinatorProvider.overrideWithValue(
          taskEventLinkCoordinator,
        ),
      ],
      child: const NextTransferApp(),
    ),
  );
}
