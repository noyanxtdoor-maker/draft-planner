// Stage B3-R1 Slice C: focused tests for the Today icon visual
// state, the absence of pull-to-refresh on the Planner, and the
// pinch dead-zone behaviour.
//
// The three concerns are intentionally grouped in one file because
// they share the same PlannerScreen widget tree and the same
// ProviderScope override pattern. Tests use the production
// PlannerScreen via a focused MaterialApp(home: PlannerScreen(...))
// harness so the assertions inspect rendered Icon colour and
// rendered widget tree, not just widget presence.
//
// The clock source is the same deterministic PlannerDateSource used
// by the current-time and pinch suites; the harness takes a
// PlannerDate "today" via a FixedPlannerDateSource override so the
// tests can pick today / yesterday / tomorrow freely.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/next_transfer_app.dart' show appEnvironmentProvider;
import 'package:rmplanner/app/theme/app_theme.dart' show AppTheme;
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/security/auth_token_store.dart';
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
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart'
    show PlannerZoomPolicy;
import 'package:rmplanner/features/planner/presentation/planner_screen.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/data/drift_startup_repository.dart';

import '../../../support/test_dependencies.dart';

const String _displayTimeZoneId = 'Asia/Manila';

const PlannerDate _today = PlannerDate(year: 2026, month: 7, day: 31);
const PlannerDate _yesterday = PlannerDate(year: 2026, month: 7, day: 30);
const PlannerDate _tomorrow = PlannerDate(year: 2026, month: 8, day: 1);

Future<(AppDatabase, DriftPlannerRepository)> _buildRepositories() async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
  final timeZones = IanaCalendarEventTimeZones(
    displayTimeZoneId: _displayTimeZoneId,
  );
  final linkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final outcomeReportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final calendarRepository = DriftCalendarEventRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    timeZones: timeZones,
    taskContextSource: linkRepository,
    linkContextTransfer: linkRepository,
    reportSource: outcomeReportingRepository,
  );
  final plannerRepository = DriftPlannerRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    calendarSource: calendarRepository,
    taskContextSource: linkRepository,
    historicalEffectReader: outcomeReportingRepository,
  );
  return (database, plannerRepository);
}

List<Override> _plannerOverrides({
  required AppDatabase database,
  required TestPrivacyDependencies privacy,
  required DriftPlannerRepository plannerRepository,
  required DriftStartupRepository startupRepository,
  required PlannerDate today,
}) {
  final linkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final outcomeReportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final eventTypeRepository = DriftEventTypeRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
  );
  final calendarRepository = DriftCalendarEventRepository(
    database: database,
    clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    timeZones: IanaCalendarEventTimeZones(
      displayTimeZoneId: _displayTimeZoneId,
    ),
    taskContextSource: linkRepository,
    linkContextTransfer: linkRepository,
    reportSource: outcomeReportingRepository,
  );
  return <Override>[
    appEnvironmentProvider.overrideWithValue(
      const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
    ),
    diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
    startupRepositoryProvider.overrideWithValue(startupRepository),
    privacyRepositoryProvider.overrideWithValue(privacy.repository),
    privacyGateProvider.overrideWithValue(privacy.gate),
    deviceAuthenticatorProvider.overrideWithValue(privacy.authenticator),
    permissionGatewayProvider.overrideWithValue(privacy.permissionGateway),
    authTokenStoreProvider.overrideWithValue(
      SecureAuthTokenStore(privacy.secureStorage),
    ),
    calendarEventRepositoryProvider.overrideWithValue(calendarRepository),
    eventTypeRepositoryProvider.overrideWithValue(eventTypeRepository),
    outcomeReportingRepositoryProvider.overrideWithValue(
      outcomeReportingRepository,
    ),
    plannerRepositoryProvider.overrideWithValue(plannerRepository),
    taskEventLinkRepositoryProvider.overrideWithValue(linkRepository),
    plannerDateSourceProvider.overrideWithValue(
      FixedPlannerDateSource(today),
    ),
  ];
}

Future<void> _pumpPlanner({
  required WidgetTester tester,
  required AppDatabase database,
  required DriftPlannerRepository plannerRepository,
  required PlannerDate selected,
  required PlannerDate today,
  Future<void> Function(WidgetTester)? extraOnPumped,
}) async {
  tester.view.physicalSize = const Size(862, 1824);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();

  // Pre-warm: force the startup controller to initialize() so the
  // Planner controller's microtask sees StartupReady.
  await tester.pumpWidget(
    ProviderScope(
      overrides: _plannerOverrides(
        database: database,
        privacy: privacy,
        plannerRepository: plannerRepository,
        startupRepository: startup,
        today: today,
      ),
      child: const MaterialApp(home: _StartupPrewarm()),
    ),
  );
  final prewarmElement = tester.element(find.byType(_StartupPrewarm));
  final prewarmContainer = ProviderScope.containerOf(prewarmElement);
  await prewarmContainer
      .read(startupControllerProvider.notifier)
      .initialize();
  await tester.pumpAndSettle();

  // Now pump the real planner screen.
  await tester.pumpWidget(
    ProviderScope(
      overrides: _plannerOverrides(
        database: database,
        privacy: privacy,
        plannerRepository: plannerRepository,
        startupRepository: startup,
        today: today,
      ),
      child: const MaterialApp(home: PlannerScreen()),
    ),
  );
  await tester.pumpAndSettle();

  // Drive the planner controller to the requested selected date.
  final plannerElement = tester.element(find.byType(PlannerScreen));
  final plannerContainer = ProviderScope.containerOf(plannerElement);
  await plannerContainer
      .read(plannerControllerProvider.notifier)
      .selectDate(selected);
  await tester.pumpAndSettle();

  if (extraOnPumped != null) {
    await extraOnPumped(tester);
  }
}

