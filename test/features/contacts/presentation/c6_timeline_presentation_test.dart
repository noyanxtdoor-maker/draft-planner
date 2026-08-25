import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_timeline_view.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_resolver.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const contactId = 'c6000000-0000-4000-8000-000000000201';
  const today = PlannerDate(year: 2026, month: 8, day: 25);

  testWidgets(
    'C6 correction: visible Contact Profile refreshes when a timed Event ends',
    (tester) async {
      final clock = _MutableClock(DateTime.utc(2026, 8, 25, 8));
      final ticks = StreamController<DateTime>();
      addTearDown(ticks.close);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final privacy = TestPrivacyDependencies(database: database);
      final contacts = DriftContactRepository(
        database: database,
        clock: clock,
        identifiers: UuidIdentifierSource(),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: contactId,
          firstName: 'C6',
          lastName: 'Refresh',
          displayName: 'C6 Refresh',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      const eventId = 'c6000000-0000-4000-8000-000000000221';
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Boundary event',
          timing: CalendarEventTiming.timed,
          startDate: today,
          startMinute: 16 * 60,
          endMinute: 16 * 60 + 30,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactId],
      );
      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(today),
          contactRepository: contacts,
          extraOverrides: <Override>[
            contactTimelineClockProvider.overrideWith((ref) => ticks.stream),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-contacts')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C6 Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Boundary event'), findsOneWidget);

      clock.value = DateTime.utc(2026, 8, 25, 8, 31);
      ticks.add(clock.value);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Boundary event'), findsNothing);

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();
      expect(find.text('Boundary event'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'C6: Profile shows nearest three, centered See more, and Timeline reverses them',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final privacy = TestPrivacyDependencies(database: database);
      final contacts = DriftContactRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 25, 4)),
        identifiers: UuidIdentifierSource(),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 25, 4)),
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: contactId,
          firstName: 'C6',
          lastName: 'Visible',
          displayName: 'C6 Visible',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      final events = <(String, String, int)>[
        ('c6000000-0000-4000-8000-000000000211', 'Dinner', 18 * 60),
        ('c6000000-0000-4000-8000-000000000212', 'Shopping', 13 * 60 + 30),
        ('c6000000-0000-4000-8000-000000000213', 'Late call', 20 * 60),
        ('c6000000-0000-4000-8000-000000000214', 'Service', 15 * 60),
      ];
      for (final event in events) {
        await calendar.saveEvent(
          profileId: profile.id,
          draft: CalendarEventDraft(
            id: event.$1,
            title: event.$2,
            timing: CalendarEventTiming.timed,
            startDate: today,
            startMinute: event.$3,
            endMinute: event.$3 + 30,
            timeZoneId: 'Asia/Manila',
            requiresReport: false,
          ),
        );
        await contacts.setEventPeople(
          profileId: profile.id,
          eventId: event.$1,
          occurrenceId: DriftContactRepository.seriesOccurrenceId,
          contactIds: const <String>[contactId],
        );
      }

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(today),
          contactRepository: contacts,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-contacts')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('C6 Visible'));
      await tester.pumpAndSettle();

      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('Late call'), findsNothing);
      final more = find.byKey(const Key('profile-upcoming-see-more'));
      expect(more, findsOneWidget);
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(more).dx,
        closeTo(tester.view.physicalSize.width / 2, 1),
        reason: 'The affordance is physically centered, not left aligned.',
      );

      await tester.tap(find.byKey(const Key('profile-next-event')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-detail-title')), findsOneWidget);
      expect(find.text('Shopping'), findsWidgets);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('contact-timeline-list')), findsOneWidget);
      final order = <String>['Late call', 'Dinner', 'Service', 'Shopping'];
      final positions = order
          .map((title) => tester.getTopLeft(find.text(title).first).dy)
          .toList(growable: false);
      for (var index = 1; index < positions.length; index++) {
        expect(positions[index], greaterThan(positions[index - 1]));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('C6: Common Events does not render an empty shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommonEventsPanel(patterns: <CommonEventPattern>[]),
        ),
      ),
    );
    expect(find.byKey(const Key('common-events-panel')), findsNothing);
  });

  testWidgets('C6: Timeline Event color resolves from Planner preferences', (
    tester,
  ) async {
    Color? resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) {
            resolved = PlannerEventColorResolver.accentColorForIdentity(
              context,
              activityTypeId: 'event-type',
              activityTypeColorValue: 0xFF00FF00,
              preferencesByTypeId: const <String, EventColorPreference>{
                'event-type': EventColorPreference(
                  accentArgb: 0xFFAA00FF,
                  surfaceArgb: 0xFF330044,
                ),
              },
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved, const Color(0xFFAA00FF));
  });

  testWidgets(
    'C6 Pass C: Future shows Scheduled while History keeps canonical outcomes on one spine',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 8, day: 25);
      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 17),
            title: 'Future event',
            subtitle: '5:00 PM – 5:30 PM',
            status: CalendarEventStatus.scheduled,
            statusLabel: 'Scheduled',
            eventId: 'future',
            originalDate: date,
            occurrenceId: 'future:2026-08-25',
            isUpcoming: true,
          ),
        ],
        history: <ContactTimelineEntry>[
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 15),
            title: 'Normal passed event',
            status: CalendarEventStatus.scheduled,
            eventId: 'normal',
            originalDate: date,
            occurrenceId: 'normal:2026-08-25',
          ),
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 14),
            title: 'Reported event',
            status: CalendarEventStatus.completedHappened,
            statusLabel: 'Completed',
            eventId: 'completed',
            originalDate: date,
            occurrenceId: 'completed:2026-08-25',
          ),
          ContactTimelineEntry(
            kind: ContactTimelineKind.eventOccurrence,
            date: date,
            chronology: DateTime(2026, 8, 25, 13),
            title: 'Awaiting event',
            status: CalendarEventStatus.scheduled,
            statusLabel: 'Unreported',
            eventId: 'unreported',
            originalDate: date,
            occurrenceId: 'unreported:2026-08-25',
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: timeline,
              eventColorsByTypeId: <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      expect(find.text('Future event'), findsOneWidget);
      expect(find.text('5:00 PM – 5:30 PM'), findsOneWidget);
      expect(find.text('Normal passed event'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Unreported'), findsOneWidget);
      expect(
        find.text('Scheduled'),
        findsOneWidget,
        reason: 'Only the Future Event card retains the Scheduled label.',
      );
      expect(
        find.byKey(const Key('timeline-history-spine-connector')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'C6 Pass A: Future and History are year-aware on one continuous spine',
    (tester) async {
      ContactTimelineEntry entry({
        required int year,
        required int month,
        required int day,
        required String title,
        required bool upcoming,
      }) {
        final date = PlannerDate(year: year, month: month, day: day);
        return ContactTimelineEntry(
          kind: ContactTimelineKind.eventOccurrence,
          date: date,
          chronology: DateTime(year, month, day, upcoming ? 18 : 9),
          title: title,
          subtitle: upcoming ? '6:00 PM – 6:30 PM' : null,
          eventId: title,
          originalDate: date,
          occurrenceId: '$title:$year-$month-$day',
          isUpcoming: upcoming,
        );
      }

      final timeline = ContactTimeline(
        upcoming: <ContactTimelineEntry>[
          entry(
            year: 2026,
            month: 12,
            day: 28,
            title: 'Future 2026',
            upcoming: true,
          ),
          entry(
            year: 2027,
            month: 1,
            day: 12,
            title: 'Future 2027',
            upcoming: true,
          ),
        ],
        history: <ContactTimelineEntry>[
          entry(
            year: 2026,
            month: 8,
            day: 25,
            title: 'History 2026',
            upcoming: false,
          ),
          entry(
            year: 2025,
            month: 12,
            day: 18,
            title: 'History 2025',
            upcoming: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactTimelineView(
              timeline: timeline,
              eventColorsByTypeId: const <String, EventColorPreference>{},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('timeline-future-year-2027')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-future-year-2026')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-history-year-2026')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('timeline-history-year-2025')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('timeline-history-year-2025')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-history-spine-connector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-spine-gap-Future 2027:2027-1-12')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('timeline-spine-gap-Future 2026:2026-12-28')),
        findsOneWidget,
      );
      expect(find.text('Future 2027'), findsOneWidget);
      expect(find.text('Future 2026'), findsOneWidget);
      expect(find.text('History 2026'), findsOneWidget);
      expect(find.text('History 2025'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _MutableClock implements AppClock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime nowUtc() => value;
}
