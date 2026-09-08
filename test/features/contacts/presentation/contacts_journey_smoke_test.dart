import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'VS-11 Contacts tab lists a created Contact and opens its Profile',
    (tester) async {
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
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: '11111111-1111-4111-8111-111111111111',
          firstName: 'Marilyn',
          lastName: 'Gomez',
          displayName: 'Marilyn Gomez',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: true,
          methods: <ContactMethodDraft>[
            ContactMethodDraft(
              type: ContactMethodType.phone,
              value: '+1 555 0100',
            ),
          ],
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

      // Open the Contacts tab (4th destination: Home, Planner, Pathways,
      // Contacts, More).
      final contactsTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Contacts'),
      );
      expect(contactsTab, findsOneWidget);
      await tester.tap(contactsTab);
      await tester.pumpAndSettle();

      expect(find.text('Marilyn Gomez'), findsOneWidget);
      expect(
        find.byKey(const Key('contacts-status-sticky-list')),
        findsOneWidget,
        reason:
            'The owner-approved factual Status default renders through the sticky list.',
      );
      final contactRow = find.byKey(
        const Key('contact-row-11111111-1111-4111-8111-111111111111'),
      );
      expect(
        find.descendant(
          of: contactRow,
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsOneWidget,
        reason: 'a favorite replaces its identity dot with one star marker',
      );
      expect(
        find.descendant(
          of: contactRow,
          matching: find.byType(ContactGroupIdentityDot),
        ),
        findsNothing,
        reason: 'a favorite must not render an additional group dot',
      );

      // The row opens the Contact Profile (two tabs, no Progress).
      await tester.tap(find.text('Marilyn Gomez'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-tab')), findsOneWidget);
      expect(find.byKey(const Key('timeline-tab')), findsOneWidget);
      expect(find.byKey(const Key('contact-profile-tab')), findsOneWidget);
      expect(find.text('CONTACT INFORMATION'), findsOneWidget);
      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
      expect(find.byKey(const Key('contact-detail-favorite')), findsOneWidget);
      expect(find.byKey(const Key('contact-detail-fab')), findsNothing);

      // Timeline tab shows the canonical Record Created entry.
      await tester.tap(find.byKey(const Key('timeline-tab')));
      await tester.pumpAndSettle();
      expect(find.text('Record Created'), findsOneWidget);

      // The shell-owned detail route pops back to the existing Contacts list
      // rather than leaving the shell or manufacturing a second nav stack.
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byKey(const Key('contacts-status-sticky-list')), findsOneWidget);
      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);

      // Dispose the tree and flush drift's zero-duration stream-cancel
      // timers so the binding has no pending timers at teardown.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpAndSettle();
    },
  );
}
