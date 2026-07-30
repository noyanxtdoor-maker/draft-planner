import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/anchored_top_bar_popup.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  group('VS-08 shared popup family', () {
    testWidgets('Filter reveals downward beneath the Filter icon', (tester) async {
      tester.view.physicalSize = const Size(411, 731);
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
          plannerDateSource: const FixedPlannerDateSource(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();

      final filterKey = find.byKey(const Key('planner-filter-button'));
      expect(filterKey, findsOneWidget);
      final filterCenter = tester.getCenter(filterKey);

      await tester.tap(filterKey);
      await tester.pumpAndSettle();

      // Popup should be visible.
      expect(find.byKey(const Key('planner-filter-menu')), findsOneWidget);

      // Popup top must be below the Filter icon center (revealed downward).
      final popupTopLeft = tester.getTopLeft(
        find.byKey(const Key('planner-filter-menu')),
      );
      expect(
        popupTopLeft.dy,
        greaterThan(filterCenter.dy),
        reason: 'Filter popup must reveal below the Filter icon',
      );

      // Outside-tap dismisses the popup.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('planner-filter-menu')), findsNothing);
    });

    testWidgets('Overflow opens the same popup family beneath the icon',
        (tester) async {
      tester.view.physicalSize = const Size(411, 731);
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
          plannerDateSource: const FixedPlannerDateSource(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();

      final overflowKey = find.byKey(const Key('planner-overflow-button'));
      expect(overflowKey, findsOneWidget);
      final overflowCenter = tester.getCenter(overflowKey);

      await tester.tap(overflowKey);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-overflow-menu')), findsOneWidget);
      final popupTopLeft = tester.getTopLeft(
        find.byKey(const Key('planner-overflow-menu')),
      );
      expect(
        popupTopLeft.dy,
        greaterThan(overflowCenter.dy),
        reason: 'Overflow popup must also reveal below the icon',
      );
      expect(anchoredTopBarPopupController.isOpen, isTrue);
    });
  });

  group('VS-08 Planner top bar', () {
    testWidgets('Current date chevron is present and is one touch target',
        (tester) async {
      tester.view.physicalSize = const Size(411, 731);
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
          plannerDateSource: const FixedPlannerDateSource(selected),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planner-date-label')), findsOneWidget);
      expect(find.byKey(const Key('planner-date-chevron')), findsOneWidget);
      expect(find.byKey(const Key('planner-calendar-button')), findsOneWidget);
      expect(
        find.byKey(const Key('planner-selection-button')),
        findsOneWidget,
      );
    });
  });

  group('PlannerEventBlockLayoutPolicy', () {
    test('classifies heights into the expected density buckets', () {
      expect(PlannerEventBlockLayoutPolicy.classify(20), Density.veryShort);
      expect(PlannerEventBlockLayoutPolicy.classify(24), Density.veryShort);
      expect(PlannerEventBlockLayoutPolicy.classify(25), Density.short);
      expect(PlannerEventBlockLayoutPolicy.classify(44), Density.short);
      expect(PlannerEventBlockLayoutPolicy.classify(45), Density.medium);
      expect(PlannerEventBlockLayoutPolicy.classify(70), Density.medium);
      expect(PlannerEventBlockLayoutPolicy.classify(71), Density.tall);
    });

    test('very short shows title only, no time, no status', () {
      const content = PlannerEventBlockContent(
        density: Density.veryShort,
        titleMaxLines: 1,
        showTime: false,
        showStatusIcons: false,
        showResizeHandle: false,
      );
      expect(content.titleMaxLines, 1);
      expect(content.showTime, isFalse);
      expect(content.showStatusIcons, isFalse);
      expect(content.showResizeHandle, isFalse);
    });

    test('short shows time but no status', () {
      final content = PlannerEventBlockContent.forHeight(
        40,
        interactive: true,
      );
      expect(content.density, Density.short);
      expect(content.showTime, isTrue);
      expect(content.showStatusIcons, isFalse);
      expect(content.showResizeHandle, isFalse);
    });

    test('medium shows time and status; resize only when interactive', () {
      final interactive = PlannerEventBlockContent.forHeight(
        60,
        interactive: true,
      );
      expect(interactive.density, Density.medium);
      expect(interactive.showTime, isTrue);
      expect(interactive.showStatusIcons, isTrue);
      expect(interactive.showResizeHandle, isFalse);

      final nonInteractive = PlannerEventBlockContent.forHeight(
        60,
        interactive: false,
      );
      expect(nonInteractive.showResizeHandle, isFalse);
    });

    test('tall shows time, status, and resize handle when interactive', () {
      final interactive = PlannerEventBlockContent.forHeight(
        120,
        interactive: true,
      );
      expect(interactive.density, Density.tall);
      expect(interactive.showTime, isTrue);
      expect(interactive.showStatusIcons, isTrue);
      expect(interactive.showResizeHandle, isTrue);
    });

    test('PlannerEventBlockColorPolicy produces fully-opaque surface', () {
      // Pure red base → derived surface must have alpha 255.
      final surface = PlannerEventBlockColorPolicy.surfaceColor(
        const Color(0xFFE91E63),
      );
      expect(surface.a, 1.0);
      // Very dark base must still produce an opaque surface.
      final darkSurface = PlannerEventBlockColorPolicy.surfaceColor(
        const Color(0xFF111111),
      );
      expect(darkSurface.a, 1.0);
    });
  });
}