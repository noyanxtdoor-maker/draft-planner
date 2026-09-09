import 'package:drift/drift.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/goals/domain/goal_event_type_policy.dart';

/// Read-only live slot occupancy for Event Type creation eligibility (D.2).
///
/// Raw SQL status='active' select for the profile; NO writes, NO
/// GoalBootstrap.ensure, NO readPlanning/readActiveGoals side effects.
/// Occupant counting and every identity validation run in the pure policy;
/// corrupt slots (two raw-active occupants) fail closed and are simply
/// absent from the returned map. Callers must treat loading/errors as
/// "no eligibility" (never fall back to all-six).
Future<Map<int, LiveGoalEventTypeBinding>> readLiveGoalEventTypeBindings(
  AppDatabase database,
  String profileId,
) async {
  final rows =
      await (database.select(database.goals)..where(
            (table) =>
                table.profileId.equals(profileId) &
                // Raw status exactly 'active': paused/completed/unknown
                // legacy statuses are ineligible for NEW selections even
                // though the model layer maps them to active elsewhere.
                table.status.equals('active'),
          )).get();
  final candidates = <LiveGoalCandidateRow>[];
  for (final row in rows) {
    candidates.add(
      LiveGoalCandidateRow(
        id: row.id,
        profileId: row.profileId,
        status: row.status,
        role: row.role,
        activeSlotIndex: row.activeSlotIndex,
        assignedEventTypeStableKey: row.assignedEventTypeStableKey,
        indicatorKey: row.indicatorKey,
        title: row.title,
      ),
    );
  }
  return GoalEventTypePolicy.bindingsForCandidates(
    candidates: candidates,
    profileId: profileId,
  );
}
