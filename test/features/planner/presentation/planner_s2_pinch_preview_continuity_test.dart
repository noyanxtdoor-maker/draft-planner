// S2 — pinch preview continuity.
//
// S2A freezes the offscreen previous/next preview columns on the committed
// hour height while a two-finger pinch is live, so the centered page alone
// consumes the raw pinch frames and the offscreen pages do not re-resolve
// display geometry per frame. The previews advance to the final committed
// height exactly once when the pinch persists, before a horizontal swipe can
// expose them.
//
// These tests assert the pack-22 matrix subset that is deterministic in a
// widget test:
//   A/B  slow pinch out/in  — centered page scales mid-gesture
//   G/H/I focal points      — minute-under-focal stays under the fingers
//   N    pinch -> immediate day swipe — S1B remains perfect, final zoom on
//        all pages, no blank page
//   O    day swipe -> immediate pinch
//   Q    saved zoom persists across release
//   R    two-pointer pinch beats vertical scroll
//
// Preview pages are read via the `planner-day-page-<date>` keys; the
// centered page via `planner-timed-event-<id>`; the preview event blocks via
// `planner-pager-preview-event-<id>`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/next_transfer_app.dart'
    show appEnvironmentProvider;
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
import 'package:rmplanner/features/planner/presentation/planner_screen.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/data/drift_startup_repository.dart';

import '../../../support/test_dependencies.dart';

const String _displayTimeZoneId = 'Asia/Manila';
const PlannerDate _selected = PlannerDate(year: 2026, month: 7, day: 27);
const String _scheduledEventId = '10101010-1010-4101-8101-101010101010';
const String _prevEventId = '20202020-2020-4202-8202-202020202020';
const String _nextEventId = '30303030-3030-4303-8303-303030303030';

