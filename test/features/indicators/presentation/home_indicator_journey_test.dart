import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/indicators/data/drift_indicator_repository.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_outcome_reporting_repository.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'VS-08 Home shows the unplanned current week and canonical planning entry',
    (tester) async {
      const monday = PlannerDate(year: 2026, month: 7, day: 27);
      tester.view.physicalSize = const Size(941, 1672);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      await startup.completeOnboarding();
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

      expect(find.text('Weekly Life Indicators'), findsOneWidget);
      expect(find.text('Start Weekly Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('home-start-weekly-planning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home-indicator-job_applications')),
        findsNothing,
      );
      expect(find.text('Scheduled'), findsNothing);
      expect(find.textContaining('worthiness'), findsNothing);
      expect(find.byKey(const Key('home-pathway-employment')), findsOneWidget);

      await tester.tap(find.text('Start Weekly Planning'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Planning'), findsOneWidget);
      expect(
        find.byKey(const Key('weekly-plan-indicator-job_applications')),
        findsOneWidget,
      );
      expect(find.text('Set Goal'), findsNWidgets(5));
      await tester.tap(
        find.byKey(const Key('weekly-plan-indicator-job_applications')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit Goal'), findsOneWidget);
      expect(find.text('Daily Progress Goal'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('goal-period-daily')),
          matching: find.byIcon(Icons.add_circle),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('goal-period-weekly')),
          matching: find.byIcon(Icons.add_circle),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('Weekly Planning'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Home remains usable at 200% text scale', (tester) async {
    const monday = PlannerDate(year: 2026, month: 7, day: 27);
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 2.5;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final startup = buildTestRepository(database: database);
    await startup.completeOnboarding();
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

    expect(find.text('Weekly Life Indicators'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('home-pathway-documents')),
      220,
      scrollable: find.descendant(
        of: find.byKey(const Key('home-indicator-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.byKey(const Key('home-pathway-documents')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Prompt A planned Home uses compact canonical WLI cards and Temple split',
    (tester) async {
      const monday = PlannerDate(year: 2026, month: 7, day: 27);
      tester.view.physicalSize = const Size(393, 874);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      const indicatorKeys = <String>[
        'job_applications',
        'scripture_study',
        'exercise',
        'meaningful_connections',
        'budget_review',
        'temple_visit',
      ];
      for (var index = 0; index < indicatorKeys.length; index += 1) {
        await indicators.saveGoal(
          profileId: profile.id,
          draft: IndicatorGoalRevisionDraft(
            id: '82000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
            operationId:
                '83000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
            indicatorKey: indicatorKeys[index],
            period: IndicatorGoalPeriod.weekly(monday),
            value: IndicatorAmount(
              scaledValue: index + 2,
              scale: 0,
              unit: 'count',
            ),
          ),
        );
      }
      await indicators.saveGoal(
        profileId: profile.id,
        draft: const IndicatorGoalRevisionDraft(
          id: '84000000-0000-4000-8000-000000000001',
          operationId: '85000000-0000-4000-8000-000000000001',
          indicatorKey: 'job_applications',
          period: IndicatorGoalPeriod(
            type: IndicatorGoalPeriodType.daily,
            start: monday,
            end: monday,
          ),
          value: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
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

      expect(find.text('Weekly Life Indicators'), findsOneWidget);
      expect(find.byKey(const Key('home-start-weekly-planning')), findsNothing);
      for (final key in indicatorKeys) {
        expect(find.byKey(Key('home-indicator-$key')), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const Key('home-indicator-job_applications')))
            .height,
        60,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('home-indicator-job_applications')))
            .width,
        closeTo(357, 0.01),
      );
      expect(
        tester.getSize(find.byKey(const Key('home-indicator-exercise'))).height,
        60,
      );
      expect(
        tester.getSize(find.byKey(const Key('home-indicator-exercise'))).width,
        closeTo(173.5, 0.01),
      );
      expect(
        tester
            .getSize(find.byKey(const Key('home-indicator-temple_visit')))
            .height,
        60,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('home-indicator-temple_visit')))
            .width,
        closeTo(357, 0.01),
      );
      expect(find.text('Month Goal'), findsOneWidget);
      expect(find.text("Today's Goal"), findsOneWidget);
      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('Set Schedule'), findsOneWidget);
      expect(find.text('Weekly Planning'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('home-indicator-temple_visit')));
      await tester.pumpAndSettle();
      expect(find.text('Select Event Type'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Prompt A planned Home responsive width matrix', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    const configurations = <({Size size, double textScale})>[
      (size: Size(360, 800), textScale: 1),
      (size: Size(393, 874), textScale: 1.15),
      (size: Size(411, 891), textScale: 1.3),
    ];
    for (final configuration in configurations) {
      tester.view.physicalSize = configuration.size;
      tester.platformDispatcher.textScaleFactorTestValue =
          configuration.textScale;
      final database = openMemoryDatabase();
      var databaseClosed = false;
      addTearDown(() async {
        if (!databaseClosed) {
          databaseClosed = true;
          await database.close();
        }
      });
      final startup = buildTestRepository(database: database);
      final profile = await startup.completeOnboarding();
      final clock = FixedClock(DateTime.utc(2026, 7, 27, 12));
      final reporting = DriftOutcomeReportingRepository(
        database: database,
        clock: clock,
      );
      final calendar = DriftCalendarEventRepository(
        database: database,
        clock: clock,
        timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
        reportSource: reporting,
      );
      final indicators = DriftIndicatorRepository(
        database: database,
        clock: clock,
        calendarEvents: calendar,
      );
      const monday = PlannerDate(year: 2026, month: 7, day: 27);
      const indicatorKeys = <String>[
        'job_applications',
        'scripture_study',
        'exercise',
        'meaningful_connections',
        'budget_review',
        'temple_visit',
      ];
      for (var index = 0; index < indicatorKeys.length; index += 1) {
        await indicators.saveGoal(
          profileId: profile.id,
          draft: IndicatorGoalRevisionDraft(
            id: '86000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
            operationId:
                '87000000-0000-4000-8000-${(index + 1).toString().padLeft(12, '0')}',
            indicatorKey: indicatorKeys[index],
            period: IndicatorGoalPeriod.weekly(monday),
            value: const IndicatorAmount(
              scaledValue: 1,
              scale: 0,
              unit: 'count',
            ),
          ),
        );
      }
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

      for (final key in indicatorKeys) {
        expect(find.byKey(Key('home-indicator-$key')), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const Key('home-indicator-job_applications')))
            .height,
        60,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await database.close();
      databaseClosed = true;
    }
  });
}
