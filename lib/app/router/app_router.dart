import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/router/startup_route_guard.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/presentation/home_screen.dart';
import 'package:rmplanner/features/startup/presentation/link_recovery_screen.dart';
import 'package:rmplanner/features/startup/presentation/onboarding_screen.dart';
import 'package:rmplanner/features/startup/presentation/protected_content_screen.dart';
import 'package:rmplanner/features/startup/presentation/recovery_screen.dart';
import 'package:rmplanner/features/startup/presentation/startup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final startupState = ref.watch(startupControllerProvider);
  final router = GoRouter(
    initialLocation: RoutePaths.startup,
    redirect: (context, state) {
      return StartupRouteGuard.redirect(
        state: startupState,
        currentLocation: state.matchedLocation,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        name: RouteNames.startup,
        path: RoutePaths.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        name: RouteNames.onboarding,
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: RouteNames.recovery,
        path: RoutePaths.recovery,
        builder: (context, state) => const RecoveryScreen(),
      ),
      GoRoute(
        name: RouteNames.protectedContent,
        path: RoutePaths.protectedContent,
        builder: (context, state) => const ProtectedContentScreen(),
      ),
      GoRoute(
        name: RouteNames.home,
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        LinkRecoveryScreen(attemptedLocation: state.uri.toString()),
  );
  ref.onDispose(router.dispose);
  return router;
});