class _StartupPrewarm extends ConsumerWidget {
  const _StartupPrewarm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(startupControllerProvider);
    return const SizedBox.shrink();
  }
}

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
  await tester.pumpWidget(
    ProviderScope(
      overrides: _plannerOverrides(
        database: database,
        privacy: privacy,
        plannerRepository: plannerRepository,
        startupRepository: startup,
        today: _selected,
      ),
      child: const MaterialApp(home: _StartupPrewarm()),
    ),
  );
  final prewarmElement = tester.element(find.byType(_StartupPrewarm));
  final prewarmContainer = ProviderScope.containerOf(prewarmElement);
  await prewarmContainer.read(startupControllerProvider.notifier).initialize();
  await tester.pumpAndSettle();
  await tester.pumpWidget(
    ProviderScope(
      overrides: _plannerOverrides(
        database: database,
        privacy: privacy,
        plannerRepository: plannerRepository,
        startupRepository: startup,
        today: _selected,
      ),
      child: MaterialApp(
        home: PlannerScreen(
          currentTimeListenable: ValueNotifier<DateTime>(
            DateTime(2026, 7, 27, 12, 0),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final plannerElement = tester.element(find.byType(PlannerScreen));
  final plannerContainer = ProviderScope.containerOf(plannerElement);
  await plannerContainer
      .read(plannerControllerProvider.notifier)
      .selectDate(_selected);
  await tester.pumpAndSettle();
}

CalendarEventDraft _draft({
  required String id,
  required int startMinute,
  required int endMinute,
  PlannerDate? date,
}) {
  return CalendarEventDraft(
    id: id,
    title: 'S2 fixture',
    timing: CalendarEventTiming.timed,
    startDate: date ?? _selected,
    startMinute: startMinute,
    endMinute: endMinute,
    requiresReport: false,
    timeZoneId: _displayTimeZoneId,
  );
}

Future<void> _seedEvents(
  DriftCalendarEventRepository calendarRepository,
  AppDatabase database,
) async {
  final profile = await buildTestRepository(
    database: database,
  ).completeOnboarding();
  final prev = _selected.addDays(-1);
  final next = _selected.addDays(1);
  for (final draft in <CalendarEventDraft>[
    // A 60-minute block on the selected day: 60 px tall at the default
    // 60 px/hour hour height.
    _draft(id: _scheduledEventId, startMinute: 9 * 60, endMinute: 10 * 60),
    _draft(
      id: _prevEventId,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      date: prev,
    ),
    _draft(
      id: _nextEventId,
      startMinute: 9 * 60,
      endMinute: 10 * 60,
      date: next,
    ),
  ]) {
    await calendarRepository.saveEvent(profileId: profile.id, draft: draft);
  }
}

String _occurrenceIdFor(String eventId, {PlannerDate? date}) {
  return CalendarEventOccurrenceIdentity.forDate(
    eventId: eventId,
    originalDate: date ?? _selected,
  );
}

Finder _centeredBlock(String eventId, {PlannerDate? date}) {
  return find.byKey(
    Key('planner-timed-event-${_occurrenceIdFor(eventId, date: date)}'),
  );
}

Finder _previewBlock(String eventId, {required PlannerDate date}) {
  return find.byKey(
    Key('planner-pager-preview-event-${_occurrenceIdFor(eventId, date: date)}'),
  );
}

String _selectedDateIso(WidgetTester tester) {
  final selectedSemantics = find.byKey(const Key('planner-selected-date'));
  expect(selectedSemantics, findsOneWidget);
  final widget = tester.widget<Semantics>(selectedSemantics);
  final label = widget.properties.label!;
  final matcher = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(label);
  return matcher!.group(1)!;
}

Offset _visibleZoomCenter(WidgetTester tester) {
  final canvas = tester.getRect(find.byKey(const Key('planner-zoom-surface')));
  final viewport = tester.getRect(find.byKey(const Key('planner-day-scroll')));
  final visible = canvas.intersect(viewport);
  expect(visible.height, greaterThan(60));
  return visible.center;
}

/// Two-finger pinch-out by `totalGap` logical pixels across `steps` staged
/// moves, pumping after each. Returns before pointer release so the test can
/// assert mid-gesture state.
Future<({TestGesture first, TestGesture second})> _pinchOut(
  WidgetTester tester, {
  required Offset center,
  required double totalGap,
  int steps = 6,
}) async {
  final first = await tester.startGesture(
    Offset(center.dx, center.dy - 40),
    pointer: 1,
  );
  final second = await tester.startGesture(
    Offset(center.dx, center.dy + 40),
    pointer: 2,
  );
  await tester.pump();
  for (var i = 0; i < steps; i++) {
    await first.moveBy(Offset(0, -totalGap / steps));
    await second.moveBy(Offset(0, totalGap / steps));
    await tester.pump();
  }
  return (first: first, second: second);
}

void main() {
  group('S2 pinch preview continuity', () {
    testWidgets(
      'A — centered page scales mid-pinch while offscreen previews stay on '
      'the committed height, then advance once at pinch end',
      (tester) async {
        final (database, plannerRepo, calendarRepo) =
            await _buildRepositories();
        await _seedEvents(calendarRepo, database);
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepo,
        );
        final prevDate = _selected.addDays(-1);
        final nextDate = _selected.addDays(1);
        final centerBlock = _centeredBlock(_scheduledEventId);
        final prevBlock = _previewBlock(_prevEventId, date: prevDate);
        final nextBlock = _previewBlock(_nextEventId, date: nextDate);
        expect(centerBlock, findsOneWidget);
        expect(prevBlock, findsOneWidget);
        expect(nextBlock, findsOneWidget);
        final centerBefore = tester.widget<Positioned>(centerBlock);
        final prevBefore = tester.widget<Positioned>(prevBlock);
        final nextBefore = tester.widget<Positioned>(nextBlock);
        // Default hour height 60 -> 60-minute Event is 60 px tall on every
        // page before the gesture.
        expect(centerBefore.height, closeTo(60.0, 0.5));
        expect(prevBefore.height, closeTo(60.0, 0.5));
        expect(nextBefore.height, closeTo(60.0, 0.5));

        final center = _visibleZoomCenter(tester);
        final gestures = await _pinchOut(tester, center: center, totalGap: 120);
        // Mid-gesture: the centered page has scaled up with the live pinch;
        // the offscreen previews remain frozen on the committed height.
        final centerMid = tester.widget<Positioned>(centerBlock);
        final prevMid = tester.widget<Positioned>(prevBlock);
        final nextMid = tester.widget<Positioned>(nextBlock);
        expect(centerMid.height!, greaterThan(centerBefore.height! + 10));
        expect(prevMid.height, closeTo(60.0, 0.5));
        expect(nextMid.height, closeTo(60.0, 0.5));

        await gestures.first.up();
        await gestures.second.up();
        await tester.pumpAndSettle();
        // After the pinch persists, every page uses the final committed zoom
        // so the next swipe exposes previews already at the final height.
        final centerAfter = tester.widget<Positioned>(centerBlock);
        final prevAfter = tester.widget<Positioned>(prevBlock);
        final nextAfter = tester.widget<Positioned>(nextBlock);
        expect(centerAfter.height, closeTo(centerMid.height!, 0.5));
        expect(prevAfter.height, closeTo(centerAfter.height!, 0.5));
        expect(nextAfter.height, closeTo(centerAfter.height!, 0.5));
      },
    );

    testWidgets(
      'N — pinch then immediate left swipe: correct final zoom on all '
      'pages, correct dates, no blank page',
      (tester) async {
        final (database, plannerRepo, calendarRepo) =
            await _buildRepositories();
        await _seedEvents(calendarRepo, database);
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepo,
        );
        final center = _visibleZoomCenter(tester);
        final gestures = await _pinchOut(tester, center: center, totalGap: 120);
        await gestures.first.up();
        await gestures.second.up();
        await tester.pumpAndSettle();
        final zoomedCenterHeight = tester
            .widget<Positioned>(_centeredBlock(_scheduledEventId))
            .height!;
        expect(zoomedCenterHeight, greaterThan(70));

        // Immediate left swipe to the next day.
        final swipeStart = Offset(center.dx + 150, center.dy);
        final swipe = await tester.startGesture(swipeStart);
        for (var i = 0; i < 8; i++) {
          await swipe.moveBy(Offset(-40, 0));
          await tester.pump();
        }
        await swipe.up();
        await tester.pumpAndSettle();

        // The next day is now centered; its Event uses the FINAL committed
        // zoom (no stale pre-pinch preview), and no blank loading page.
        final nextDayBlock = _centeredBlock(
          _nextEventId,
          date: _selected.addDays(1),
        );
        expect(nextDayBlock, findsOneWidget);
        final nextDayHeight = tester.widget<Positioned>(nextDayBlock).height!;
        expect(nextDayHeight, closeTo(zoomedCenterHeight, 0.5));
        expect(find.byKey(const Key('planner-loading-day-')), findsNothing);
      },
    );

    testWidgets(
      'O — day swipe then immediate pinch: pinch still owns the gesture and '
      'scales the newly centered page',
      (tester) async {
        final (database, plannerRepo, calendarRepo) =
            await _buildRepositories();
        await _seedEvents(calendarRepo, database);
        await _pumpPlanner(
          tester: tester,
          database: database,
          plannerRepository: plannerRepo,
        );
        // First swipe left to next day.
        final center = _visibleZoomCenter(tester);
        final swipeStart = Offset(center.dx + 150, center.dy);
        final swipe = await tester.startGesture(swipeStart);
        for (var i = 0; i < 8; i++) {
          await swipe.moveBy(Offset(-40, 0));
          await tester.pump();
        }
        await swipe.up();
        await tester.pumpAndSettle();
        final nextDayBlock = _centeredBlock(
          _nextEventId,
          date: _selected.addDays(1),
        );
        expect(nextDayBlock, findsOneWidget);
        final before = tester.widget<Positioned>(nextDayBlock).height!;
        expect(before, closeTo(60.0, 0.5));

        // Immediate pinch-out on the newly centered page.
        final gestures = await _pinchOut(
          tester,
          center: _visibleZoomCenter(tester),
          totalGap: 120,
        );
        final mid = tester.widget<Positioned>(nextDayBlock).height!;
        expect(mid, greaterThan(before + 10));
        await gestures.first.up();
        await gestures.second.up();
        await tester.pumpAndSettle();
      },
    );

    testWidgets('Q — saved zoom persists after release/reopen of the Planner', (
      tester,
    ) async {
      final (database, plannerRepo, calendarRepo) = await _buildRepositories();
      await _seedEvents(calendarRepo, database);
      await _pumpPlanner(
        tester: tester,
        database: database,
        plannerRepository: plannerRepo,
      );
      final center = _visibleZoomCenter(tester);
      final gestures = await _pinchOut(tester, center: center, totalGap: 150);
      await gestures.first.up();
      await gestures.second.up();
      await tester.pumpAndSettle();
      final zoomed = tester
          .widget<Positioned>(_centeredBlock(_scheduledEventId))
          .height!;
      expect(zoomed, greaterThan(70));

      // Rebuild the whole Planner (simulated reopen) and verify the saved
      // zoom is applied to the fresh centered page.
      await tester.pumpWidget(
        ProviderScope(
          overrides: _plannerOverrides(
            database: database,
            privacy: TestPrivacyDependencies(database: database),
            plannerRepository: plannerRepo,
            startupRepository: buildTestRepository(
              database: database,
              privacyGate: TestPrivacyDependencies(database: database).gate,
            ),
            today: _selected,
          ),
          child: MaterialApp(
            home: PlannerScreen(
              currentTimeListenable: ValueNotifier<DateTime>(
                DateTime(2026, 7, 27, 12, 0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reopened = tester
          .widget<Positioned>(_centeredBlock(_scheduledEventId))
          .height!;
      expect(reopened, closeTo(zoomed, 0.5));
    });

    testWidgets('R — two-pointer pinch beats vertical scroll: no scroll offset '
        'accumulation mid-pinch and one-finger scroll still works after', (
      tester,
    ) async {
      final (database, plannerRepo, calendarRepo) = await _buildRepositories();
      await _seedEvents(calendarRepo, database);
      await _pumpPlanner(
        tester: tester,
        database: database,
        plannerRepository: plannerRepo,
      );
      double scrollPixels() {
        final scrollable = find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        );
        return tester.state<ScrollableState>(scrollable).position.pixels;
      }

      // Two-pointer pinch owns the gesture: the selected date must not
      // change mid-pinch, and no horizontal day commit may occur.
      final selectedBefore = _selectedDateIso(tester);
      final center = _visibleZoomCenter(tester);
      final gestures = await _pinchOut(tester, center: center, totalGap: 120);
      expect(_selectedDateIso(tester), selectedBefore);
      await gestures.first.up();
      await gestures.second.up();
      await tester.pumpAndSettle();
      expect(_selectedDateIso(tester), selectedBefore);

      // The pinch may have moved the scroll offset through focal
      // compensation, but one-finger vertical scroll must still be able to
      // move the timeline afterward (physics restored post-pinch).
      final before = scrollPixels();
      final oneFingerAfter = await tester.startGesture(
        Offset(center.dx, center.dy - 40),
      );
      for (var i = 0; i < 6; i++) {
        await oneFingerAfter.moveBy(Offset(0, -30));
        await tester.pump();
      }
      await oneFingerAfter.up();
      await tester.pumpAndSettle();
      expect(
        scrollPixels(),
        isNot(closeTo(before, 1.0)),
        reason:
            'one-finger vertical scroll must move the timeline after a pinch',
      );
    });
  });
}
