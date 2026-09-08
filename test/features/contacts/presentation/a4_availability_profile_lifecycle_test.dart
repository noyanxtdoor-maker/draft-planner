import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets('A4 Profile Availability save dismisses and refreshes safely', (
    tester,
  ) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    final profile = await startup.completeOnboarding();
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 24, 14)),
      identifiers: SequenceIdentifierSource(<String>[
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ]),
    );
    await contacts.createContact(
      profileId: profile.id,
      draft: const ContactDraft(
        id: '11111111-1111-4111-8111-111111111111',
        firstName: 'Maria',
        lastName: 'Santos',
        displayName: 'Maria Santos',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
      ),
    );
    final privacy = TestPrivacyDependencies(database: database);
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        plannerDateSource: const FixedPlannerDateSource(
          PlannerDate(year: 2026, month: 8, day: 24),
        ),
        contactRepository: contacts,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-contacts')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('contact-profile-tab')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-availability-edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('availability-add')), findsOneWidget);
    await tester.tap(find.byKey(const Key('availability-add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('availability-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('availability-add')), findsNothing);
    expect(find.textContaining('Monday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
