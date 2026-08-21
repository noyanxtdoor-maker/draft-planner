import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

/// C3 Filter exit regression coverage.
///
/// FilterBuilderScreen intentionally owns a PopScope(canPop: false). Once its
/// exit decision is complete, navigation must be completed imperatively rather
/// than by re-entering Navigator.maybePop().
void main() {
  const monday = PlannerDate(year: 2026, month: 7, day: 27);

  Future<void> settle(WidgetTester tester) {
    return tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  Future<void> pumpContactsApp(WidgetTester tester) async {
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
      identifiers: SequenceIdentifierSource(<String>[
        'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
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
    await settle(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Contacts'),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('contacts-filter-button')));
    await settle(tester);
    expect(find.byKey(const Key('filter-builder-scroll')), findsOneWidget);
  }

  Future<void> expectFilterClosed(WidgetTester tester) async {
    await settle(tester);
    expect(find.byKey(const Key('filter-builder-scroll')), findsNothing);
    expect(find.byKey(const Key('contacts-filter-button')), findsOneWidget);
  }

  Future<void> changeOneCriterion(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('filter-sort-by')));
    await settle(tester);
    await tester.tap(find.text('Recently added'));
    await settle(tester);
  }

  testWidgets('system Back exits Filter without a navigation hang', (
    tester,
  ) async {
    await pumpContactsApp(tester);

    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await expectFilterClosed(tester);
  });

  testWidgets('X close exits Filter without a navigation hang', (tester) async {
    await pumpContactsApp(tester);

    await tester.tap(find.byKey(const Key('filter-builder-close')));
    await expectFilterClosed(tester);
  });

  testWidgets('dirty Filter + Discard exits without a navigation hang', (
    tester,
  ) async {
    await pumpContactsApp(tester);

    await changeOneCriterion(tester);
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue);
    await settle(tester);
    expect(find.text('Discard filter changes?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-discard-filter')));
    await expectFilterClosed(tester);
  });

  testWidgets('Apply still returns normally from Filter', (tester) async {
    await pumpContactsApp(tester);

    await changeOneCriterion(tester);
    await tester.tap(find.byKey(const Key('filter-builder-check')));
    await expectFilterClosed(tester);
  });

  testWidgets('Save as Saved Filter returns normally when exposed', (
    tester,
  ) async {
    await pumpContactsApp(tester);

    await tester.tap(find.byKey(const Key('save-as-filter-switch')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('filter-name-field')),
      'C3 exit regression',
    );
    await tester.tap(find.byKey(const Key('filter-builder-check')));
    await expectFilterClosed(tester);
  });
}
