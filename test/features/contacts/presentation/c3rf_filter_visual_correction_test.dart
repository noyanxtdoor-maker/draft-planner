import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_filter_controls.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  Future<void> pumpFilter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(941, 1672);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    await startup.completeOnboarding();
    final privacy = TestPrivacyDependencies(database: database);
    final contacts = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      identifiers: SequenceIdentifierSource(const <String>[]),
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
    await tester.tap(find.byKey(const Key('nav-contacts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('contacts-filter-button')));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) {
    return tester.scrollUntilVisible(
      finder,
      260,
      scrollable: find.byType(Scrollable),
    );
  }

  testWidgets('C3-RF shell uses the locked Filter presentation', (
    tester,
  ) async {
    await pumpFilter(tester);

    expect(find.text('Build a view'), findsNothing);
    expect(find.text('Filter Contacts'), findsNothing);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.byKey(const Key('filter-builder-close')), findsOneWidget);
    expect(find.byKey(const Key('filter-builder-check')), findsOneWidget);
    expect(find.byKey(const Key('filter-builder-apply')), findsNothing);
    expect(find.text('Save as Area Filter'), findsOneWidget);
    expect(find.byKey(const Key('filter-name-field')), findsNothing);
    expect(find.byKey(const Key('filter-description-field')), findsNothing);
    expect(find.text('Contact List Sort'), findsOneWidget);
    expect(find.text('Sort By'), findsNothing);

    await tester.tap(find.byKey(const Key('save-as-filter-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-name-field')), findsOneWidget);
    expect(find.byKey(const Key('filter-description-field')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('filter-name-field'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('filter-description-field'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('filter-description-field'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('filter-sort-by'))).dy),
    );
  });

  testWidgets('C3-RF displayed fields expand inline and use right checkboxes', (
    tester,
  ) async {
    await pumpFilter(tester);

    await tester.tap(find.byKey(const Key('displayed-fields-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-sheet-displayedFields')), findsNothing);
    expect(
      find.byKey(
        const Key('filter-inline-option-displayed fields-currentGroup'),
      ),
      findsOneWidget,
    );
    expect(find.text('Current Group'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
  });

  testWidgets(
    'C4 Favorites None remains valid and completion stays available',
    (tester) async {
      await pumpFilter(tester);

      await reveal(
        tester,
        find.byKey(const Key('filter-category-main-favorites')),
      );
      await tester.tap(find.byKey(const Key('filter-category-main-favorites')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-master-favorites')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('filter-validation-favorites')),
        findsNothing,
      );
      expect(find.byKey(const Key('filter-state-favorites')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('filter-state-favorites')))
            .data,
        'None',
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('filter-builder-check')))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byKey(const Key('filter-master-favorites')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('filter-validation-favorites')),
        findsNothing,
      );

      await reveal(tester, find.byKey(const Key('filter-category-main-phone')));
      await tester.tap(find.byKey(const Key('filter-category-main-phone')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('filter-inline-option-phone-mobile')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-state-phone')), findsOneWidget);
      expect(find.text('Some'), findsOneWidget);
    },
  );

  testWidgets(
    'C4 Phone preserves All to None to Some to All and final None on reopen',
    (tester) async {
      await pumpFilter(tester);

      await reveal(tester, find.byKey(const Key('filter-category-main-phone')));
      await tester.tap(find.byKey(const Key('filter-category-main-phone')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('filter-state-phone'))).data,
        'All',
      );

      await tester.tap(find.byKey(const Key('filter-master-phone')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('filter-state-phone'))).data,
        'None',
      );

      await tester.tap(
        find.byKey(const Key('filter-inline-option-phone-mobile')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('filter-state-phone'))).data,
        'Some',
      );

      await tester.tap(find.byKey(const Key('filter-master-phone')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('filter-state-phone'))).data,
        'All',
      );

      await tester.tap(find.byKey(const Key('filter-master-phone')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('filter-inline-option-phone-mobile')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('filter-inline-option-phone-mobile')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('filter-state-phone'))).data,
        'None',
      );

      await tester.tap(find.byKey(const Key('filter-builder-check')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('contacts-filter-button')));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const Key('filter-category-main-phone')));
      expect(
        tester.widget<Text>(find.byKey(const Key('filter-state-phone'))).data,
        'None',
      );
    },
  );

  testWidgets('C4 zero-option Tags master is visibly disabled and unchecked', (
    tester,
  ) async {
    await pumpFilter(tester);

    await reveal(tester, find.byKey(const Key('filter-category-main-tags')));
    await tester.tap(find.byKey(const Key('filter-category-main-tags')));
    await tester.pumpAndSettle();

    final master = find.byKey(const Key('filter-master-tags'));
    expect(master, findsOneWidget);
    expect(
      tester
          .widgetList<IgnorePointer>(
            find.ancestor(of: master, matching: find.byType(IgnorePointer)),
          )
          .any((pointer) => pointer.ignoring),
      isTrue,
    );
    final checkbox = tester.widget<Checkbox>(
      find.descendant(of: master, matching: find.byType(Checkbox)),
    );
    expect(checkbox.value, isFalse);
    expect(find.text('No tags available.'), findsOneWidget);
  });

  testWidgets('C3-RF Restore Defaults is draft-only and resets filter state', (
    tester,
  ) async {
    await pumpFilter(tester);

    await tester.tap(find.byKey(const Key('filter-sort-by')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recently added'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('filter-restore-defaults')));
    expect(find.byKey(const Key('filter-restore-defaults')), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-restore-defaults')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filter-restore-defaults')), findsNothing);
    expect(find.text('Name (A–Z)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('save-as-filter-switch')),
      -400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('save-as-filter-switch')), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('save-as-filter-switch')),
          )
          .value,
      isFalse,
    );
  });

  test('C4 zero-option Groups/Tags display None without a fake selection', () {
    const criteria = ContactFilterCriteria();
    expect(
      contactFilterCategoryState(
        criteria,
        ContactFilterCategory.groups,
        groups: <ContactGroup>[],
      ),
      ContactFilterSelectionState.none,
    );
    expect(
      contactFilterCategoryState(
        criteria,
        ContactFilterCategory.tags,
        tags: <ContactTag>[],
      ),
      ContactFilterSelectionState.none,
    );
  });
}
