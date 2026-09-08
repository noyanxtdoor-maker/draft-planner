import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_detail_screen.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'E1 production router reuses one Contact shell for same/different Timeline '
    'Contacts while Planner-origin Event Detail preserves push navigation',
    (tester) async {
      const today = PlannerDate(year: 2026, month: 8, day: 31);
      const eventDate = PlannerDate(year: 2026, month: 9, day: 1);
      const eventId = 'e1000000-0000-4000-8000-000000000101';
      const contactA = 'e1000000-0000-4000-8000-000000000102';
      const contactB = 'e1000000-0000-4000-8000-000000000103';
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final privacy = TestPrivacyDependencies(database: database);
      final contacts = DriftContactRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 31, 2)),
        identifiers: UuidIdentifierSource(),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 8, 31, 2)),
        timeZones: IanaCalendarEventTimeZones(
          displayTimeZoneId: 'Asia/Manila',
        ),
      );
      for (final item in <({String id, String first})>[
        (id: contactA, first: 'Alpha'),
        (id: contactB, first: 'Beta'),
      ]) {
        await contacts.createContact(
          profileId: profile.id,
          draft: ContactDraft(
            id: item.id,
            firstName: item.first,
            lastName: 'Person',
            displayName: 'Duplicate Name',
            preferredContactMethod: ContactPreferredMethod.message,
            isFavorite: false,
          ),
        );
      }
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'E1 linked visit',
          timing: CalendarEventTiming.timed,
          startDate: eventDate,
          startMinute: 10 * 60,
          endMinute: 11 * 60,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: eventId,
        occurrenceId: DriftContactRepository.seriesOccurrenceId,
        contactIds: const <String>[contactA, contactB],
      );

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          calendarEventRepository: calendar,
          contactRepository: contacts,
          plannerDateSource: const FixedPlannerDateSource(today),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NextTransferApp)),
      );
      final router = container.read(appRouterProvider);
      final occurrenceId = CalendarEventOccurrenceIdentity.forDate(
        eventId: eventId,
        originalDate: eventDate,
      );

      Future<void> pumpUntil(Finder finder) async {
        for (var attempt = 0; attempt < 30; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (finder.evaluate().isNotEmpty) return;
        }
      }

      Future<void> openFromTimeline() async {
        router.go(RoutePaths.contactDetail(contactA));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byKey(const Key('timeline-tab')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.tap(find.byKey(Key('timeline-card-$occurrenceId')));
        await tester.pump();
        await pumpUntil(
          find.byKey(const Key('event-preview-contact-$contactA')),
        );
      }

      await openFromTimeline();
      await tester.tap(find.byKey(const Key('event-preview-contact-$contactA')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<ContactDetailScreen>(find.byType(ContactDetailScreen)).contactId,
        contactA,
      );
      expect(find.byType(Navigator), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      await openFromTimeline();
      await tester.tap(find.byKey(const Key('event-preview-contact-$contactB')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<ContactDetailScreen>(find.byType(ContactDetailScreen)).contactId,
        contactB,
      );
      expect(find.byType(Navigator), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      router.go(RoutePaths.calendarEventDetail(eventId, eventDate));
      await tester.pump();
      await pumpUntil(
        find.byKey(const Key('event-preview-contact-$contactB')),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('event-preview-contact-$contactB')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester.widget<ContactDetailScreen>(find.byType(ContactDetailScreen)).contactId,
        contactB,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
