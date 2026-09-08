import 'package:rmplanner/features/planner/domain/planner_date.dart';

/// A canonical 7-day local-calendar week window produced by [resolveWeek].
///
/// Every active non-frozen weekly consumer (Home, Goal Planning, target
/// revisions, WeeklyPlans, history) must derive its period identity from this
/// single resolver so that a configured start-of-week day is honored
/// everywhere.  The frozen Planner week view keeps its own already-parameterized
/// `_weekDates` helper and does not use this type.
final class WeekPeriod {
  const WeekPeriod({required this.start, required this.end});

  /// First day of the week; `start.weekday == configured startDay`.
  final PlannerDate start;

  /// Exactly `start + 6` local-calendar days.
  final PlannerDate end;

  bool contains(PlannerDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  /// Adjacent week with the same configured start day.  Weeks are always
  /// exactly 7 days, so movement is a plain +/- 7 from [start].
  WeekPeriod shifted(int weeks) =>
      WeekPeriod(start: start.addDays(7 * weeks), end: end.addDays(7 * weeks));

  String get key => start.iso8601;
}

/// Resolves the canonical 7-day week window containing [date] for a
/// configured first day of the week.
///
/// [startDay] uses `DateTime.monday` (1) .. `DateTime.sunday` (7).
///
/// Math (locked contract):
///   offset = (date.weekday - startDay + 7) % 7
///   start  = date - offset local-calendar days
///   end    = start + 6
///
/// Local-calendar only; no UTC conversion is used for weekly identity.
WeekPeriod resolveWeek({required PlannerDate date, required int startDay}) {
  if (startDay < DateTime.monday || startDay > DateTime.sunday) {
    throw ArgumentError.value(startDay, 'startDay', 'Must be 1..7');
  }
  final offset = (date.weekday - startDay + 7) % 7;
  final start = date.addDays(-offset);
  return WeekPeriod(start: start, end: start.addDays(6));
}
