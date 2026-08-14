import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/settings/application/appearance_providers.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/settings/data/drift_appearance_repository.dart';
import 'package:rmplanner/features/settings/presentation/appearance_screen.dart';
import 'package:rmplanner/features/settings/presentation/settings_screen.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

import '../../../support/test_dependencies.dart';

void main() {
  Future<AppDatabase> pumpApp(
    WidgetTester tester, {
    required AppearanceMode initialAppearance,
    ThemeColorMode initialThemeColor = ThemeColorMode.rose,
    AppDatabase? database,
  }) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final resolvedDatabase = database ?? openMemoryDatabase();
    if (database == null) {
      addTearDown(resolvedDatabase.close);
    }
    final privacy = TestPrivacyDependencies(database: resolvedDatabase);
    final startup = buildTestRepository(
      database: resolvedDatabase,
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
        initialAppearance: initialAppearance,
        initialThemeColor: initialThemeColor,
      ),
    );
    await tester.pumpAndSettle();
    return resolvedDatabase;
  }

  ThemeMode? themeModeOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;

  /// Navigates Home -> drawer -> Settings so the Appearance row is reachable.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home-hamburger')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('drawer-account-settings')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('global-app-drawer-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-account-settings')));
    await tester.pumpAndSettle();
  }

  group('B2 activation', () {
    testWidgets('saved Dark is the initial ThemeMode.dark on first build',
        (tester) async {
      await pumpApp(tester, initialAppearance: AppearanceMode.dark);
      expect(themeModeOf(tester), ThemeMode.dark);
    });

    testWidgets('saved Light is the initial ThemeMode.light on first build',
        (tester) async {
      await pumpApp(tester, initialAppearance: AppearanceMode.light);
      expect(themeModeOf(tester), ThemeMode.light);
    });

    testWidgets('saved System is ThemeMode.system', (tester) async {
      await pumpApp(tester, initialAppearance: AppearanceMode.system);
      expect(themeModeOf(tester), ThemeMode.system);
    });

    testWidgets('Light ignores a simulated Dark platform', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, initialAppearance: AppearanceMode.light);
      expect(themeModeOf(tester), ThemeMode.light);
      // Resolved rendered brightness stays light.
      final brightness = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .theme!
          .brightness;
      expect(brightness, Brightness.light);
    });

    testWidgets('Dark ignores a simulated Light platform', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, initialAppearance: AppearanceMode.dark);
      expect(themeModeOf(tester), ThemeMode.dark);
      final brightness = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .darkTheme!
          .brightness;
      expect(brightness, Brightness.dark);
    });

    testWidgets('System follows a live platform-brightness change',
        (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, initialAppearance: AppearanceMode.system);
      expect(themeModeOf(tester), ThemeMode.system);
      await openSettings(tester);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('Settings exposes the Appearance row and route',
        (tester) async {
      await pumpApp(tester, initialAppearance: AppearanceMode.system);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceScreen), findsOneWidget);
    });

    testWidgets('Appearance screen shows the selected mode',
        (tester) async {
      await pumpApp(tester, initialAppearance: AppearanceMode.dark);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceScreen), findsOneWidget);
      // The Dark option must be marked selected.
      expect(
        tester
            .widget<RadioListTile<AppearanceMode>>(
              find.byKey(const Key('appearance-option-dark')),
            )
            .value,
        AppearanceMode.dark,
      );
    });

    testWidgets('choosing Light applies it live and persists across relaunch',
        (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      await pumpApp(tester, initialAppearance: AppearanceMode.dark, database: database);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appearance-option-light')));
      await tester.pumpAndSettle();
      expect(themeModeOf(tester), ThemeMode.light);

      // Simulated relaunch: a fresh app build on the SAME database with the
      // persisted value read through the real repository.
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      expect(await repository.readAppearance(), AppearanceMode.light);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        initialAppearance: await repository.readAppearance(),
        database: database,
      );
      expect(themeModeOf(tester), ThemeMode.light);
    });

    testWidgets(
        'theme switch does NOT reload Goal/Planner/Home domain providers',
        (tester) async {
      // Performance isolation probe (Pack B2 section 13): the Appearance
      // notifier touches presentation state only.  Switching themes must not
      // rerun GoalBootstrap/readPlanning, weekly-plan providers, or Home
      // Life Goals reads.  Provider identity is the observable: a rerun
      // would replace the cached AsyncValue instance.
      await pumpApp(tester, initialAppearance: AppearanceMode.dark);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final today = container.read(plannerDateSourceProvider).today();
      final startOfWeek = container.read(startOfWeekProvider);
      final periodStart = IndicatorPeriod.currentWeek(
        today,
        startDay: startOfWeek,
      ).start;

      final planBefore = container.read(goalPlanningProvider(periodStart));
      final weeklyBefore = container.read(
        weeklyPlanEstablishedProvider(periodStart),
      );
      final templeBefore = container.read(nextTempleVisitProvider);

      await container
          .read(appearanceProvider.notifier)
          .setMode(AppearanceMode.light);
      await tester.pumpAndSettle();

      final planAfter = container.read(goalPlanningProvider(periodStart));
      final weeklyAfter = container.read(
        weeklyPlanEstablishedProvider(periodStart),
      );
      final templeAfter = container.read(nextTempleVisitProvider);

      expect(identical(planBefore, planAfter), isTrue,
          reason: 'Goal planning reran on a theme change');
      expect(identical(weeklyBefore, weeklyAfter), isTrue,
          reason: 'Weekly-plan establishment reran on a theme change');
      expect(identical(templeBefore, templeAfter), isTrue,
          reason: 'Home Life Goals reran on a theme change');
    });
  });

  group('B2-CORRECTION theme color', () {
    Color primaryOf(WidgetTester tester) =>
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .colorScheme
            .primary;

    testWidgets('saved Blue is the initial Light primary on first build',
        (tester) async {
      await pumpApp(
        tester,
        initialAppearance: AppearanceMode.light,
        initialThemeColor: ThemeColorMode.blue,
      );
      expect(themeModeOf(tester), ThemeMode.light);
      expect(primaryOf(tester), AppTheme.blueLightPrimary);
    });

    testWidgets('saved Blue in Dark keeps the Blue Dark semantic primary',
        (tester) async {
      await pumpApp(
        tester,
        initialAppearance: AppearanceMode.dark,
        initialThemeColor: ThemeColorMode.blue,
      );
      final darkPrimary = tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .darkTheme!
          .colorScheme
          .primary;
      expect(darkPrimary, AppTheme.blueDarkPrimary);
    });

    testWidgets('Appearance screen shows the THEME COLOR Rose/Blue selection',
        (tester) async {
      await pumpApp(
        tester,
        initialAppearance: AppearanceMode.dark,
        initialThemeColor: ThemeColorMode.rose,
      );
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      expect(find.byType(AppearanceScreen), findsOneWidget);
      expect(
        tester
            .widget<RadioListTile<ThemeColorMode>>(
              find.byKey(const Key('theme-color-option-rose')),
            )
            .value,
        ThemeColorMode.rose,
      );
      // Theme Color is independent: Appearance stayed Dark while Blue is
      // available and unselected.
      expect(
        tester
            .widget<RadioListTile<ThemeColorMode>>(
              find.byKey(const Key('theme-color-option-blue')),
            )
            .value,
        ThemeColorMode.blue,
      );
      expect(
        tester
            .widget<RadioListTile<AppearanceMode>>(
              find.byKey(const Key('appearance-option-dark')),
            )
            .value,
        AppearanceMode.dark,
      );
    });

    testWidgets('choosing Blue applies it live and persists across relaunch',
        (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      // Persist Dark in the DB first so the independence of the two
      // dimensions is observable (the provider seed alone never writes).
      final seedRepository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      await seedRepository.saveAppearance(AppearanceMode.dark);
      await pumpApp(
        tester,
        initialAppearance: AppearanceMode.dark,
        database: database,
      );
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('settings-appearance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('theme-color-option-blue')));
      await tester.pumpAndSettle();
      // Live: the Light theme primary becomes Blue even while Dark mode is
      // active (independent dimension).
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .darkTheme!
            .colorScheme
            .primary,
        AppTheme.blueDarkPrimary,
      );

      // Simulated relaunch on the SAME database.
      final repository = DriftAppearanceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      );
      expect(await repository.readThemeColor(), ThemeColorMode.blue);
      expect(await repository.readAppearance(), AppearanceMode.dark);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(
        tester,
        initialAppearance: await repository.readAppearance(),
        initialThemeColor: await repository.readThemeColor(),
        database: database,
      );
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .darkTheme!
            .colorScheme
            .primary,
        AppTheme.blueDarkPrimary,
      );
    });

    testWidgets('Rose/Blue switch does NOT reload Goal/Planner/Home providers',
        (tester) async {
      await pumpApp(tester, initialAppearance: AppearanceMode.dark);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final today = container.read(plannerDateSourceProvider).today();
      final startOfWeek = container.read(startOfWeekProvider);
      final periodStart = IndicatorPeriod.currentWeek(
        today,
        startDay: startOfWeek,
      ).start;

      final planBefore = container.read(goalPlanningProvider(periodStart));
      final weeklyBefore = container.read(
        weeklyPlanEstablishedProvider(periodStart),
      );
      final templeBefore = container.read(nextTempleVisitProvider);

      await container
          .read(themeColorProvider.notifier)
          .setColor(ThemeColorMode.blue);
      await tester.pumpAndSettle();

      final planAfter = container.read(goalPlanningProvider(periodStart));
      final weeklyAfter = container.read(
        weeklyPlanEstablishedProvider(periodStart),
      );
      final templeAfter = container.read(nextTempleVisitProvider);

      expect(identical(planBefore, planAfter), isTrue,
          reason: 'Goal planning reran on a theme-color change');
      expect(identical(weeklyBefore, weeklyAfter), isTrue,
          reason: 'Weekly-plan establishment reran on a theme-color change');
      expect(identical(templeBefore, templeAfter), isTrue,
          reason: 'Home Life Goals reran on a theme-color change');
    });
  });
}
