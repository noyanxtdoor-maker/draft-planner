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
import 'package:rmplanner/app/next_transfer_app.dart'
    show appEnvironmentProvider;
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
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
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

Future<(AppDatabase, DriftPlannerRepository, DriftCalendarEventRepository)>
_buildRepositories() async {
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
  return (database, plannerRepository, calendarRepository);
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
    plannerDateSourceProvider.overrideWithValue(FixedPlannerDateSource(today)),
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
  await prewarmContainer.read(startupControllerProvider.notifier).initialize();
  await tester.pumpAndSettle();

  // Now pump the real planner screen.
  // Keep the injected Planner date source and the current-time source on the
  // same civil date. A real device always has that invariant; without the
  // fixed clock this historical-date fixture would correctly suppress the
  // current-time indicator even when `today` is selected.
  final currentTime = ValueNotifier<DateTime>(
    DateTime(today.year, today.month, today.day, 9, 13),
  );
  addTearDown(currentTime.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: _plannerOverrides(
        database: database,
        privacy: privacy,
        plannerRepository: plannerRepository,
        startupRepository: startup,
        today: today,
      ),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: PlannerScreen(currentTimeListenable: currentTime),
      ),
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
  final widget = tester.widget<Icon>(
    find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
  );
  return widget.color!;
}

Color _primaryColor(WidgetTester tester) {
  // B2-CORRECTION: the today-icon selected state is the semantic Theme
  // Color primary (dark Rose baseline = canonical rose, pixel-identical).
  return Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary;
}

