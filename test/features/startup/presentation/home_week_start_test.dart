import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/settings/application/start_of_week_repository.dart';
import 'package:rmplanner/features/settings/data/drift_start_of_week_repository.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_repository.dart';
import 'package:rmplanner/features/weekly_planning/domain/weekly_plan.dart';

import '../../../support/test_dependencies.dart';

final class _DelayedWeeklyPlanningRepository
    implements WeeklyPlanningRepository {
  _DelayedWeeklyPlanningRepository({
    required this.today,
    required this.established,
  });

  final PlannerDate today;
  final bool established;
  final Completer<void> _release = Completer<void>();
  int openOrCreateCalls = 0;

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  @override
  Future<WeeklyPlan> openOrCreate({
    required String profileId,
    required PlannerDate date,
    int startDay = DateTime.monday,
  }) async {
    openOrCreateCalls += 1;
    await _release.future;
    final period = WeeklyPeriod.containing(date, startDay: startDay);
    return WeeklyPlan(
      id: 'delayed-plan',
      profileId: profileId,
      period: period,
      timeZoneId: 'Asia/Manila',
      storedState: WeeklyPlanState.draft,
      indicators: const <WeeklyIndicatorReview>[],
      createdAtUtc: DateTime.utc(2026, 8, 13),
      updatedAtUtc: DateTime.utc(2026, 8, 13),
    );
  }

  @override
  Future<WeeklyPlan?> readPlanForPeriod({
    required String profileId,
    required PlannerDate periodStart,
  }) async {
    if (!established) {
      return null;
    }
    return WeeklyPlan(
      id: 'existing-plan',
      profileId: profileId,
      period: WeeklyPeriod.containing(periodStart),
      timeZoneId: 'Asia/Manila',
      storedState: WeeklyPlanState.draft,
      indicators: const <WeeklyIndicatorReview>[],
      createdAtUtc: DateTime.utc(2026, 8, 13),
      updatedAtUtc: DateTime.utc(2026, 8, 13),
    );
  }

  @override
  Future<PlannerDate> todayForProfile(String profileId) async => today;

  @override
  Future<WeeklyPlan?> readPlan({
    required String profileId,
    required String planId,
  }) async => null;

  @override
  Future<List<WeeklyPlan>> readHistory(String profileId) async =>
      const <WeeklyPlan>[];
}

final class _MutablePlannerDateSource implements PlannerDateSource {
  _MutablePlannerDateSource(this.value);

  PlannerDate value;

  @override
  PlannerDate today() => value;
}

final class _ControlledStartOfWeekRepository
    implements StartOfWeekRepository {
  _ControlledStartOfWeekRepository(this.value);

  int value;
  int readCalls = 0;
  bool _holdNextRead = false;
  Completer<int>? _pendingRead;

  void holdNextRead() {
    _holdNextRead = true;
    _pendingRead = Completer<int>();
  }

  void releasePendingRead() {
    final pending = _pendingRead;
    if (pending != null && !pending.isCompleted) {
      pending.complete(value);
    }
  }

  @override
  Future<int> readStartOfWeek({required String profileId}) {
    readCalls += 1;
    if (_holdNextRead) {
      _holdNextRead = false;
      return _pendingRead!.future;
    }
    return Future<int>.value(value);
  }

  @override
  Future<void> saveStartOfWeek({
    required String profileId,
    required int startDay,
  }) async {
    value = startDay;
  }
}

