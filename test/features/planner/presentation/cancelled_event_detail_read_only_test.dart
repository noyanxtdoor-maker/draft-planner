import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'Slice A: canonical cancelled Event Detail is read-only while factual '
    'details and tappable Contact remain visible',
    (tester) async {
      const date = PlannerDate(year: 2026, month: 7, day: 27);
      const eventId = 'ad000000-0000-4000-8000-000000000001';
      const contactId = 'ad-contact';
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startup = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      final profile = await startup.completeOnboarding();
      final contacts = DriftContactRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        identifiers: const UuidIdentifierSource(),
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
        timeZones: IanaCalendarEventTimeZones(
          displayTimeZoneId: 'Asia/Manila',
        ),
      );
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: contactId,
          firstName: 'Read-only',
          lastName: 'Contact',
          displayName: 'Read-only Contact',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      await calendar.saveEvent(
        profileId: profile.id,
        draft: const CalendarEventDraft(
          id: eventId,
          title: 'Cancelled detail fixture',
          notes: 'Factual notes remain visible',
          timing: CalendarEventTiming.timed,
          startDate: date,
          startMinute: 9 * 60,
          endMinute: 10 * 60,
          timeZoneId: 'Asia/Manila',
          locationText: 'Factual address',
          requiresReport: true,
          status: CalendarEventStatus.cancelled,
        ),
      );
      await contacts.setEventPeople(
        profileId: profile.id,
        eventId: eventId,
        occurrenceId: 'series',
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
          calendarEventRepository: calendar,
          contactRepository: contacts,
          plannerDateSource: const FixedPlannerDateSource(date),
        ),
      );
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(MaterialApp));
      unawaited(
        ProviderScope.containerOf(element).read(appRouterProvider).push(
          RoutePaths.calendarEventDetail(eventId, date),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cancelled-event-read-only-banner')),
        findsOneWidget,
      );
      expect(find.text('Cancelled detail fixture'), findsWidgets);
      expect(find.text('Factual notes remain visible'), findsOneWidget);
      expect(find.text('Factual address'), findsOneWidget);
      expect(
        find.byKey(const Key('event-preview-contact-$contactId')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('event-detail-edit-icon')), findsNothing);
      expect(find.byKey(const Key('event-detail-overflow-icon')), findsNothing);
      expect(find.byKey(const Key('event-status-control')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
