import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';

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
}
