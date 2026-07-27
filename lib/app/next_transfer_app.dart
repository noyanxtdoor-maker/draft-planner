import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/core/platform/app_environment.dart';

final appEnvironmentProvider = Provider<AppEnvironment>((ref) {
  throw StateError('AppEnvironment must be overridden at the app root');
});

final class NextTransferApp extends ConsumerWidget {
  const NextTransferApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
