import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'VS-08 Android smoke: stable local week and explicit Task commitment',
    (tester) async {
      const monday = PlannerDate(year: 2026, month: 7, day: 27);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final now = DateTime.utc(2026, 7, 27, 12);
      await database
          .into(database.plannerTasks)
          .insert(
            PlannerTasksCompanion.insert(
              id: '83000000-0000-4000-8000-000000000001',
              profileId: profile.id,
              title: 'Weekly smoke Task',
              requiresReport: const Value<bool>(false),
              createdAtUtc: now,
              updatedAtUtc: now,
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
          plannerDateSource: const FixedPlannerDateSource(monday),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-targets-button')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('home-indicator-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('weekly-targets-button')));
      await tester.pumpAndSettle();
      expect(find.text('2026-07-27 — 2026-08-02'), findsOneWidget);
      expect(find.textContaining('Asia/Manila'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-plan-add-commitment')),
        250,
        scrollable: find.descendant(
          of: find.byKey(const Key('weekly-plan-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('weekly-plan-add-commitment')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select existing Task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekly smoke Task'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly smoke Task'), findsOneWidget);
      expect(find.text('Incomplete Task'), findsOneWidget);

      await tester.tap(find.byKey(const Key('weekly-plan-history-button')));
      await tester.pumpAndSettle();
      expect(find.text('Prior Weeks'), findsOneWidget);
    },
  );
}
