import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

abstract final class StartupRouteGuard {
  static const Set<String> _gateLocations = <String>{
    RoutePaths.startup,
    RoutePaths.onboarding,
    RoutePaths.recovery,
    RoutePaths.protectedContent,
  };

  static String? redirect({
    required StartupState state,
    required String currentLocation,
  }) {
    return switch (state) {
      StartupOpening() => _unlessCurrent(currentLocation, RoutePaths.startup),
      StartupWelcome() || StartupOnboarding() => _unlessCurrent(
        currentLocation,
        RoutePaths.onboarding,
      ),
      StartupRecovery() => _unlessCurrent(currentLocation, RoutePaths.recovery),
      StartupProtected() => _unlessCurrent(
        currentLocation,
        RoutePaths.protectedContent,
      ),
      StartupReady() =>
        _gateLocations.contains(currentLocation) ? RoutePaths.home : null,
    };
  }

  static String? _unlessCurrent(String current, String expected) {
    return current == expected ? null : expected;
  }
}
