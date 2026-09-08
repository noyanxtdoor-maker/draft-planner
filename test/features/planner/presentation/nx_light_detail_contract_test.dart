// NX-01/02/05/06 — Light detail/status contract tests.
//
// NX-01: Event/Contact detail captions must use a readable Light foreground
//        (Dark keeps the exact white60 pixels).
// NX-02: inactive (unselected) status controls must be visibly neutral in
//        Light (Dark keeps white38/white54 byte-identical).
// NX-05: the detail sheet heading is truthful from the FIRST frame when the
//        planner already knows the identity (no 'Calendar Event' morph).
// NX-06: the Edit form keeps a stable seeded shell (type label + title)
//        instead of a blank spinner while the correctness load runs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/data/drift_task_event_link_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_report_status_icons.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';

import '../../../support/test_dependencies.dart';

const _selected = PlannerDate(year: 2026, month: 7, day: 27);
const _eventId = '99999999-9999-4999-9999-999999999999';

CalendarEventDraft _contactDraft() {
  return const CalendarEventDraft(
    id: _eventId,
    title: 'Contact follow-up',
    timing: CalendarEventTiming.timed,
    startDate: _selected,
    startMinute: 9 * 60,
    endMinute: 10 * 60,
    timeZoneId: 'Asia/Manila',
    requiresReport: true,
    activityTypeId: 'contact-type-id',
    activityTypeStableKeySnapshot: 'contact',
    activityTypeLabelSnapshot: 'Contact',
  );
}

class _PendingCalendarRepository implements CalendarEventRepository {
  _PendingCalendarRepository(this.occurrenceCompleter);

  final Completer<CalendarEventOccurrence?> occurrenceCompleter;

  @override
  String get displayTimeZoneId => 'Asia/Manila';

  @override
  bool isValidTimeZone(String timeZoneId) => true;

  @override
  Future<CalendarEventOccurrence?> readOccurrence({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
  }) {
    return occurrenceCompleter.future;
  }

  @override
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  }) async {
    return const <PlannerCalendarItem>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused: ${invocation.memberName}');
}

/// NX-06: holds [readEventDraft] behind a gate while all other reads pass
/// through to the real repository.  The Edit form's two correctness loads
/// (`_loadExisting` + `_loadConfiguration`) both await a draft read, so the
/// loading shell stays visible deterministically until the test releases the
/// gate — exactly the blank-pause window the sheet previously showed.
class _HoldingRepository implements CalendarEventRepository {
  _HoldingRepository(this.delegate);

  final CalendarEventRepository delegate;
  final Completer<void> _draftGate = Completer<void>();
  bool _draftsHeld = true;

  @override
  String get displayTimeZoneId => delegate.displayTimeZoneId;

  @override
  bool isValidTimeZone(String timeZoneId) =>
      delegate.isValidTimeZone(timeZoneId);

  @override
  Future<CalendarEventOccurrence?> readOccurrence({
    required String profileId,
    required String eventId,
    required PlannerDate originalDate,
  }) {
    return delegate.readOccurrence(
      profileId: profileId,
      eventId: eventId,
      originalDate: originalDate,
    );
  }

  @override
  Future<CalendarEventDraft?> readEventDraft({
    required String profileId,
    required String eventId,
  }) async {
    if (_draftsHeld) {
      await _draftGate.future;
    }
    return delegate.readEventDraft(profileId: profileId, eventId: eventId);
  }

  @override
  Future<List<PlannerCalendarItem>> readDay({
    required String profileId,
    required PlannerDate date,
  }) {
    return delegate.readDay(profileId: profileId, date: date);
  }

  /// Releases every pending draft read (the form then renders normally).
  void releaseDrafts() {
    _draftsHeld = false;
    if (!_draftGate.isCompleted) {
      _draftGate.complete();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unused: ${invocation.memberName}');
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required TestPrivacyDependencies privacy,
  required AppDatabase database,
  required DriftPlannerRepository plannerRepository,
  required DriftCalendarEventRepository calendarRepository,
  List<Override> extraOverrides = const <Override>[],
  AppearanceMode appearance = AppearanceMode.light,
}) async {
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();
  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
      plannerRepository: plannerRepository,
      calendarEventRepository: calendarRepository,
      plannerDateSource: const FixedPlannerDateSource(_selected),
      initialAppearance: appearance,
      extraOverrides: extraOverrides,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
}

Future<
    (
      AppDatabase,
      DriftPlannerRepository,
      DriftCalendarEventRepository,
    )
  >
  _buildRepositories() async {
  final database = openMemoryDatabase();
  addTearDown(database.close);
  final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
  final timeZones = IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila');
  final linkRepository = DriftTaskEventLinkRepository(
    database: database,
    clock: clock,
  );
  final reportingRepository = DriftOutcomeReportingRepository(
    database: database,
    clock: clock,
  );
  final calendarRepository = DriftCalendarEventRepository(
    database: database,
    clock: clock,
    timeZones: timeZones,
    taskContextSource: linkRepository,
    linkContextTransfer: linkRepository,
    reportSource: reportingRepository,
  );
  final plannerRepository = DriftPlannerRepository(
    database: database,
    clock: clock,
    calendarSource: calendarRepository,
    taskContextSource: linkRepository,
    historicalEffectReader: reportingRepository,
  );
  return (database, plannerRepository, calendarRepository);
}

Future<void> _openContactDetail(WidgetTester tester) async {
  final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
    eventId: _eventId,
    originalDate: _selected,
  );
  await tester.tap(find.byKey(Key('planner-timed-event-$occurrenceId')));
  await tester.pumpAndSettle();
}

