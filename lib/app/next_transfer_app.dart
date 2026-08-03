import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/application/privacy_services.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

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

  @override
  void initState() {
    super.initState();
    _backgroundSession = PrivacyBackgroundSession(
      clock: ref.read(monotonicClockProvider),
    );
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
          unawaited(
            ref.read(homeIndicatorControllerProvider.notifier).refresh(),
          );
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
    final router = ref.watch(appRouterProvider);
    final environment = ref.watch(appEnvironmentProvider);

    return MaterialApp.router(
      title: 'Next Transfer',
      debugShowCheckedModeBanner: environment.showDebugBanner,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
