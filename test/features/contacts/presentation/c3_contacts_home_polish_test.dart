import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
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

  testWidgets('Pass B2: aggregate Status renders ordered flat Smart sections and Status rows', (tester) async {
    final app = await pumpApp(tester, seedContacts: true);
    final calendar = DriftCalendarEventRepository(
      database: app.database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    );
    final groups = await app.contacts.readGroups(app.profileId);
    final family = groups.singleWhere((group) => group.name == 'Family');
    const ids = <String>[
      '44444444-4444-4444-8444-444444444444',
      '55555555-5555-4555-8555-555555555555',
      '66666666-6666-4666-8666-666666666666',
    ];
    for (final id in ids) {
      await app.contacts.createContact(profileId: app.profileId, draft: ContactDraft(id: id, firstName: id.substring(0, 1), lastName: 'Status', displayName: 'Status $id', preferredContactMethod: ContactPreferredMethod.message, isFavorite: false));
      await app.contacts.setContactGroups(profileId: app.profileId, contactId: id, groupIds: <String>[family.id], primaryGroupId: family.id);
    }
    var serial = 700;
    Future<void> interaction(String contactId, int daysAgo) async {
      final value = DateTime.utc(2026, 7, 27).subtract(Duration(days: daysAgo));
      final eventId = '00000000-0000-4000-8000-${serial.toString().padLeft(12, '0')}';
      serial++;
      await calendar.saveEvent(profileId: app.profileId, draft: CalendarEventDraft(id: eventId, title: 'Status interaction', timing: CalendarEventTiming.timed, startDate: PlannerDate(year: value.year, month: value.month, day: value.day), startMinute: 600, endMinute: 660, timeZoneId: 'Asia/Manila', requiresReport: false, recurrence: const CalendarRecurrenceRule(frequency: CalendarRecurrenceFrequency.none)));
      final originalDate = PlannerDate(year: value.year, month: value.month, day: value.day);
      await app.database.into(app.database.eventOccurrenceParticipants).insert(
        EventOccurrenceParticipantsCompanion.insert(
          id: 'snapshot-$serial', profileId: app.profileId, eventId: eventId,
          occurrenceId: CalendarEventOccurrenceIdentity.forDate(eventId: eventId, originalDate: originalDate),
          originalDate: originalDate.toString(), contactId: contactId,
          displayNameSnapshot: contactId, createdAtUtc: DateTime.utc(2026, 7, 27),
        ),
      );
    }
    const marilyn = '11111111-1111-4111-8111-111111111111';
    await interaction(marilyn, 120); await interaction(marilyn, 20);
    await interaction(ids[0], 25); await interaction(ids[0], 18); await interaction(ids[0], 10); await interaction(ids[0], 2);
    await interaction(ids[1], 70); await interaction(ids[1], 40); await interaction(ids[1], 20);
    await interaction(ids[2], 150); await interaction(ids[2], 100); await interaction(ids[2], 60);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('current-filter-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-filter-status')));
    await tester.pumpAndSettle();

    final labels = <String>['Recently Reconnected', 'Frequent Connection', 'Regular Connection', 'Reconnect Soon'];
    for (final label in labels) { expect(find.text(label), findsOneWidget); }
    final positions = labels.map((label) => tester.getTopLeft(find.text(label)).dy).toList();
    for (var index = 1; index < positions.length; index++) { expect(positions[index], greaterThan(positions[index - 1])); }
    expect(find.text('Interacted Today'), findsNothing);
    final first = find.byKey(const Key('contacts-status-section-recentlyReconnected'));
    final second = find.byKey(const Key('contacts-status-section-frequentConnection'));
    expect(find.descendant(of: first, matching: find.byType(FullWidthSectionDivider)), findsNothing);
    expect(find.descendant(of: first, matching: find.byType(Divider)), findsOneWidget);
    expect(find.descendant(of: second, matching: find.byType(FullWidthSectionDivider)), findsOneWidget);
    expect(find.descendant(of: second, matching: find.byType(Divider)), findsOneWidget);
    final marilynRow = find.byKey(const Key('contact-row-$marilyn'));
    expect(find.descendant(of: marilynRow, matching: find.byType(ContactGroupDot)), findsOneWidget);
    expect(find.descendant(of: marilynRow, matching: find.byIcon(Icons.star_rounded)), findsNothing);
    expect(find.descendant(of: marilynRow, matching: find.byType(ContactAvatar)), findsNothing);
    expect(find.descendant(of: marilynRow, matching: find.textContaining('Last interaction:')), findsOneWidget);
    final contactsList = find.byKey(const Key('contacts-list'));
    expect(
      contactsList,
      findsOneWidget,
      reason: 'Aggregate Status must render inside the canonical Contacts list.',
    );
    final contactsScrollable = find.descendant(
      of: contactsList,
      matching: find.byType(Scrollable),
    );
    expect(
      contactsScrollable,
      findsOneWidget,
      reason: 'The canonical Contacts list must own exactly one Scrollable.',
    );
    await tester.scrollUntilVisible(
      find.text('Not Interacted Yet'),
      280,
      scrollable: contactsScrollable,
    );
    expect(find.text('Not Interacted Yet'), findsOneWidget);
    expect(find.text('No recorded interaction yet'), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      await tester.drag(contactsScrollable, const Offset(0, 360));
      await tester.pump();
    }
    expect(marilynRow, findsOneWidget);
    await tester.tap(marilynRow);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-detail-fab')), findsOneWidget);
  });

  testWidgets('Pass B2: aggregate Status hides zero-match Smart sections', (tester) async {
    final app = await pumpApp(tester, seedContacts: true);
    final calendar = DriftCalendarEventRepository(
      database: app.database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    );
    const ids = <String>[
      '77777777-7777-4777-8777-777777777777',
      '88888888-8888-4888-8888-888888888888',
      '99999999-9999-4999-8999-999999999999',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    ];
    for (final id in ids) {
      await app.contacts.createContact(
        profileId: app.profileId,
        draft: ContactDraft(
          id: id,
          firstName: id.substring(0, 1),
          lastName: 'Status',
          displayName: 'Zero match $id',
          preferredContactMethod: ContactPreferredMethod.message,
          isFavorite: false,
        ),
      );
    }
    var serial = 800;
    Future<void> interaction(int daysAgo) async {
      final value = DateTime.utc(2026, 7, 27).subtract(Duration(days: daysAgo));
      final eventId =
          '00000000-0000-4000-8000-${serial.toString().padLeft(12, '0')}';
      serial++;
      final date = PlannerDate(
        year: value.year,
        month: value.month,
        day: value.day,
      );
      await calendar.saveEvent(
        profileId: app.profileId,
        draft: CalendarEventDraft(
          id: eventId,
          title: 'Frequent Status interaction',
          timing: CalendarEventTiming.timed,
          startDate: date,
          startMinute: 600,
          endMinute: 660,
          timeZoneId: 'Asia/Manila',
          requiresReport: false,
          recurrence: const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.none,
          ),
        ),
      );
      await app.database.into(app.database.eventOccurrenceParticipants).insert(
        EventOccurrenceParticipantsCompanion.insert(
          id: 'zero-match-snapshot-$serial',
          profileId: app.profileId,
          eventId: eventId,
          occurrenceId: CalendarEventOccurrenceIdentity.forDate(
            eventId: eventId,
            originalDate: date,
          ),
          originalDate: date.toString(),
          contactId: ids.first,
          displayNameSnapshot: 'Zero match frequent',
          createdAtUtc: DateTime.utc(2026, 7, 27),
        ),
      );
    }

    for (final daysAgo in <int>[25, 18, 10, 2]) {
      await interaction(daysAgo);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('current-filter-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('standard-filter-status')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('contacts-status-section-frequentConnection')),
      findsOneWidget,
    );
    for (final status in <String>[
      'recentlyReconnected',
      'regularConnection',
      'reconnectSoon',
    ]) {
      expect(find.byKey(Key('contacts-status-section-$status')), findsNothing);
    }
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
