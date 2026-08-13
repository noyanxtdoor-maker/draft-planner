/// Profile-scoped read/write path for the configurable start-of-week
/// preference (Local-Profile planning preference).
///
/// The value is persisted in the existing `PlannerPreferences.weekStartDay`
/// column (schema v24) so no migration or new table is required.  `DateTime`
/// weekday constants are used (`DateTime.monday` .. `DateTime.sunday`).
abstract interface class StartOfWeekRepository {
  /// Returns the configured first day of the week for [profileId], or
  /// `DateTime.monday` when no preference row exists yet.
  Future<int> readStartOfWeek({required String profileId});

  /// Persists [startDay] for [profileId].  Only the start-of-week column is
  /// touched; all other preference columns are preserved.
  Future<void> saveStartOfWeek({
    required String profileId,
    required int startDay,
  });
}
