import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// Resolves the current presentation pair for a Planner item without changing
/// the item or rereading the Event table. The map is supplied by the existing
/// Event Type controller and changes atomically when a settings write lands.
abstract final class PlannerEventColorResolver {
  static EventColorPreference preferenceForType(
    EventType type,
    Map<String, EventColorPreference> preferencesByStableKey,
  ) {
    return preferencesByStableKey[type.stableKey] ??
        PlannerEventColorDefaults.forEventType(type);
  }

  static Color accentColorForType(
    EventType type,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    return Color(
      preferencesByTypeId[type.id]?.accentArgb ??
          PlannerEventColorDefaults.forEventType(type).accentArgb,
    );
  }

  static Color surfaceColorForType(
    EventType type,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    return Color(
      preferencesByTypeId[type.id]?.surfaceArgb ??
          PlannerEventColorDefaults.forEventType(type).surfaceArgb,
    );
  }

  static EventColorPreference? preferenceFor(
    PlannerCalendarItem event,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    final typeId = event.activityTypeId;
    return typeId == null ? null : preferencesByTypeId[typeId];
  }

  static Color accentColor(
    PlannerCalendarItem event,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    final preference = preferenceFor(event, preferencesByTypeId);
    return Color(
      preference?.accentArgb ?? event.activityTypeColorValue ?? 0xFFE91E63,
    );
  }

  static Color surfaceColor(
    PlannerCalendarItem event,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    final preference = preferenceFor(event, preferencesByTypeId);
    if (preference != null) {
      return Color(preference.surfaceArgb);
    }
    return PlannerEventBlockColorPolicy.surfaceColor(
      Color(event.activityTypeColorValue ?? 0xFFE91E63),
    );
  }
}