void main() {
  // 2026-08-13 is a Thursday.  Monday week = Aug 10-16; Sunday week = Aug 9-15.
  const thursday = PlannerDate(year: 2026, month: 8, day: 13);

  Future<void> pumpHome(
    WidgetTester tester,
    AppDatabase database, {
    PlannerDate today = thursday,
    PlannerDateSource? plannerDateSource,
    WeeklyPlanningRepository? weeklyPlanningRepository,
    StartOfWeekRepository? startOfWeekRepository,
  }) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        plannerDateSource:
            plannerDateSource ?? FixedPlannerDateSource(today),
        weeklyPlanningRepository: weeklyPlanningRepository,
        startOfWeekRepository: startOfWeekRepository,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unestablished current period hides cards and shows Start Planning',
      (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    await pumpHome(tester, database);

    // Header + View All remain.
    expect(find.text('Life Goals'), findsOneWidget);
    expect(find.byKey(const Key('home-wli-view-all')), findsOneWidget);
    // Life Goal cards are hidden.
    final goalCards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('home-indicator-goal-');
    });
    expect(goalCards, findsNothing);
    expect(find.byKey(const Key('home-daily-target-quick-control')), findsNothing);
    // Centered Start Planning is visible.
    expect(find.byKey(const Key('home-start-weekly-planning')), findsOneWidget);
    expect(find.text('Start Planning'), findsOneWidget);
    // The established pill is NOT shown.
    expect(find.text('Goal Planning'), findsNothing);
    // Active Pathways unchanged.
    expect(find.byKey(const Key('home-pathway-employment')), findsOneWidget);
  });

  testWidgets(
      'deliberate entry establishes the period; Home then shows cards and '
      'Goal Planning', (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    await pumpHome(tester, database);

    expect(find.byKey(const Key('home-start-weekly-planning')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-start-weekly-planning')));
    await tester.pumpAndSettle();
    // The Goal Planning screen opens with the new title.
    expect(find.text('Goal Planning'), findsWidgets);

    // Return Home: now established.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Goal Planning'), findsOneWidget);
    expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
    // Cards are visible again (the six canonical Goals were bootstrapped).
    final goalCards = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('home-indicator-goal-');
    });
    expect(goalCards, findsWidgets);
  });

  testWidgets('established Home shows the Goal Planning pill and 0/0 for unset',
      (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    await establishWeeklyPlan(
      database: database,
      profileId: profile.id,
      date: thursday,
    );
    await pumpHome(tester, database);

    expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
    expect(find.text('Goal Planning'), findsOneWidget);
    // Home-only unset target renders 0/0 (never 0/Not set).
    expect(find.textContaining('Not set'), findsNothing);
    expect(find.text('0/0'), findsWidgets);
  });

  for (final entry in <({bool established, String button})>[
    (established: false, button: 'Start Planning'),
    (established: true, button: 'Goal Planning'),
  ]) {
    testWidgets(
      'A1: ${entry.button} opens Goal Planning before openOrCreate finishes',
      (tester) async {
        final database = openMemoryDatabase();
        addTearDown(database.close);
        final delayed = _DelayedWeeklyPlanningRepository(
          today: thursday,
          established: entry.established,
        );
        addTearDown(delayed.release);
        await pumpHome(
          tester,
          database,
          weeklyPlanningRepository: delayed,
        );

        expect(find.text(entry.button), findsOneWidget);
        await tester.tap(find.byKey(const Key('weekly-targets-button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('weekly-plan-back-home')),
          findsOneWidget,
          reason:
              '${entry.button} must transfer control to the destination '
              'without waiting for local plan establishment.',
        );
        expect(delayed.openOrCreateCalls, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        delayed.release();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('weekly-plan-list')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A2: same-day resume keeps confirmed Home without provider reload churn',
    (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await establishWeeklyPlan(
        database: database,
        profileId: profile.id,
        date: thursday,
        startDay: DateTime.sunday,
      );
      final dates = _MutablePlannerDateSource(thursday);
      final startOfWeek = _ControlledStartOfWeekRepository(DateTime.sunday);
      addTearDown(startOfWeek.releasePendingRead);
      await pumpHome(
        tester,
        database,
        plannerDateSource: dates,
        startOfWeekRepository: startOfWeek,
      );
      final initialReads = startOfWeek.readCalls;
      expect(find.text('Goal Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('home-canonical-plan-loading')),
        findsNothing,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(
        startOfWeek.readCalls,
        initialReads,
        reason: 'Same-day resume must not re-read an unchanged preference.',
      );
      expect(find.text('Goal Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('home-canonical-plan-loading')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'A2: date-boundary resume retains confirmed Home while preference reloads',
    (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      await establishWeeklyPlan(
        database: database,
        profileId: profile.id,
        date: thursday,
        startDay: DateTime.sunday,
      );
      final dates = _MutablePlannerDateSource(thursday);
      final startOfWeek = _ControlledStartOfWeekRepository(DateTime.sunday);
      addTearDown(startOfWeek.releasePendingRead);
      await pumpHome(
        tester,
        database,
        plannerDateSource: dates,
        startOfWeekRepository: startOfWeek,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('home-app-bar'))),
      );
      final initialReads = startOfWeek.readCalls;
      expect(container.read(startOfWeekProvider), DateTime.sunday);
      expect(find.text('Goal Planning'), findsOneWidget);

      startOfWeek.holdNextRead();
      dates.value = thursday.addDays(1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(startOfWeek.readCalls, initialReads + 1);
      expect(
        container.read(startOfWeekProvider),
        DateTime.sunday,
        reason:
            'A pending refresh must preserve the last confirmed preference.',
      );
      expect(find.text('Goal Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('home-canonical-plan-loading')),
        findsNothing,
      );

      startOfWeek.releasePendingRead();
      await tester.pumpAndSettle();
      expect(container.read(startOfWeekProvider), DateTime.sunday);
      expect(find.text('Goal Planning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a non-Monday configured start is used for the current period',
      (tester) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final startOfWeek = DriftStartOfWeekRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 13, 12)),
    );
    await startOfWeek.saveStartOfWeek(
      profileId: profile.id,
      startDay: DateTime.sunday,
    );
    // Establish the SUNDAY week (Aug 9-15), not the Monday week (Aug 10-16).
    await establishWeeklyPlan(
      database: database,
      profileId: profile.id,
      date: thursday,
      startDay: DateTime.sunday,
    );
    await pumpHome(tester, database);

    expect(find.text('Goal Planning'), findsOneWidget);
    expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
    // With only the Sunday week established, opening planning must land on
    // the Sunday-resolved period (Aug 9-15).
    await tester.tap(find.byKey(const Key('weekly-targets-button')));
    await tester.pumpAndSettle();
    expect(find.text('Goal Planning'), findsWidgets);
    expect(find.text('Aug 9 – Aug 15, 2026'), findsOneWidget);
  });
}
