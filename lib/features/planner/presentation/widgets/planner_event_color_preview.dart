import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_content.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// A deterministic Settings preview that reuses the same content and color
/// policy as the production Planner Event block.
final class PlannerEventColorPreview extends StatelessWidget {
  const PlannerEventColorPreview({
    required this.eventType,
    required this.preference,
    super.key,
  });

  final EventType eventType;
  final EventColorPreference preference;

  @override
  Widget build(BuildContext context) {
    final accent = Color(preference.accentArgb);
    final surface = Color(preference.surfaceArgb);
    final sample = PlannerCalendarItem(
      id: 'event-color-preview-${eventType.stableKey}',
      title: eventType.label,
      date: PlannerDate.parse('2026-08-02'),
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: DateTime(2026, 8, 2, 10),
      endLocal: DateTime(2026, 8, 2, 11),
      isRecurring: true,
      activityTypeId: eventType.id,
      activityTypeLabel: eventType.label,
      activityTypeColorValue: eventType.colorValue,
    );
    final content = PlannerEventBlockContent.forHeight(64, interactive: false);
    return Semantics(
      label: '${eventType.label} Event preview',
      child: SizedBox(
        height: 64,
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              PlannerEventBlockLayoutPolicy.eventBorderRadius,
            ),
            side: BorderSide(
              color: PlannerEventBlockColorPolicy.borderColor(accent),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accent,
                  width: PlannerEventBlockLayoutPolicy.eventAccentWidth,
                ),
              ),
            ),
            child: PlannerEventBlockContentView(
              event: sample,
              use24HourTime: false,
              displayStartMinute: 10 * 60,
              displayEndMinute: 11 * 60,
              awaitingReport: false,
              content: content,
              accentColor: accent,
              surfaceColor: surface,
            ),
          ),
        ),
      ),
    );
  }
}
