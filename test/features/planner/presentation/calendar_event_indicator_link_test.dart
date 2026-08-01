import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'VS-08: optional Weekly Life Indicator link is reversible and persists only on Save',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      await startupRepository.completeOnboarding();

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startupRepository,
          plannerDateSource: const FixedPlannerDateSource(selected),
          plannerIdentifierSource: SequenceIdentifierSource(<String>[
            '33333333-3333-4333-8333-333333333333',
            '44444444-4444-4444-8444-444444444444',
            '55555555-5555-4555-8555-555555555555',
            '66666666-6666-4666-8666-666666666666',
            '77777777-7777-4777-8777-777777777777',
            '88888888-8888-4888-8888-888888888888',
          ]),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openGeneralForm() async {
        await tester.tap(find.text('Planner'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('planner-create-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('create-calendar-event-action')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('event-type-option-general')));
        await tester.pumpAndSettle();
      }

      Future<void> revealIndicatorLink() async {
        final formScroll = find.byElementPredicate((element) {
          if (element.widget is! Scrollable || element is! StatefulElement) {
            return false;
          }
          final state = element.state;
          return state is ScrollableState &&
              state.position.viewportDimension > 100 &&
              element.findAncestorWidgetOfExactType<ListView>()?.key ==
                  const Key('calendar-event-form-scroll');
        });
        final formState = tester.state<ScrollableState>(formScroll.at(0));
        formState.position.jumpTo(formState.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final offset = formState.position.maxScrollExtent - 350;
        formState.position.jumpTo(offset < 0 ? 0 : offset);
        await tester.pumpAndSettle();
      }

      await openGeneralForm();
      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Indicator Link Event',
      );
      await revealIndicatorLink();
      await tester.tap(
        find.byKey(const Key('weekly-life-indicator-link-section')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Link to Weekly Life Indicator'), findsWidgets);
      await tester.tap(
        find.byKey(const Key('weekly-indicator-option-exercise')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Exercise'), findsOneWidget);
      await tester.tap(find.byKey(const Key('weekly-life-indicator-remove')));
      await tester.pumpAndSettle();
      expect(find.text('Optional — no indicator linked'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-event-sheet-close')));
      await tester.pumpAndSettle();
      expect(await database.select(database.calendarEvents).get(), isEmpty);

      await openGeneralForm();
      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Indicator Link Event',
      );
      await revealIndicatorLink();
      await tester.tap(
        find.byKey(const Key('weekly-life-indicator-link-section')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('weekly-indicator-option-exercise')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pumpAndSettle();

      final saved = await database.select(database.calendarEvents).getSingle();
      expect(
        saved.contributionRuleKey,
        const ScheduledPotentialRule(
          indicatorKey: 'exercise',
          value: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
        ).encode(),
      );
      expect(
        await database.select(database.activityLedgerEntries).get(),
        isEmpty,
      );
      expect(await database.select(database.outcomeReports).get(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
