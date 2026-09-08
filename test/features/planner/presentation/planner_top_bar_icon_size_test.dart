import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_calendar_icon.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_top_bar_icons.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets('top-bar glyph sizes align without shrinking touch targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(PlannerFilterIcon)), const Size(24, 24));
    expect(
      tester.getSize(find.byType(PlannerSelectionIcon)),
      const Size(24, 24),
    );
    expect(tester.getSize(find.byIcon(Icons.more_vert)), const Size(24, 24));
    expect(
      tester.getSize(find.byIcon(Icons.today_outlined)),
      const Size(22, 22),
    );
    expect(
      tester.getSize(find.byKey(const Key('planner-calendar-button'))),
      const Size(44, 44),
    );
    for (final key in <String>[
      'planner-filter-button',
      'planner-selection-button',
      'planner-overflow-button',
    ]) {
      expect(
        tester.getSize(find.byKey(Key(key))).shortestSide,
        greaterThanOrEqualTo(44),
      );
    }

    final resolved = resolvePlannerCalendarIcon();
    expect(resolved.glyph, Icons.today_outlined);
    expect(resolved.size, 22);
  });
}
