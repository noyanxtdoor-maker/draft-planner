import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

/// Light UI Final Polish (D) — Contact detail flicker regression.
///
/// POLISH-07 root cause: readTimeline() writes historical participant freeze
/// rows inside a provider watched by the very table stream those writes emit
/// on, so every mid-read write re-ran the read (a ~5Hz loading<->data flash).
/// Fix: freeze writes run in ONE transaction (one coalesced table update) and
/// the detail screen retains the last valid Contact while refreshing, so a
/// refresh never blanks the populated page.
void main() {
  testWidgets('D1: detail retains populated content through a refresh '
      'emission — no blank loading flash', (tester) async {
    const monday = PlannerDate(year: 2026, month: 7, day: 27);
    // flutter_tester's Ahem font wraps the factual sticky Status title at the
    // former 376dp harness width before this test reaches Contact Detail.
    // Use the same normal 400dp mobile harness as the accepted sticky tests.
    tester.view.physicalSize = const Size(1000, 1672);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    final profile = await startup.completeOnboarding();
    final privacy = TestPrivacyDependencies(database: database);
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      identifiers: SequenceIdentifierSource(<String>[
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ]),
    );

    const contactId = '11111111-1111-4111-8111-111111111111';
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: contactId,
        firstName: 'Test',
        lastName: 'Contact',
        displayName: 'Test Contact',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
      ),
    );
    // A PAST linked event: readTimeline() freezes it, which is the write
    // that used to re-trigger the watched read loop.
    await database
        .into(database.calendarEvents)
        .insert(
          CalendarEventsCompanion.insert(
            id: 'evt-past-1',
            profileId: profile.id,
            title: 'Past Visit',
            timing: 'morning',
            startDate: '2026-07-01',
            createdAtUtc: DateTime.utc(2026, 7, 1, 12),
            updatedAtUtc: DateTime.utc(2026, 7, 1, 12),
          ),
        );
    await database
        .into(database.eventContactLinks)
        .insert(
          EventContactLinksCompanion.insert(
            id: 'link-past-1',
            profileId: profile.id,
            eventId: 'evt-past-1',
            occurrenceId: const Value('occ-custom-1'),
            originalDate: const Value('2026-07-01'),
            contactId: contactId,
            status: const Value('active'),
            createdAtUtc: DateTime.utc(2026, 7, 1, 12),
            updatedAtUtc: DateTime.utc(2026, 7, 1, 12),
          ),
        );

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        plannerDateSource: const FixedPlannerDateSource(monday),
        contactRepository: contacts,
      ),
    );
    await tester.pumpAndSettle();

    // Open the Contact detail (Profile tab by default).
    await tester.tap(find.byKey(const Key('nav-contacts')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Contact'));
    await tester.pumpAndSettle();

    // Populated, stable: the contact name is shown and NO loading spinner or
    // blank 'Contact' app-bar-only frame remains.
    expect(find.text('Test Contact'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.byKey(const Key('contact-detail-fab')),
      findsNothing,
      reason: 'the approved C5 Profile has no global create FAB',
    );
    expect(
      find.byKey(const Key('main-bottom-navigation')),
      findsOneWidget,
      reason: 'Contact Detail remains inside the existing MainShell',
    );

    // The freeze wrote exactly one immutable snapshot (idempotent at rest).
    final snapshotCount = await (database.select(
      database.eventOccurrenceParticipants,
    )..where((table) => table.contactId.equals(contactId))).get();
    expect(snapshotCount, hasLength(1));

    // A refresh emission (any contacts-table write) must NOT blank the page:
    // the previous valid content is retained while the provider re-reads.
    await contacts.setFavorite(
      profileId: profile.id,
      contactId: contactId,
      favorite: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'POLISH-07: a refresh must not flash the blank loading frame',
    );
    expect(
      find.text('Test Contact'),
      findsWidgets,
      reason:
          'POLISH-07: previous Contact content must stay visible during '
          'a refresh',
    );
    expect(tester.takeException(), isNull);

    // The freeze must still be exactly one row after the refresh cycle.
    final afterRefresh = await (database.select(
      database.eventOccurrenceParticipants,
    )..where((table) => table.contactId.equals(contactId))).get();
    expect(afterRefresh, hasLength(1));
  });
}
