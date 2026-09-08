/// Independent Theme Color dimension (B2-CORRECTION).
///
/// B2-FINAL-POLISH owner lock: BLUE is the default from now on (fresh,
/// missing, and invalid values all resolve to Blue).  Rose remains fully
/// supported as a valid stored choice.  The value is stored independently of
/// [AppearanceMode] in the same device-scoped `AppearancePreferences` row.
enum ThemeColorMode {
  rose('rose'),
  blue('blue');

  const ThemeColorMode(this.storageName);

  final String storageName;

  /// Parses a persisted string, failing safely to [ThemeColorMode.blue] for
  /// missing, null, or unknown values (B2-FINAL-POLISH owner lock).
  static ThemeColorMode fromStorage(String? value) {
    for (final mode in values) {
      if (mode.storageName == value) {
        return mode;
      }
    }
    return ThemeColorMode.blue;
  }
}
