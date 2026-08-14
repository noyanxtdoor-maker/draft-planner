import 'package:rmplanner/app/theme/theme_color_mode.dart';

/// Device-scoped appearance preference (Pack B1 Appearance foundation).
///
/// `system` follows the Android platform brightness, `light` forces Light,
/// and `dark` forces Dark regardless of the platform.  The value is stored
/// as the enum's [storageName] string in the single-row
/// `AppearancePreferences` table and never depends on a Local Profile or any
/// Goal/Planner/startup domain state.
enum AppearanceMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppearanceMode(this.storageName);

  final String storageName;

    /// Parses a persisted string, failing safely to [AppearanceMode.dark]
  /// for missing, null, or unknown values (B2-FINAL-POLISH owner lock:
  /// DARK is the default from now on).
  static AppearanceMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageName == value) {
        return mode;
      }
    }
    return AppearanceMode.dark;
  }
}

/// Device-scoped read/write path for the Appearance preference.
///
/// The values are persisted in the existing single-row
/// `AppearancePreferences` table (schema v26) so no profile or domain
/// readiness is required to read them before the first frame.
abstract interface class AppearanceRepository {
  /// Returns the current device appearance, or [AppearanceMode.dark] when
  /// no row exists yet or the stored value is invalid (B2-FINAL-POLISH
  /// owner lock: DARK is the default).
  Future<AppearanceMode> readAppearance();

  /// Persists [mode] for the device.  Setting the same value is an
  /// idempotent no-write (updated_at_utc only moves on a real change).
  Future<void> saveAppearance(AppearanceMode mode);

  /// Returns the current device Theme Color, or [ThemeColorMode.blue] when
  /// no row exists yet or the stored value is invalid (B2-FINAL-POLISH
  /// owner lock: BLUE is the default).
  Future<ThemeColorMode> readThemeColor();

  /// Persists [color] for the device, independent of the Appearance Mode.
  /// Setting the same value is an idempotent no-write.
  Future<void> saveThemeColor(ThemeColorMode color);
}
