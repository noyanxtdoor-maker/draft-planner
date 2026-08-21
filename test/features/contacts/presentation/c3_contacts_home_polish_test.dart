import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

/// C3 Contacts Home + truthful standard views + Search presentation tests
/// (implementation pack 2026-08-19).
void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  Future<
    ({
      WidgetTester tester,
      AppDatabase database,
      String profileId,
      DriftContactRepository contacts,
    })
  >
  pumpApp(WidgetTester tester, {bool seedContacts = false}) async {
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
        'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      ]),
    );
    if (seedContacts) {
      await contacts.ensureBuiltInGroups(profile.id);
      final rows = await contacts.readGroups(profile.id);
      final family = rows.singleWhere((row) => row.name == 'Family');
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
      await contacts.setContactGroups(
        profileId: profile.id,
        contactId: '11111111-1111-4111-8111-111111111111',
        groupIds: <String>[family.id],
        primaryGroupId: family.id,
      );
      // A second contact with NO group and an archived contact.
      await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: '22222222-2222-4222-8222-222222222222',
          firstName: 'Ashley',
          lastName: 'Cruz',
          displayName: 'Ashley Cruz',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      final archived = await contacts.createContact(
        profileId: profile.id,
        draft: const ContactDraft(
          id: '33333333-3333-4333-8333-333333333333',
          firstName: 'Archived',
          lastName: 'Person',
          displayName: 'Archived Person',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
      await contacts.archiveContact(
        profileId: profile.id,
        contactId: archived.id,
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

    return (
      tester: tester,
      database: database,
      profileId: profile.id,
      contacts: contacts,
    );
  }

  testWidgets('C3: Person+ FAB opens Add Contact', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('add-contact-fab')), findsOneWidget);
    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('add-contact-fab')),
    );
    expect(
      (fab.child as Icon).icon,
      Icons.person_add_alt,
      reason: 'FAB must read as Person+',
    );
    await tester.tap(find.byKey(const Key('add-contact-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-first-name')), findsOneWidget);
  });

  testWidgets('C3: filter action opens the canonical filter builder', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('contacts-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-builder-scroll')), findsOneWidget);
    expect(find.byKey(const Key('filter-sort-by')), findsOneWidget);
  });

  testWidgets('C3: quick filters use shared checkbox sheets and Clear All', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    expect(
      find.byKey(const Key('contacts-quick-filter-strip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('contacts-quick-filter-groups')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('contacts-quick-filter-groups')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-sheet-groups')), findsOneWidget);
    expect(find.byKey(const Key('filter-sheet-master-state')), findsOneWidget);
    expect(find.text('All'), findsOneWidget);

    await tester.tap(find.text('Family').last);
    await tester.tap(find.byKey(const Key('filter-sheet-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Filtered Contacts'), findsOneWidget);
    expect(find.byKey(const Key('active-filter-chip-groups')), findsOneWidget);
    expect(
      (tester.widget<InputChip>(
        find.byKey(const Key('active-filter-chip-groups')),
      )).label,
      isA<Text>(),
    );

    await tester.tap(find.byKey(const Key('active-filter-clear-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('active-filter-chip-groups')), findsNothing);
    expect(find.byKey(const Key('active-filter-clear-all')), findsNothing);
  });

  testWidgets('C3: full Filter category rows expand inline', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('contacts-filter-button')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('filter-category-main-eventHistory')),
      260,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.byKey(const Key('filter-category-main-eventHistory')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-sheet-eventHistory')), findsNothing);
    expect(
      find.byKey(const Key('filter-inline-option-event history-history')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('filter-builder-scroll')), findsOneWidget);
  });

  testWidgets('C3: standard catalog is truthful and PMG-shaped', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    await tester.tap(find.byKey(const Key('current-filter-row')));
    await tester.pumpAndSettle();
    expect(find.text('Area Filters'), findsOneWidget);
    expect(find.text('Standard Filters'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Recently Viewed'), findsOneWidget);
    expect(find.text('Recently Contacted'), findsOneWidget);
    expect(find.text('No Recent Contact'), findsOneWidget);
    expect(find.text('Recently Created'), findsOneWidget);
    expect(find.text('Needs Follow-Up'), findsNothing);
    expect(find.text('Has Future Events'), findsNothing);
    expect(find.text('Archived'), findsNothing);
    for (final icon in <String>[
      'status',
      'recentlyViewed',
      'recentlyContacted',
      'noRecentContact',
      'recentlyCreated',
    ]) {
      final iconFinder = find.byKey(Key('standard-filter-icon-$icon'));
      expect(iconFinder, findsOneWidget);
      expect(
        find.descendant(of: iconFinder, matching: find.byType(SvgPicture)),
        findsOneWidget,
        reason:
            '$icon must use the approved SVG asset, not the retired painter.',
      );
      final svg = tester.widget<SvgPicture>(
        find.byKey(Key('standard-filter-svg-$icon')),
      );
      expect(svg.width, 24);
      expect(svg.height, 24);
      expect(svg.colorFilter, isNotNull);
    }
  });

  testWidgets('C3: row subtitle shows one primary group only and favorite is '
      'separate', (tester) async {
    await pumpApp(tester, seedContacts: true);
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    // Subtitle shows the single current group.
    expect(find.text('Family'), findsOneWidget);
    // Favorite star stays separate from the group dot.
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('Terra R2: only the first visible category omits its major '
      'divider', (tester) async {
    await pumpApp(tester, seedContacts: true);
    final favorites = find.byKey(const Key('contacts-favorites-section'));
    final other = find.byKey(const Key('contacts-other-section'));
    expect(favorites, findsOneWidget);
    expect(other, findsOneWidget);
    expect(
      find.descendant(
        of: favorites,
        matching: find.byType(FullWidthSectionDivider),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: favorites, matching: find.byType(Divider)),
      findsOneWidget,
      reason: 'The thin rule remains directly below the first category title.',
    );
    expect(
      find.descendant(
        of: other,
        matching: find.byType(FullWidthSectionDivider),
      ),
      findsOneWidget,
      reason: 'The existing major divider remains before every later category.',
    );
  });

  testWidgets('Terra: Status applies directly and renders canonical categories '
      'in the main Contacts list', (tester) async {
    await pumpApp(tester, seedContacts: true);
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    expect(find.text('Archived Person'), findsNothing);

    await tester.tap(find.byKey(const Key('current-filter-row')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(
      find.byKey(const Key('standard-filter-status-notInteractedYet')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('standard-filter-status')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-view-selector-panel')), findsNothing);
    expect(find.text('Not Interacted Yet'), findsOneWidget);
    expect(find.text('Interacted Today'), findsNothing);
    expect(find.text('1+ Year Ago'), findsNothing);
    expect(
      find.byKey(const Key('contacts-status-section-notInteractedYet')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('contacts-status-section-notInteractedYet')),
        matching: find.byType(FullWidthSectionDivider),
      ),
      findsNothing,
      reason:
          'The first visible category keeps its thin title rule but no major divider.',
    );
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    expect(find.text('Archived Person'), findsNothing);
  });

  testWidgets('C3: Search route matches name and does not expose Notes', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    await tester.tap(find.byKey(const Key('contacts-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-search-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('contact-search-field')),
      'Marilyn',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    expect(find.text('Ashley Cruz'), findsNothing);
  });
}
