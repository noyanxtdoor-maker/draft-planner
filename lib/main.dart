import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/security/auth_token_store.dart';
import 'package:rmplanner/core/security/privacy_gate.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/task_event_link_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/data/drift_privacy_repository.dart';
import 'package:rmplanner/features/privacy/data/local_auth_device_authenticator.dart';
import 'package:rmplanner/features/privacy/data/permission_handler_gateway.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/settings/data/drift_start_of_week_repository.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/data/drift_startup_repository.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/data/drift_weekly_planning_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Planner Polish Delta 2: the app is portrait-only on every route, sheet,
  // and dialog, regardless of the Android auto-rotate setting.  The manifest
  // `screenOrientation="portrait"` protects the native Activity before the
  // first frame; this Flutter-level lock keeps the engine portrait for the
  // whole session and prevents any rotation-driven re-layout.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

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
  final eventTypeRepository = DriftEventTypeRepository(
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
  final indicatorRepository = DriftIndicatorRepository(
    database: database,
    clock: clock,
    calendarEvents: calendarEventRepository,
  );
  final goalRepository = DriftGoalRepository(
    database: database,
    clock: clock,
    identifiers: const UuidIdentifierSource(),
  );
  final weeklyPlanningRepository = DriftWeeklyPlanningRepository(
    database: database,
    clock: clock,
    identifiers: const UuidIdentifierSource(),
    timeZones: calendarEventTimeZones,
    indicators: indicatorRepository,
  );
  final contactRepository = DriftContactRepository(
    database: database,
    clock: clock,
    identifiers: const UuidIdentifierSource(),
  );
  final taskEventLinkCoordinator = DriftTaskEventLinkCoordinator(
    database: database,
    calendarEvents: calendarEventRepository,
    links: taskEventLinkRepository,
  );
  final startOfWeekRepository = DriftStartOfWeekRepository(
    database: database,
    clock: clock,
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
        eventTypeRepositoryProvider.overrideWithValue(eventTypeRepository),
        outcomeReportingRepositoryProvider.overrideWithValue(
          outcomeReportingRepository,
        ),
        plannerRepositoryProvider.overrideWithValue(plannerRepository),
        indicatorRepositoryProvider.overrideWithValue(indicatorRepository),
        goalRepositoryProvider.overrideWithValue(goalRepository),
        contactRepositoryProvider.overrideWithValue(contactRepository),
        weeklyPlanningRepositoryProvider.overrideWithValue(
          weeklyPlanningRepository,
        ),
        startOfWeekRepositoryProvider.overrideWithValue(startOfWeekRepository),
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
