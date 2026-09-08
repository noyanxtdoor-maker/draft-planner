import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
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
/// B2-FINAL-POLISH owner lock: the fallback default is [AppearanceMode.dark]
/// (also the fresh-install semantics when nothing is persisted).  main()
/// overrides this with the value read from the device repository BEFORE
/// runApp so the first MaterialApp build already has the persisted mode (no
/// wrong-theme first frame).  Tests may override it directly to pin a mode.
final initialAppearanceProvider = Provider<AppearanceMode?>((ref) => null);

final appearanceProvider = NotifierProvider<AppearanceNotifier, AppearanceMode>(
  AppearanceNotifier.new,
);

final class AppearanceNotifier extends Notifier<AppearanceMode> {
  @override
  AppearanceMode build() {
    final initial = ref.watch(initialAppearanceProvider);
    if (initial != null) {
      return initial;
    }
    return AppearanceMode.dark;
  }

  /// Re-reads the persisted device appearance and applies it to state.
  /// Storage failures fail safely to [AppearanceMode.dark].
  Future<AppearanceMode> refresh() async {
    AppearanceMode value;
    try {
      value = await ref.read(deviceAppearanceRepositoryProvider).readAppearance();
    } on Object {
      value = AppearanceMode.dark;
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

/// Optional pre-runApp seed for the Theme Color.  main() overrides this with
/// the value read from the device repository BEFORE runApp so the first
/// MaterialApp build already has the persisted color (no wrong-color first
/// frame).  Tests may override it directly to pin a color.  Null keeps the
/// [ThemeColorMode.blue] default (B2-FINAL-POLISH owner lock; also the
/// fresh-install semantics).
final initialThemeColorProvider = Provider<ThemeColorMode?>((ref) => null);

/// Independent Theme Color notifier.  Appearance Mode and Theme Color are
/// two independent dimensions: switching one never touches the other, and
/// neither invalidates Goal/Planner/Home domain providers.
final themeColorProvider = NotifierProvider<ThemeColorNotifier, ThemeColorMode>(
  ThemeColorNotifier.new,
);

final class ThemeColorNotifier extends Notifier<ThemeColorMode> {
  @override
  ThemeColorMode build() {
    final initial = ref.watch(initialThemeColorProvider);
    if (initial != null) {
      return initial;
    }
    return ThemeColorMode.blue;
  }

  /// Re-reads the persisted device Theme Color and applies it to state.
  /// Storage failures fail safely to [ThemeColorMode.blue].
  Future<ThemeColorMode> refresh() async {
    ThemeColorMode value;
    try {
      value = await ref.read(deviceAppearanceRepositoryProvider).readThemeColor();
    } on Object {
      value = ThemeColorMode.blue;
    }
    state = value;
    return value;
  }

  /// Persists [color] for the device (one bounded single-row write), then
  /// applies it to in-memory state so watchers re-resolve.  Returns false
  /// when persistence fails (state keeps the last confirmed value).
  Future<bool> setColor(ThemeColorMode color) async {
    try {
      await ref.read(deviceAppearanceRepositoryProvider).saveThemeColor(color);
    } on Object {
      return false;
    }
    state = color;
    return true;
  }
}