void main() {
  group('Stage B3-R1 Slice C: Today icon visual state', () {
    testWidgets(
      'TEST 1 — Today icon is pink/accent when selected date is today',
      (tester) async {
        final (database, plannerRepository, _) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _today,
          today: _today,
        );
        final color = _iconColor(tester, const Key('planner-calendar-button'));
        expect(
          color,
          _primaryColor(tester),
          reason:
              'icon must use the semantic Theme Color primary when '
              'selected date is today',
        );
      },
    );

    testWidgets(
      'TEST 2a — Today icon is white/on-surface when selected date is yesterday',
      (tester) async {
        final (database, plannerRepository, _) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _yesterday,
          today: _today,
        );
        final color = _iconColor(tester, const Key('planner-calendar-button'));
        expect(
          color,
          isNot(_primaryColor(tester)),
          reason: 'icon must NOT be the accent when viewing yesterday',
        );
        expect(
          color,
          Theme.of(tester.element(find.byType(Scaffold))).colorScheme.onSurface,
          reason: 'icon must use the on-surface color away from today',
        );
      },
    );

    testWidgets(
      'TEST 2b — Today icon is white/on-surface when selected date is tomorrow',
      (tester) async {
        final (database, plannerRepository, _) = await _buildRepositories();
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepository,
          selected: _tomorrow,
          today: _today,
        );
        final color = _iconColor(tester, const Key('planner-calendar-button'));
        expect(
          color,
          isNot(_primaryColor(tester)),
          reason: 'icon must NOT be the accent when viewing tomorrow',
        );
      },
    );

    testWidgets('TEST 3 — Tapping Go to today from yesterday returns to today '
        'and the icon becomes pink', (tester) async {
      final (database, plannerRepository, _) = await _buildRepositories();
      await _pumpPlanner(
        tester: tester,
        database: database,
        plannerRepository: plannerRepository,
        selected: _yesterday,
        today: _today,
      );
      // Pre-tap: icon is not the accent.
      expect(
        _iconColor(tester, const Key('planner-calendar-button')),
        isNot(_primaryColor(tester)),
      );
      // Tap the Go to today button.
      await tester.tap(find.byKey(const Key('planner-today-button')));
      await tester.pumpAndSettle();
      // Post-tap: icon is the accent.
      expect(
        _iconColor(tester, const Key('planner-calendar-button')),
        _primaryColor(tester),
        reason: 'icon must be the accent after returning to today',
      );
      // And the controller's selected date is today.
      final plannerElement = tester.element(find.byType(PlannerScreen));
      final plannerContainer = ProviderScope.containerOf(plannerElement);
      final selected = plannerContainer
          .read(plannerControllerProvider)
          .selectedDate;
      expect(
        selected,
        _today,
        reason: 'planner controller must report today as selected',
      );
    });

    testWidgets('R5-06: Today publishes the correct cached day and final '
        'layout on the first data-bearing frame with no stale Event', (
      tester,
    ) async {
      final (database, plannerRepository, calendarRepository) =
          await _buildRepositories();
      const todayEventId = '22222222-aaaa-4aaa-8aaa-aaaaaaaaaa01';
      const farEventId = '22222222-aaaa-4aaa-8aaa-aaaaaaaaaa02';
      final farAway = _today.addDays(7);
      await _pumpPlanner(
        tester: tester,
        database: database,
        plannerRepository: plannerRepository,
        selected: _today,
        today: _today,
      );
      final profileId =
          (await database.select(database.localProfiles).getSingle()).id;
      await calendarRepository.saveEvent(
        profileId: profileId,
        draft: const CalendarEventDraft(
          id: todayEventId,
          title: 'Today canonical Event',
          timing: CalendarEventTiming.timed,
          startDate: _today,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          timeZoneId: _displayTimeZoneId,
          requiresReport: false,
        ),
      );
      await calendarRepository.saveEvent(
        profileId: profileId,
        draft: CalendarEventDraft(
          id: farEventId,
          title: 'Far stale Event',
          timing: CalendarEventTiming.timed,
          startDate: farAway,
          startMinute: 11 * 60,
          endMinute: 12 * 60,
          timeZoneId: _displayTimeZoneId,
          requiresReport: false,
        ),
      );

      final plannerElement = tester.element(find.byType(PlannerScreen));
      final plannerContainer = ProviderScope.containerOf(plannerElement);
      final planner = plannerContainer.read(plannerControllerProvider.notifier);
      // T0/T1: refresh Today through the canonical repository path so the
      // controller's bounded day cache contains the authoritative Event.
      await planner.refresh();
      await tester.pumpAndSettle();
      final todayOccurrence = (await calendarRepository.readDay(
        profileId: profileId,
        date: _today,
      )).singleWhere((event) => event.eventId == todayEventId);
      final farOccurrence = (await calendarRepository.readDay(
        profileId: profileId,
        date: farAway,
      )).singleWhere((event) => event.eventId == farEventId);

      // T2/T3: navigate away and prove the far schedule is authoritative.
      await planner.selectDate(farAway);
      await tester.pumpAndSettle();
      expect(
        _iconColor(tester, const Key('planner-calendar-button')),
        isNot(_primaryColor(tester)),
        reason: 'precondition: the icon is not the accent away from today',
      );
      expect(
        find.byKey(Key('planner-timed-event-${farOccurrence.id}')),
        findsOneWidget,
      );

      // T4: user intent. T5 is the first rendered frame after the tap.
      await tester.tap(find.byKey(const Key('planner-today-button')));
      await tester.pump();
      final state = plannerContainer.read(plannerControllerProvider);
      expect(
        state.selectedDate,
        _today,
        reason: 'the selected date must switch to today in the same frame',
      );
      expect(
        state.day?.selectedDate,
        _today,
        reason:
            'the first Today frame must carry Today data, not a placeholder',
      );
      final todayEvent = find.byKey(
        Key('planner-timed-event-${todayOccurrence.id}'),
      );
      expect(
        todayEvent,
        findsOneWidget,
        reason: 'the canonical Today Event must be present on the first frame',
      );
      expect(
        find.byKey(Key('planner-timed-event-${farOccurrence.id}')),
        findsNothing,
        reason: 'the old far-date Event must never paint under Today',
      );
      final firstTodayRect = tester.getRect(todayEvent);
      expect(find.text('Jul 31'), findsOneWidget);
      expect(
        find.byKey(const Key('planner-selected-date')),
        findsOneWidget,
        reason: 'the date strip must highlight Today on the first frame',
      );
      expect(
        find.byKey(Key('planner-day-page-${farAway.iso8601}')),
        findsNothing,
        reason: 'the pager must not retain the old date page while loading',
      );
      expect(
        find.byKey(const Key('planner-day-pager-viewport')),
        findsOneWidget,
        reason: 'data reconciliation must not replace the pager with a spinner',
      );
      expect(
        find.byKey(const Key('planner-current-time-line')),
        findsOneWidget,
        reason: 'Today current-time ownership must activate immediately',
      );

      // T6: the canonical refresh may finish and unrelated frames may pump,
      // but unchanged state/data must not mutate the first geometry.
      for (var frame = 0; frame < 8; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
        final laterRect = tester.getRect(todayEvent);
        expect(laterRect.left, closeTo(firstTodayRect.left, 0.5));
        expect(laterRect.width, closeTo(firstTodayRect.width, 0.5));
      }
      await tester.pumpAndSettle();
      expect(
        _iconColor(tester, const Key('planner-calendar-button')),
        _primaryColor(tester),
        reason: 'the icon must be the accent once today is fully loaded',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Stage B3-R1 Slice C: Planner has no pull-to-refresh', () {
    testWidgets(
      'TEST 4 — RefreshProgressIndicator is not present in the Day view',
      (tester) async {
        final (database, plannerRepository, _) = await _buildRepositories();
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
        final (database, plannerRepository, _) = await _buildRepositories();
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
        await tester.fling(scrollable, const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
        expect(
          find.byType(RefreshProgressIndicator),
          findsNothing,
          reason:
              'no refresh indicator should appear after a downward '
              'fling',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Stage B3-R1 Slice C/D2: Pinch dead-zone', () {
    test('TEST 6 — applyDeadZone collapses tiny scale noise to 1.0', () {
      // The Stage B3-R1 Slice D2 contract tightened the dead
      // zone from 0.03 to 0.012 (owner-approved). The contract
      // is:
      //   * exactly 1.0 remains 1.0 (identity)
      //   * tiny pointer noise inside the new dead zone maps
      //     to 1.0 (no spurious zoom)
      //   * the boundary at 1 + 0.012 is inclusive
      //     (`<=`), so a real 1.2% scale is still considered
      //     noise
      //   * noise on both sides of 1.0 is symmetric
      // The previous 1.029 / 0.971 boundary values are now
      // well outside the dead zone and the assertion no longer
      // pins them; the assertion now pins the actual new
      // contract.
      expect(PlannerZoomPolicy.applyDeadZone(1.0), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(1.005), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(1.01), 1.0);
      // 1.011 is comfortably inside the new 0.012 dead zone
      // even with IEEE-754 rounding (1.011 - 1.0 ≈ 0.01099...).
      expect(PlannerZoomPolicy.applyDeadZone(1.011), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(0.995), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(0.99), 1.0);
      expect(PlannerZoomPolicy.applyDeadZone(0.989), 1.0);
    });

    test('TEST 7 — applyDeadZone lets modest realistic scale through', () {
      // The Stage B3-R1 Slice D2 contract requires that a
      // modest realistic pinch scale change becomes visible
      // immediately, with symmetric pinch-out and pinch-in
      // behavior. A 1.5% scale change is the upper bound of
      // the "human intentional pinch" range and must pass
      // through unchanged. The mapping remains monotonic
      // outside the dead zone.
      expect(PlannerZoomPolicy.applyDeadZone(1.015), 1.015);
      expect(PlannerZoomPolicy.applyDeadZone(0.985), 0.985);
      expect(PlannerZoomPolicy.applyDeadZone(1.03), 1.03);
      expect(PlannerZoomPolicy.applyDeadZone(0.97), 0.97);
      expect(PlannerZoomPolicy.applyDeadZone(1.05), 1.05);
      expect(PlannerZoomPolicy.applyDeadZone(0.95), 0.95);
      expect(PlannerZoomPolicy.applyDeadZone(1.5), 1.5);
      expect(PlannerZoomPolicy.applyDeadZone(0.5), 0.5);
      // Pinch-out and pinch-in at the same magnitude must
      // produce equal-magnitude deviations from 1.0, proving
      // the symmetry the owner requires.
      expect(
        (PlannerZoomPolicy.applyDeadZone(1.03) - 1.0).abs(),
        closeTo((1.0 - PlannerZoomPolicy.applyDeadZone(0.97)).abs(), 1e-9),
        reason:
            'pinch-out and pinch-in at the same magnitude '
            'must produce equal-magnitude resolved scale',
      );
    });

    test('TEST 7b — applyDeadZone is monotonic across the boundary', () {
      // Continuity-at-the-threshold: stepping just inside the
      // dead zone and just outside must produce non-decreasing
      // values (for pinch-out) and non-increasing values (for
      // pinch-in). The owner-approved contract is explicit
      // that no jump may occur at the threshold. The values
      // chosen are deliberately inside and outside the new
      // 0.012 dead zone by a comfortable margin so floating-
      // point rounding cannot blur the boundary.
      final inside = PlannerZoomPolicy.applyDeadZone(1.01);
      final outside = PlannerZoomPolicy.applyDeadZone(1.02);
      expect(inside, 1.0);
      expect(outside, 1.02);
      expect(
        outside >= inside,
        isTrue,
        reason:
            'resolved scale must not decrease as scale '
            'crosses the dead-zone boundary from inside to '
            'outside on the pinch-out side',
      );
      final insideIn = PlannerZoomPolicy.applyDeadZone(0.99);
      final outsideIn = PlannerZoomPolicy.applyDeadZone(0.98);
      expect(insideIn, 1.0);
      expect(outsideIn, 0.98);
      expect(
        outsideIn <= insideIn,
        isTrue,
        reason:
            'resolved scale must not increase as scale '
            'crosses the dead-zone boundary from inside to '
            'outside on the pinch-in side',
      );
    });

    test('TEST 8 — clampAbsolute honors the absolute safety range', () {
      expect(PlannerZoomPolicy.clampAbsolute(10), 20);
      expect(PlannerZoomPolicy.clampAbsolute(20), 20);
      expect(PlannerZoomPolicy.clampAbsolute(60), 60);
      expect(PlannerZoomPolicy.clampAbsolute(320), 320);
      expect(PlannerZoomPolicy.clampAbsolute(400), 320);
    });
  });
}