/// Tiny widget that anchors a ProviderContainer so the startup
/// controller's initialize() runs before the PlannerScreen is built.
class _StartupPrewarm extends ConsumerWidget {
  const _StartupPrewarm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(startupControllerProvider);
    return const SizedBox.shrink();
  }
}

Color _iconColor(WidgetTester tester, Key key) {
  final widget = tester.widget<Icon>(find.descendant(
    of: find.byKey(key),
    matching: find.byType(Icon),
  ));
  return widget.color!;
}

void main() {
  group('Stage B3-R1 Slice C: Today icon visual state', () {
    testWidgets(
      'TEST 1 — Today icon is pink/accent when selected date is today',
      (tester) async {
        final (database, plannerRepository) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _today,
          today: _today,
        );
        final color = _iconColor(
          tester,
          const Key('planner-calendar-button'),
        );
        expect(color, AppTheme.rose,
            reason: 'icon must use the Next Transfer accent when selected '
                'date is today');
      },
    );

    testWidgets(
      'TEST 2a — Today icon is white/on-surface when selected date is yesterday',
      (tester) async {
        final (database, plannerRepository) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _yesterday,
          today: _today,
        );
        final color = _iconColor(
          tester,
          const Key('planner-calendar-button'),
        );
        expect(color, isNot(AppTheme.rose),
            reason: 'icon must NOT be pink when viewing yesterday');
        expect(color, Theme.of(tester.element(find.byType(Scaffold))).colorScheme.onSurface,
            reason: 'icon must use the on-surface color away from today');
      },
    );

    testWidgets(
      'TEST 2b — Today icon is white/on-surface when selected date is tomorrow',
      (tester) async {
        final (database, plannerRepository) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _tomorrow,
          today: _today,
        );
        final color = _iconColor(
          tester,
          const Key('planner-calendar-button'),
        );
        expect(color, isNot(AppTheme.rose),
            reason: 'icon must NOT be pink when viewing tomorrow');
      },
    );

    testWidgets(
      'TEST 3 — Tapping Go to today from yesterday returns to today '
      'and the icon becomes pink',
      (tester) async {
        final (database, plannerRepository) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _yesterday,
          today: _today,
        );
        // Pre-tap: icon is not pink.
        expect(
          _iconColor(tester, const Key('planner-calendar-button')),
          isNot(AppTheme.rose),
        );
        // Tap the Go to today button.
        await tester.tap(find.byKey(const Key('planner-today-button')));
        await tester.pumpAndSettle();
        // Post-tap: icon is pink.
        expect(
          _iconColor(tester, const Key('planner-calendar-button')),
          AppTheme.rose,
          reason: 'icon must be pink after returning to today',
        );
        // And the controller's selected date is today.
        final plannerElement = tester.element(find.byType(PlannerScreen));
        final plannerContainer = ProviderScope.containerOf(plannerElement);
        final selected = plannerContainer
            .read(plannerControllerProvider)
            .selectedDate;
        expect(selected, _today,
            reason: 'planner controller must report today as selected');
      },
    );
  });

  group('Stage B3-R1 Slice C: Planner has no pull-to-refresh', () {
    testWidgets(
      'TEST 4 — RefreshProgressIndicator is not present in the Day view',
      (tester) async {
        final (database, plannerRepository) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _today,
          today: _today,
        );
        expect(
          find.byType(RefreshProgressIndicator),
          findsNothing,
          reason: 'Planner Day view must not render a refresh indicator',
        );
      },
    );

    testWidgets(
      'TEST 5 — Downward overscroll on the timeline does not trigger a refresh callback',
      (tester) async {
        final (database, plannerRepository) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _today,
          today: _today,
        );
        // Pull down inside the timeline viewport using a
        // generous swipe distance (well beyond the default
        // RefreshIndicator trigger of ~140 logical pixels).
        // With the RefreshIndicator removed, this gesture becomes
        // an ordinary scroll that does not produce a refresh
        // spinner.
        final scrollable = find.byKey(const Key('planner-day-scroll'));
        expect(scrollable, findsOneWidget);
        await tester.fling(
          scrollable,
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(RefreshProgressIndicator),
          findsNothing,
          reason: 'no refresh indicator should appear after a downward '
              'fling',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Stage B3-R1 Slice C: Pinch dead-zone', () {
    test('TEST 6 — applyDeadZone collapses tiny scale noise to 1.0', () {
      expect(PlannerZoomPolicy.applyDeadZone(1.0), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(1.01), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(0.99), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(1.029), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(0.971), 1.0);
    });

    test('TEST 7 — applyDeadZone preserves scale beyond the dead zone', () {
      expect(PlannerZoomPolicy.applyDeadZone(1.05), 1.05);
      expect(PlannerZoomPolicy.applyDeadZone(0.9), 0.9);
      expect(PlannerZoomPolicy.applyDeadZone(1.5), 1.5);
      expect(PlannerZoomPolicy.applyDeadZone(0.5), 0.5);
    });

    test('TEST 8 — clamp honors the locked Stage B1 preset bounds', () {
      expect(PlannerZoomPolicy.clamp(40), 44);
      expect(PlannerZoomPolicy.clamp(43), 44);
      expect(PlannerZoomPolicy.clamp(60), 60);
      expect(PlannerZoomPolicy.clamp(88), 88);
      expect(PlannerZoomPolicy.clamp(89), 88);
      expect(PlannerZoomPolicy.clamp(130), 88);
    });
  });
}
