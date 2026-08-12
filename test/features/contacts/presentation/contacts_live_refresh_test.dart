import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets('Contacts tab refreshes live for EVERY write while listening '
      '(two consecutive emissions: create then archive)', (tester) async {
    const monday = PlannerDate(year: 2026, month: 7, day: 27);
    tester.view.physicalSize = const Size(941, 1672);
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
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      ]),
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

    final contactsTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Contacts'),
    );
    await tester.tap(contactsTab);
    await tester.pumpAndSettle();
    // Nothing created yet: the change stream is already being listened to.
    expect(find.text('Marilyn Gomez'), findsNothing);

    // Emission 1: create while listening — the row must appear.
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: '11111111-1111-4111-8111-111111111111',
        firstName: 'Marilyn',
        lastName: 'Gomez',
        displayName: 'Marilyn Gomez',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Marilyn Gomez'), findsOneWidget);

    // Emission 2: archive while listening — the row must disappear.
    await contacts.archiveContact(
      profileId: profile.id,
      contactId: '11111111-1111-4111-8111-111111111111',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Marilyn Gomez'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpAndSettle();
  });
}
