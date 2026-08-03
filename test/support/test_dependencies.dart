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
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/planner_repository.dart';
import 'package:rmplanner/features/planner/application/task_event_link_providers.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
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
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_repository.dart';
import 'package:rmplanner/features/weekly_planning/data/drift_weekly_planning_repository.dart';

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

final class FixedPlannerDateSource implements PlannerDateSource {
  const FixedPlannerDateSource(this.value);

  final PlannerDate value;

  @override
  PlannerDate today() => value;
}

final class MemoryPlannerCalendarSource implements PlannerCalendarSource {
  MemoryPlannerCalendarSource([this.items = const <PlannerCalendarItem>[]]);

  List<PlannerCalendarItem> items;

  @override
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  }) async {
    return items.where((item) => item.date == date).toList(growable: false);
  }
}

final class FailingTaskWriteGuard implements TaskWriteGuard {
  const FailingTaskWriteGuard();

  @override
  Future<void> beforeCommit() async {
    throw StateError('Injected task write failure');
  }
}

final class MemoryPlannerTaskContextSource implements PlannerTaskContextSource {
  const MemoryPlannerTaskContextSource(this.contexts);

  final Map<String, PlannerTaskContext> contexts;

  @override
  Future<PlannerTaskContext> readContext(String taskId) async {
    return contexts[taskId] ?? const PlannerTaskContext();
  }
}

final class FixedHistoricalEffectReader implements TaskHistoricalEffectReader {
  const FixedHistoricalEffectReader(this.hasEffects);

  final bool hasEffects;

  @override
  Future<bool> hasReportOrLedgerEffect(String taskId) async => hasEffects;
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
    PlannerRepository? plannerRepository,
    CalendarEventRepository? calendarEventRepository,
    PlannerDateSource plannerDateSource = const FixedPlannerDateSource(
      PlannerDate(year: 2026, month: 7, day: 27),
    ),
    IdentifierSource? plannerIdentifierSource,
    WeeklyPlanningRepository? weeklyPlanningRepository,
  }) {
    final linkRepository = DriftTaskEventLinkRepository(
      database: repository.database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    final outcomeReportingRepository = DriftOutcomeReportingRepository(
      database: repository.database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    final eventTypeRepository = DriftEventTypeRepository(
      database: repository.database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    );
    final resolvedCalendarEventRepository =
        calendarEventRepository ??
        DriftCalendarEventRepository(
          database: repository.database,
          clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
          timeZones: IanaCalendarEventTimeZones(
            displayTimeZoneId: 'Asia/Manila',
          ),
          taskContextSource: linkRepository,
          linkContextTransfer: linkRepository,
          reportSource: outcomeReportingRepository,
        );
    final resolvedPlannerRepository =
        plannerRepository ??
        DriftPlannerRepository(
          database: repository.database,
          clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
          calendarSource: resolvedCalendarEventRepository,
          taskContextSource: linkRepository,
          historicalEffectReader: outcomeReportingRepository,
        );
    final linkCoordinator = DriftTaskEventLinkCoordinator(
      database: repository.database,
      calendarEvents: resolvedCalendarEventRepository,
      links: linkRepository,
    );
    final indicatorRepository = DriftIndicatorRepository(
      database: repository.database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      calendarEvents: resolvedCalendarEventRepository,
    );
    final resolvedWeeklyPlanningRepository =
        weeklyPlanningRepository ??
        DriftWeeklyPlanningRepository(
          database: repository.database,
          clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
          identifiers: const UuidIdentifierSource(),
          timeZones: IanaCalendarEventTimeZones(
            displayTimeZoneId: 'Asia/Manila',
          ),
          indicators: indicatorRepository,
        );
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
        calendarEventRepositoryProvider.overrideWithValue(
          resolvedCalendarEventRepository,
        ),
        eventTypeRepositoryProvider.overrideWithValue(eventTypeRepository),
        outcomeReportingRepositoryProvider.overrideWithValue(
          outcomeReportingRepository,
        ),
        plannerRepositoryProvider.overrideWithValue(resolvedPlannerRepository),
        indicatorRepositoryProvider.overrideWithValue(indicatorRepository),
        weeklyPlanningRepositoryProvider.overrideWithValue(
          resolvedWeeklyPlanningRepository,
        ),
        taskEventLinkRepositoryProvider.overrideWithValue(linkRepository),
        taskEventLinkCoordinatorProvider.overrideWithValue(linkCoordinator),
        plannerDateSourceProvider.overrideWithValue(plannerDateSource),
        if (plannerIdentifierSource != null)
          plannerIdentifierSourceProvider.overrideWithValue(
            plannerIdentifierSource,
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
