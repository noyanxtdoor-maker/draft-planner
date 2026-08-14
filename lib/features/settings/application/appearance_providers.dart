import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/settings/application/appearance_repository.dart';

/// Device-scoped Appearance repository, overridden at the app root.
///
/// B1 is dormant infrastructure: this provider is not yet watched by
/// MaterialApp (B2 activates the theme system).  It is presentation-only
/// and never invalidates Goal/Planner/startup domain providers.
final deviceAppearanceRepositoryProvider = Provider<AppearanceRepository>((ref) {
  throw StateError('AppearanceRepository must be overridden at the app root');
});

/// Current device appearance (System / Light / Dark).
///
/// The build default is [AppearanceMode.system]; B2 will seed the notifier
/// from the pre-runApp repository read before MaterialApp consumes it.
final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceMode>(
  AppearanceNotifier.new,
);

final class AppearanceNotifier extends Notifier<AppearanceMode> {
  @override
  AppearanceMode build() {
    return AppearanceMode.system;
  }

  /// Re-reads the persisted device appearance and applies it to state.
  /// Storage failures fail safely to [AppearanceMode.system].
  Future<AppearanceMode> refresh() async {
    AppearanceMode value;
    try {
      value = await ref.read(deviceAppearanceRepositoryProvider).readAppearance();
    } on Object {
      value = AppearanceMode.system;
    }
    state = value;
    return value;
  }

  /// Persists [mode] for the device, then applies it to in-memory state so
  /// watchers re-resolve.  Returns false when persistence fails (state keeps
  /// the last confirmed value).
  Future<bool> setMode(AppearanceMode mode) async {
    try {
      await ref.read(deviceAppearanceRepositoryProvider).saveAppearance(mode);
    } on Object {
      return false;
    }
    state = mode;
    return true;
  }
}
