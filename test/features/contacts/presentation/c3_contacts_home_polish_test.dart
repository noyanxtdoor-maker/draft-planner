import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';
import 'package:rmplanner/features/contacts/presentation/contact_filter_controls.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_top_bar_icons.dart';

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

  testWidgets('C3-R4: quick filters live-apply and funnel resets state', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    expect(
      find.byKey(const Key('contacts-quick-filter-strip')),
      findsOneWidget,
    );
    final rail = find.byKey(const Key('contacts-quick-filter-strip'));
    expect(rail, findsOneWidget);
    expect(find.byKey(const Key('contacts-quick-filter-reset')), findsOneWidget);
    expect(
      find.byKey(const Key('contacts-quick-filter-displayedFields')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quick-filter-chip-body-Displayed Fields')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('quick-filter-chip-body-Displayed Fields')),
      ).height,
      34,
    );
    expect(
      tester.getSize(
        find.byKey(const Key('contacts-quick-filter-displayedFields')),
      ).height,
      48,
      reason: 'The compact body remains inside a 48dp effective tap target.',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('contacts-quick-filter-reset')),
        matching: find.byType(PlannerFilterIcon),
      ),
      findsOneWidget,
      reason: 'Contacts reuses the Planner filter icon visual source of truth.',
    );
    final topBarForeground = Theme.of(
      tester.element(find.byKey(const Key('contacts-filter-button'))),
    ).colorScheme.onSurface;
    expect(
      tester.widget<PlannerFilterIcon>(
        find.descendant(
          of: find.byKey(const Key('contacts-quick-filter-reset')),
          matching: find.byType(PlannerFilterIcon),
        ),
      ).color,
      topBarForeground,
    );
    expect(
      tester.widget<SvgPicture>(
        find.byKey(const Key('filter-plus-glyph')),
      ).colorFilter,
      ColorFilter.mode(topBarForeground, BlendMode.srcIn),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.search)).color,
      topBarForeground,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.more_vert)).color,
      topBarForeground,
    );
    expect(find.text('Displayed Fields'), findsOneWidget);
    expect(find.text('Groups: All'), findsNothing);
    await tester.dragUntilVisible(
      find.byKey(const Key('contacts-quick-filter-groups')),
      rail,
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('contacts-quick-filter-groups')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-sheet-groups')), findsOneWidget);
    expect(find.byKey(const Key('filter-sheet-master-state')), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byKey(const Key('filter-sheet-apply')), findsNothing);
    expect(find.byKey(const Key('filter-sheet-clear')), findsNothing);

    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    expect(find.text('Filtered'), findsOneWidget);
    await tester.tapAt(const Offset(8, 100));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('contacts-quick-filter-reset')),
      rail,
      const Offset(180, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts-quick-filter-reset')), findsOneWidget);

    await tester.tap(find.byKey(const Key('contacts-quick-filter-reset')));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets('C3-R4: Displayed Fields is transient and does not relabel the base view', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    await tester.tap(
      find.byKey(const Key('contacts-quick-filter-displayedFields')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('displayed-fields-sheet')), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.byKey(const Key('filter-sheet-apply')), findsNothing);
    await tester.tap(
      find.byKey(const Key('displayed-fields-option-contactMethod')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Some'), findsOneWidget);
    await tester.tapAt(const Offset(8, 100));
    await tester.pumpAndSettle();
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Filtered'), findsNothing);
  });

  testWidgets('C3-R4 R2: rail exposes the complete canonical order with trailing controls', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    final rail = find.byKey(const Key('contacts-quick-filter-strip'));
    final expected = <ContactFilterCategory>[
      ContactFilterCategory.groups,
      ContactFilterCategory.tags,
      ContactFilterCategory.favorites,
      ContactFilterCategory.availability,
      ContactFilterCategory.phone,
      ContactFilterCategory.email,
      ContactFilterCategory.address,
      ContactFilterCategory.socialProfile,
      ContactFilterCategory.eventHistory,
      ContactFilterCategory.withEventsToday,
      ContactFilterCategory.withFutureEvents,
      ContactFilterCategory.withoutFutureEvents,
      ContactFilterCategory.source,
      ContactFilterCategory.archived,
    ];
    expect(quickFilterCategories, expected);
    for (final category in expected) {
      final chip = find.byKey(Key('contacts-quick-filter-${category.name}'));
      await tester.dragUntilVisible(chip, rail, const Offset(-180, 0));
      expect(chip, findsOneWidget);
    }

    final groups = find.byKey(const Key('contacts-quick-filter-groups'));
    await tester.dragUntilVisible(groups, rail, const Offset(180, 0));
    await tester.tap(groups);
    await tester.pumpAndSettle();
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Family'),
    );
    expect(tile.controlAffinity, ListTileControlAffinity.trailing);
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    expect(find.text('Filtered'), findsOneWidget);
  });

  testWidgets('C3-R4 R2: zero Displayed Fields is valid structural Contacts content', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    await tester.tap(
      find.byKey(const Key('contacts-quick-filter-displayedFields')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('displayed-fields-sheet')),
        matching: find.byType(TriStateMasterCheckbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Select at least one displayed field.'), findsNothing);
    await tester.tapAt(const Offset(8, 100));
    await tester.pumpAndSettle();
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    expect(find.byType(ContactGroupIdentityDot), findsWidgets);
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
    expect(
      find.text('Status'),
      findsNWidgets(2),
      reason:
          'R4 defaults Contacts to Status while retaining Status as a direct '
          'Standard Filter action.',
    );
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

  testWidgets('C3-R4: default Status rows suppress ordinary favorite chrome', (
    tester,
  ) async {
    await pumpApp(tester, seedContacts: true);
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    expect(find.text('Family'), findsNothing);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('Terra R2: the first visible Status category omits its major '
      'divider but keeps its thin title rule', (tester) async {
    await pumpApp(tester, seedContacts: true);
    final firstStatus = find.byKey(
      const Key('contacts-status-section-notInteractedYet'),
    );
    expect(firstStatus, findsOneWidget);
    expect(
      find.descendant(
        of: firstStatus,
        matching: find.byType(FullWidthSectionDivider),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: firstStatus, matching: find.byType(Divider)),
      findsOneWidget,
      reason: 'The thin rule remains directly below the first category title.',
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
    expect(find.text('Find the people you’re looking for'), findsOneWidget);
    expect(find.text('Matches'), findsNothing);
    expect(find.textContaining('recent history'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('contact-search-field')),
      'Marilyn',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Marilyn Gomez'), findsOneWidget);
    expect(find.text('Ashley Cruz'), findsNothing);
  });
}
