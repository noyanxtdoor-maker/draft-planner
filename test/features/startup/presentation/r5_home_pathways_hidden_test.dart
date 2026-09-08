// R5 (owner 2026-08-16): Pathways is deferred. Home must NOT render the
// Active Pathways section (the fabricated Employment / N of M milestones /
// On Track card) or its View All entry point. Life Goals / Goal Planning
// content must remain untouched.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const today = PlannerDate(year: 2026, month: 8, day: 14);

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startup = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    await startup.completeOnboarding();
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        plannerDateSource: const FixedPlannerDateSource(today),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'R5: Home does not render the deferred/fabricated Active Pathways '
    'section', (tester) async {
      await pumpHome(tester);

      // No user-facing Pathways content of any kind.
      expect(find.text('Active Pathways'), findsNothing);
      expect(find.text('Employment'), findsNothing);
      expect(find.text('Education'), findsNothing);
      expect(find.text('Documents'), findsNothing);
      expect(find.text('On Track'), findsNothing);
      expect(find.textContaining('milestones'), findsNothing);
      expect(
        find.byKey(const Key('home-pathways-view-all')),
        findsNothing,
        reason: 'the Pathways View All entry point must be gone',
      );
      expect(
        find.byKey(const Key('home-pathway-employment')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'R5: hiding Pathways leaves Life Goals / Goal Planning Home content '
    'intact', (tester) async {
      await pumpHome(tester);
      expect(find.text('Life Goals'), findsOneWidget);
      expect(find.byKey(const Key('home-wli-view-all')), findsOneWidget);
      // Home still renders its core scaffold (bottom navigation with the
      // four primary destinations).
      expect(find.text('Home'), findsWidgets);
      expect(find.text('Planner'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Maps'), findsOneWidget);
    },
  );
}
