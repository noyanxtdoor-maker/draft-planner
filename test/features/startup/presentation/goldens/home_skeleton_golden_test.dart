import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/application/start_of_week_repository.dart';

import '../../../../support/test_dependencies.dart';

/// Gates the initial persisted start-of-week read so the Home cannot form a
/// period family yet — the honest Life Goals skeleton is the only content.
final class _HeldStartOfWeekRepository implements StartOfWeekRepository {
  _HeldStartOfWeekRepository();

  final Completer<int> _pendingRead = Completer<int>();

  @override
  Future<int> readStartOfWeek({required String profileId}) {
    return _pendingRead.future;
  }

  @override
  Future<void> saveStartOfWeek({
    required String profileId,
    required int startDay,
  }) async {}

  void release() {
    if (!_pendingRead.isCompleted) {
      _pendingRead.complete(DateTime.monday);
    }
  }
}

void main() {
  const thursday = PlannerDate(year: 2026, month: 8, day: 13);

  void registerSkeletonGolden({
    required String name,
    Size viewport = const Size(393, 874),
    double textScale = 1,
  }) {
    testWidgets('Pack A skeleton golden: $name', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue,
      );

      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startup = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      await startup.completeOnboarding();
      final startOfWeek = _HeldStartOfWeekRepository();
      addTearDown(startOfWeek.release);
      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: FixedPlannerDateSource(thursday),
          startOfWeekRepository: startOfWeek,
        ),
      );
      // Pre-readiness Home holds the honest skeleton; settle manually to
      // avoid a pumpAndSettle timeout from the provisional loading state.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      final capture = find.byKey(const Key('home-life-goals-skeleton'));
      expect(capture, findsOneWidget);
      // The section header stays visible above the skeleton.
      expect(find.text('Life Goals'), findsOneWidget);
      // No fabricated content may leak into the placeholder.
      expect(find.text('Start Planning'), findsNothing);
      expect(find.text('Goal Planning'), findsNothing);
      expect(
        find.byKey(const Key('home-canonical-plan-loading')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('home-daily-target-quick-control')),
        findsNothing,
      );
      await expectLater(
        capture,
        matchesGoldenFile('goldens/home_skeleton/$name.png'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    });
  }

  registerSkeletonGolden(name: '01_skeleton_360', viewport: const Size(360, 800));
  registerSkeletonGolden(name: '02_skeleton_393', viewport: const Size(393, 874));
  registerSkeletonGolden(name: '03_skeleton_411', viewport: const Size(411, 891));
  registerSkeletonGolden(
    name: '04_skeleton_393_scale_1_30',
    viewport: const Size(393, 874),
    textScale: 1.3,
  );
}
