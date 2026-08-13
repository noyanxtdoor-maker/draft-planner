import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS-07 Android smoke: six local factual indicators and targets', (
    tester,
  ) async {
    const monday = PlannerDate(year: 2026, month: 7, day: 27);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    final profile = await startup.completeOnboarding();
    await establishWeeklyPlan(
      database: database,
      profileId: profile.id,
      date: monday,
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

    expect(find.text('Life Goals'), findsOneWidget);
    expect(find.byKey(const Key('home-active-period')), findsOneWidget);
    // Home-only unset targets render 0/0 (never 0/Not set).
    expect(find.text('Not set'), findsNothing);
    expect(find.text('0/0'), findsNWidgets(6));
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-targets-button')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-indicator-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('weekly-targets-button')));
    await tester.pumpAndSettle();
    expect(find.text('Goal Planning'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-plan-targets-button')),
      250,
      scrollable: find.descendant(
        of: find.byKey(const Key('weekly-plan-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('weekly-plan-targets-button')));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Targets'), findsOneWidget);
    expect(find.textContaining('Actual is read-only'), findsOneWidget);
  });
}
