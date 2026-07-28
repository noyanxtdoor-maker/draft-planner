import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'VS-03 Android smoke: offline Task create, status, and relaunch',
    (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      final profile = await startupRepository.completeOnboarding();
      final plannerRepository = DriftPlannerRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startupRepository,
          plannerRepository: plannerRepository,
          plannerDateSource: const FixedPlannerDateSource(
            PlannerDate(year: 2026, month: 7, day: 27),
          ),
          plannerIdentifierSource: SequenceIdentifierSource(<String>[
            'android-task',
            'android-complete-operation',
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planner-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-task-action')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('task-title-field')),
        'Android offline Task',
      );
      await tester.tap(find.byKey(const Key('save-task-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Android offline Task'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('complete-task-button')));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(
        (await plannerRepository.readTask(
          profileId: profile.id,
          taskId: 'android-task',
        ))!.status,
        PlannerTaskStatus.completed,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      final relaunchedPrivacy = TestPrivacyDependencies(database: database);
      final relaunchedStartup = buildTestRepository(
        database: database,
        privacyGate: relaunchedPrivacy.gate,
      );
      await tester.pumpWidget(
        relaunchedPrivacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: relaunchedStartup,
          plannerRepository: plannerRepository,
          plannerDateSource: const FixedPlannerDateSource(
            PlannerDate(year: 2026, month: 7, day: 27),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Android offline Task'),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('planner-day-scroll')),
          matching: find.byType(Scrollable),
        ),
      );

      expect(find.text('Android offline Task'), findsOneWidget);
    },
  );
}
