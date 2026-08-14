import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'B3.2 Task form: Life Goal section (unlinked default, picker, link, '
    'unlink), Event Type metadata without Goal helper, single + People',
    (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
          plannerIdentifierSource: SequenceIdentifierSource(
            <String>['task-form-b3-2'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planner-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-task-action')));
      await tester.pumpAndSettle();

      // Life Goal section present and unlinked by default.
      expect(find.byKey(const Key('task-life-goal-section')), findsOneWidget);
      expect(find.text('Choose a Life Goal (optional)'), findsOneWidget);
      // The old Event-Type Goal-inference helper is gone.
      expect(
        find.textContaining('add progress to the Goal assigned to'),
        findsNothing,
      );

      // Event Type remains as independent classification metadata only.
      expect(find.byKey(const Key('task-event-type-field')), findsOneWidget);
      expect(find.byKey(const Key('task-goal-event-type-field')), findsNothing);

      // Exactly ONE + People affordance; legacy free-text dialog gone.
      await tester.scrollUntilVisible(
        find.byKey(const Key('task-add-people-button')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-add-people-button')), findsOneWidget);
      expect(find.byKey(const Key('task-add-contacts-button')), findsNothing);
      expect(find.byKey(const Key('task-person-name-field')), findsNothing);

      // Link to a Life Goal through the approved picker.
      await tester.scrollUntilVisible(
        find.byKey(const Key('task-life-goal-field')),
        -300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-life-goal-field')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-life-goal-picker')), findsOneWidget);
      final option = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>)
                .value
                .startsWith('task-life-goal-option-'),
      );
      expect(option, findsWidgets);
      await tester.tap(option.first);
      await tester.pumpAndSettle();

      // Linked card shows the Goal title + Unlink affordance.
      expect(find.byKey(const Key('task-life-goal-unlink')), findsOneWidget);
      expect(find.text('Choose a Life Goal (optional)'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const Key('task-life-goal-unlink')),
        -300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-life-goal-unlink')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a Life Goal (optional)'), findsOneWidget);
    },
  );
}
