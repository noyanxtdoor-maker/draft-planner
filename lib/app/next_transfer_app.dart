import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) {
      return;
    }
    final relocked = ref
        .read(privacyControllerProvider.notifier)
        .lockForBackground();
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
