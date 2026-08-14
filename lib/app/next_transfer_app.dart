import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/settings/application/appearance_providers.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';
import 'package:rmplanner/features/weekly_planning/application/weekly_planning_providers.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw StateError('AppEnvironment must be overridden at the app root');
});

final class NextTransferApp extends ConsumerStatefulWidget {
  const NextTransferApp({super.key});

  @override
  ConsumerState<NextTransferApp> createState() => _NextTransferAppState();
}

final class _NextTransferAppState extends ConsumerState<NextTransferApp>
    with WidgetsBindingObserver {
  late final PrivacyBackgroundSession _backgroundSession;
  late PlannerDate _lastResolvedDate;

  @override
  void initState() {
    super.initState();
    _backgroundSession = PrivacyBackgroundSession(
      clock: ref.read(monotonicClockProvider),
    );
    _lastResolvedDate = ref.read(plannerDateSourceProvider).today();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _backgroundSession.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(privacyControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (ref.read(privacyControllerProvider).settings.lockEnabled) {
          _backgroundSession.enterBackground(() {
            _relockForBackground(controller);
          });
        }
      case AppLifecycleState.resumed:
        if (_backgroundSession.resume()) {
          _relockForBackground(controller);
        }
        if (ref.read(startupControllerProvider) is StartupReady) {
          final resolvedDate = ref.read(plannerDateSourceProvider).today();
          if (resolvedDate != _lastResolvedDate) {
            _lastResolvedDate = resolvedDate;
            // A real local-date boundary can change Home's active period.
            // Preserve confirmed provider values while re-resolving instead
            // of rebuilding every provider on every same-day resume.
            ref.invalidate(plannerDateSourceProvider);
            unawaited(ref.read(startOfWeekProvider.notifier).refresh());
            ref.invalidate(goalPlanningProvider);
            ref.invalidate(weeklyPlanEstablishedProvider);
            unawaited(
              ref.read(homeIndicatorControllerProvider.notifier).refresh(),
            );
          }
        }
    }
  }

  void _relockForBackground(PrivacyController controller) {
    final relocked = controller.lockForBackground();
    if (relocked) {
      unawaited(ref.read(startupControllerProvider.notifier).initialize());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(privacyControllerProvider);
    // Pack B2: the device Appearance drives ThemeMode.  The notifier is
    // seeded synchronously from the pre-runApp read (main.dart), so the first
    // build already has the persisted mode.  Changing it rebuilds the
    // presentation layer only — no Goal/Planner domain provider is touched.
    final appearance = ref.watch(appearanceProvider);
    final themeColor = ref.watch(themeColorProvider);
    final router = ref.watch(appRouterProvider);
    final environment = ref.watch(appEnvironmentProvider);

    return MaterialApp.router(
      title: 'Next Transfer',
      debugShowCheckedModeBanner: environment.showDebugBanner,
      // B2-CORRECTION: Appearance Mode chooses brightness; Theme Color
      // chooses the semantic palette.  Both are seeded synchronously before
      // runApp, so the first build already has the persisted pair.  Changing
      // either rebuilds the presentation layer only — no Goal/Planner domain
      // provider is touched.
      theme: AppTheme.light(themeColor),
      darkTheme: AppTheme.dark(themeColor),
      themeMode: switch (appearance) {
        AppearanceMode.system => ThemeMode.system,
        AppearanceMode.light => ThemeMode.light,
        AppearanceMode.dark => ThemeMode.dark,
      },
      // B2-CORRECTION: explicit SystemUiOverlayStyle from the ACTIVE
      // ThemeData.  The Flutter presets hard-code a black navigation bar with
      // light icons in BOTH themes, which Android 15+ contrast enforcement
      // turns into a black region in Light.  Here Light gets the semantic
      // app/nav surface with dark icons and disabled contrast enforcement;
      // Dark keeps the dark appearance.  Status bar stays transparent with
      // brightness-correct icons.  The native splash stays system-following.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: const Color(0xFF101113),
                systemNavigationBarIconBrightness: Brightness.light,
                systemNavigationBarContrastEnforced: false,
              )
            : SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
                statusBarBrightness: Brightness.light,
                systemNavigationBarColor:
                    Theme.of(context).colorScheme.surfaceContainer,
                systemNavigationBarIconBrightness: Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
        child: child!,
      ),
      routerConfig: router,
    );
  }
}
