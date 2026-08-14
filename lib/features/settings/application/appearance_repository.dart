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

  /// Parses a persisted string, failing safely to [AppearanceMode.system]
  /// for missing, null, or unknown values.
  static AppearanceMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageName == value) {
        return mode;
      }
    }
    return AppearanceMode.system;
  }
}

/// Device-scoped read/write path for the Appearance preference.
///
/// The value is persisted in the existing single-row
/// `AppearancePreferences` table (schema v25) so no profile or domain
/// readiness is required to read it before the first frame.
abstract interface class AppearanceRepository {
  /// Returns the current device appearance, or [AppearanceMode.system] when
  /// no row exists yet or the stored value is invalid.
  Future<AppearanceMode> readAppearance();

  /// Persists [mode] for the device.  Setting the same value is an
  /// idempotent no-write (updated_at_utc only moves on a real change).
  Future<void> saveAppearance(AppearanceMode mode);
}
