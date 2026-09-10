import 'package:rmplanner/features/goals/domain/assigned_event_type_draft.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';

/// One explicitly changed Assigned Event Type presentation field. A missing
/// patch is never treated as a clear; an omitted patch means preserve.
final class LiveGoalPresentationPatch {
  const LiveGoalPresentationPatch({
    this.nameOverride,
    this.clearNameOverride = false,
    this.colorPreference,
  });

  /// MANUAL name for the live Goal. Ignored when [clearNameOverride] is set.
  final String? nameOverride;

  /// Explicit AUTO (Use Goal name): removes only this Goal's entry.
  final bool clearNameOverride;

  /// Changed slot color pair; null means preserve the current pair.
  final EventColorPreference? colorPreference;
}

/// One committed live Goal presentation save: the saved override state and
/// the saved slot color pair actually persisted inside the transaction.
final class LiveGoalPresentationResult {
  const LiveGoalPresentationResult({
    required this.nameMode,
    required this.nameOverride,
    required this.colorPreference,
  });

  final AssignedEventTypeNameMode nameMode;

  /// Null in AUTO mode; the trimmed stored name in MANUAL mode.
  final String? nameOverride;
  final EventColorPreference colorPreference;
}

abstract interface class EventTypeRepository {
  Future<List<EventType>> readEventTypes({
    required String profileId,
    bool includeArchived = false,
  });

  Future<EventType?> readEventType({
    required String profileId,
    required String eventTypeId,
  });

  Future<EventType?> readExactTypeForIndicator({
    required String profileId,
    required String indicatorKey,
  });

  Future<EventType> saveCustomType({
    required String profileId,
    required EventTypeDraft draft,
  });

  Future<void> renameSystemType({
    required String profileId,
    required String eventTypeId,
    required String label,
  });

  Future<void> setCustomTypeArchived({
    required String profileId,
    required String eventTypeId,
    required bool archived,
  });

  Future<void> restoreSystemDefaults({required String profileId});

  Future<PlannerSettings> readPlannerSettings({required String profileId});

  Future<PlannerSettings> savePlannerSettings({
    required String profileId,
    required PlannerSettings settings,
  });

  Future<Map<String, EventColorPreference>> readEventColorPreferences({
    required String profileId,
  });

  Future<Map<String, EventColorPreference>> saveEventColorPreference({
    required String profileId,
    required String eventTypeStableKey,
    required EventColorPreference preference,
  });

  Future<Map<String, EventColorPreference>> restoreEventColorDefaults({
    required String profileId,
  });

  Future<Map<String, int>> readContactGroupColors({required String profileId});

  Future<Map<String, int>> saveContactGroupColor({
    required String profileId,
    required String groupId,
    required int colorArgb,
  });

  Future<Map<String, int>> restoreContactGroupColorDefaults({
    required String profileId,
  });

  /// Profile-scoped change stream for the presentation document (event
  /// colors, group colors, Goal name overrides). Emits after every committed
  /// full-document write so providers can reproject display labels. Does
  /// NOT fire on unrelated table updates.
  Stream<void> watchPresentationDocument(String profileId);

  /// Reads the current validated name-override map keyed by real Goal UUID.
  Future<Map<String, GoalEventTypeNameOverride>> readGoalEventTypeNameOverrides(
    String profileId,
  );

  /// Settings-only live presentation save for one canonical slot's live
  /// Goal occupant: atomically commits the explicit name override change
  /// and/or changed slot color inside ONE transaction. No Goal row, target,
  /// indicator, outbox, or notification write; no raw type rename.
  ///
  /// Re-checks live eligibility at Save: the expected Goal must still be the
  /// raw-active occupant of [expectedSlotIndex] with unchanged identity
  /// fields, or a [StateError] is thrown and nothing is written (archive and
  /// replacement races are rejected).
  ///
  /// [originalValues] are the values the caller last observed; changed
  /// inputs are rejected with [StateError] instead of overwriting.
  Future<LiveGoalPresentationResult> saveLiveGoalPresentation({
    required String profileId,
    required int expectedSlotIndex,
    required String expectedGoalId,
    required String expectedEventTypeId,
    required String expectedStableKey,
    required LiveGoalPresentationOriginals originalValues,
    required LiveGoalPresentationPatch patch,
  });
}

/// Caller-observed originals for [EventTypeRepository.saveLiveGoalPresentation].
final class LiveGoalPresentationOriginals {
  const LiveGoalPresentationOriginals({
    this.observedNameOverride,
    this.observedColor,
  });

  /// Name override the caller last observed (null = AUTO observed).
  final GoalEventTypeNameOverride? observedNameOverride;

  /// Effective slot color pair the caller last observed (saved preference
  /// or locked default). Used to reject concurrent color changes.
  final EventColorPreference? observedColor;
}
