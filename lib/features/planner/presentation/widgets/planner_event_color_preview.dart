import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
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
    // Settings identity preview: the stored pair is rendered as-is on its
    // dark-style surface, so the text stays white regardless of the current
    // theme brightness (matches the pre-correction preview).
    final textColor = PlannerEventBlockColorPolicy.textColor(
      surface,
      Brightness.dark,
    );
    final timeText = formatPlannerEventRange(600, 660, false);
    return Semantics(
      label: '${eventType.label} Event preview',
      child: SizedBox(
        height: 40,
        child: Material(
          color: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
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
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 3, 28, 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          eventType.label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                        Text(
                          timeText,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.92),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 11,
                  right: 8,
                  child: Icon(
                    Icons.repeat,
                    size: 18,
                    color: accent.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