Color? _captionColor(WidgetTester tester, String caption) {
  final text = tester.widget<Text>(find.text(caption));
  return text.style?.color;
}

void main() {
  testWidgets(
    'NX-01: Light Event/Contact detail captions are readable semantic '
    'foreground (never white60) and the values stay readable',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (database, plannerRepo, calendarRepo) =
          await _buildRepositories();
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await calendarRepo.saveEvent(
        profileId: profile.id,
        draft: _contactDraft(),
      );
      final privacy = TestPrivacyDependencies(database: database);
      await _pumpApp(
        tester,
        privacy: privacy,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
      );
      await _openContactDetail(tester);

      final context = tester.element(
        find.byKey(const Key('calendar-event-existing-detail-sheet')),
      );
      final expected = Theme.of(
        context,
      ).colorScheme.onSurfaceVariant;
      expect(
        _captionColor(tester, 'Current Status'),
        expected,
        reason: 'NX-01: "Current Status" caption must use the Light '
            'onSurfaceVariant foreground, not white60',
      );
      expect(
        _captionColor(tester, 'Title'),
        expected,
        reason: 'NX-01: detail field captions must use the Light '
            'onSurfaceVariant foreground, not white60',
      );
      expect(
        _captionColor(tester, 'Current Status'),
        isNot(Colors.white60),
      );
      // The value text itself stays present and readable (its own color is
      // theme onSurface by default).  NX-05 seeds the sheet heading with the
      // activity label ('Contact'), and the Title detail field shows the
      // event title, so the title string can legitimately appear more than
      // once (e.g. heading/title region).
      expect(find.text('Contact follow-up'), findsWidgets);
    },
  );

  testWidgets(
    'NX-01: Dark detail captions keep the exact white60 pixels',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (database, plannerRepo, calendarRepo) =
          await _buildRepositories();
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await calendarRepo.saveEvent(
        profileId: profile.id,
        draft: _contactDraft(),
      );
      final privacy = TestPrivacyDependencies(database: database);
      await _pumpApp(
        tester,
        privacy: privacy,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        appearance: AppearanceMode.dark,
      );
      await _openContactDetail(tester);
      expect(_captionColor(tester, 'Current Status'), Colors.white60);
      expect(_captionColor(tester, 'Title'), Colors.white60);
    },
  );

  testWidgets(
    'NX-02: Light inactive (unselected) status controls use a visible '
    'neutral semantic treatment, never white38/white54',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (database, plannerRepo, calendarRepo) =
          await _buildRepositories();
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await calendarRepo.saveEvent(
        profileId: profile.id,
        draft: _contactDraft(),
      );
      final privacy = TestPrivacyDependencies(database: database);
      await _pumpApp(
        tester,
        privacy: privacy,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
      );
      await _openContactDetail(tester);

      final row = find.byKey(const Key('event-status-control'));
      final paints = find.descendant(
        of: row,
        matching: find.byType(CustomPaint),
      );
      expect(paints, findsWidgets);
      var unselectedFound = false;
      for (final element in paints.evaluate()) {
        final painter = tester
            .widget<CustomPaint>(find.byWidget(element.widget))
            // ignore: avoid_dynamic_calls
            .painter as dynamic;
        // ignore: avoid_dynamic_calls
        if (painter.style == PlannerReportStatusIconStyle.unselected) {
          unselectedFound = true;
          // ignore: avoid_dynamic_calls
          expect(painter.ringColor, isNot(Colors.white38),
              reason: 'NX-02: unselected ring must not be white38 in Light');
          // ignore: avoid_dynamic_calls
          expect(painter.glyphColor, isNot(Colors.white54),
              reason: 'NX-02: unselected glyph must not be white54 in Light');
        }
      }
      expect(unselectedFound, isTrue,
          reason: 'the status row must contain unselected controls');
    },
  );

  testWidgets(
    'NX-02: Dark unselected status controls keep white38/white54',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (database, plannerRepo, calendarRepo) =
          await _buildRepositories();
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await calendarRepo.saveEvent(
        profileId: profile.id,
        draft: _contactDraft(),
      );
      final privacy = TestPrivacyDependencies(database: database);
      await _pumpApp(
        tester,
        privacy: privacy,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        appearance: AppearanceMode.dark,
      );
      await _openContactDetail(tester);

      final row = find.byKey(const Key('event-status-control'));
      final paints = find.descendant(
        of: row,
        matching: find.byType(CustomPaint),
      );
      var unselectedFound = false;
      for (final element in paints.evaluate()) {
        final painter = tester
            .widget<CustomPaint>(find.byWidget(element.widget))
            // ignore: avoid_dynamic_calls
            .painter as dynamic;
        // ignore: avoid_dynamic_calls
        if (painter.style == PlannerReportStatusIconStyle.unselected) {
          unselectedFound = true;
          // ignore: avoid_dynamic_calls
          expect(painter.ringColor, Colors.white38);
          // ignore: avoid_dynamic_calls
          expect(painter.glyphColor, Colors.white54);
        }
      }
      expect(unselectedFound, isTrue);
    },
  );

  testWidgets(
    'NX-05: the Contact sheet heading is truthful from the first frame '
    '(planner seed) and never shows the generic "Calendar Event" morph',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (database, plannerRepo, calendarRepo) =
          await _buildRepositories();
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await calendarRepo.saveEvent(
        profileId: profile.id,
        draft: _contactDraft(),
      );
      // Resolve the real occurrence for later completion.
      final occurrence = await calendarRepo.readOccurrence(
        profileId: profile.id,
        eventId: _eventId,
        originalDate: _selected,
      );
      final completer = Completer<CalendarEventOccurrence?>();
      final privacy = TestPrivacyDependencies(database: database);
      await _pumpApp(
        tester,
        privacy: privacy,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        extraOverrides: <Override>[
          calendarEventRepositoryProvider.overrideWithValue(
            _PendingCalendarRepository(completer),
          ),
        ],
      );
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: _eventId,
        originalDate: _selected,
      );
      await tester.tap(find.byKey(Key('planner-timed-event-$occurrenceId')));
      // Only a few frames of the sheet-open animation; the occurrence read
      // is still PENDING.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.text('Contact'),
        findsOneWidget,
        reason: 'NX-05: the sheet heading must show the seeded identity on '
            'the first frame while detail content is still loading',
      );
      expect(
        find.text('Calendar Event'),
        findsNothing,
        reason: 'NX-05: no generic "Calendar Event" title morph may appear '
            'when the planner already knows the identity',
      );
      // Complete the pending read and settle: heading stays truthful and the
      // content appears.  After load the 'Contact' string appears twice — the
      // seeded sheet heading AND the Event Type detail-field value — so only
      // assert presence (the heading-specific check below uses the styled
      // app-bar title text).
      completer.complete(occurrence);
      await tester.pumpAndSettle();
      expect(find.text('Contact'), findsWidgets);
      expect(find.text('Calendar Event'), findsNothing);
      // The sheet heading (titleLarge, centered) still shows the seeded
      // identity exactly once.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'Contact' &&
              widget.textAlign == TextAlign.center,
        ),
        findsOneWidget,
      );
      expect(find.text('Contact follow-up'), findsWidgets);
    },
  );

  testWidgets(
    'NX-06: Edit opened from the Contact sheet keeps a stable seeded shell '
    '(heading "Edit Contact Event" + title) while the form loads',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (database, plannerRepo, calendarRepo) =
          await _buildRepositories();
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await calendarRepo.saveEvent(
        profileId: profile.id,
        draft: _contactDraft(),
      );
      final holding = _HoldingRepository(calendarRepo);
      final privacy = TestPrivacyDependencies(database: database);
      await _pumpApp(
        tester,
        privacy: privacy,
        database: database,
        plannerRepository: plannerRepo,
        calendarRepository: calendarRepo,
        extraOverrides: <Override>[
          calendarEventRepositoryProvider.overrideWithValue(holding),
        ],
      );
      // Open the detail sheet: occurrence reads pass straight through, so
      // the sheet content loads normally.
      await _openContactDetail(tester);
      // Tap Edit: the sheet re-reads the occurrence (passes through) and
      // pushes the form.  The form's draft reads are HELD, so its loading
      // shell stays visible deterministically.
      await tester.tap(
        find.byKey(const Key('event-detail-sheet-edit-icon')),
      );
      // The sheet re-reads the occurrence (a real drift future) before
      // pushing the Edit form, so give the route a few timed pumps.
      var formVisible = false;
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Edit Contact Event').evaluate().isNotEmpty) {
          formVisible = true;
          break;
        }
      }
      expect(formVisible, isTrue, reason: 'the Edit form route must open');
      // The form is now open with its correctness loads held PENDING.  The
      // shell must already show the seeded identity.
      expect(
        find.text('Edit Contact Event'),
        findsOneWidget,
        reason: 'NX-06: the Edit form heading must be the seeded type label '
            'from the first frame, not the generic "Edit Event"',
      );
      expect(
        find.byKey(const Key('edit-loading-seed-title')),
        findsOneWidget,
        reason: 'NX-06: the loading shell must show the seeded title line',
      );
      expect(find.text('Contact follow-up'), findsWidgets);
      // Release the draft reads: the real form renders.  The loaded heading
      // resolves through the test event-type registry (the seeded
      // 'contact-type-id' does not exist there, so it falls back to the
      // Other type label) — the contract is that the generic 'Edit Event'
      // never appears and the seeded title is retained in the form.
      holding.releaseDrafts();
      await tester.pumpAndSettle();
      expect(find.text('Edit Event'), findsNothing);
      expect(find.text('Contact follow-up'), findsWidgets);
    },
  );
}
