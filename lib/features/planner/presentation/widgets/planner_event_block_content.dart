import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

String formatPlannerEventMinute(int minute, bool use24HourTime) {
  final hour = minute ~/ 60;
  final normalizedMinute = minute % 60;
  if (use24HourTime) {
    return '${hour.toString().padLeft(2, '0')}:${normalizedMinute.toString().padLeft(2, '0')}';
  }
  final displayHour = hour == 0
      ? 12
      : hour > 12
      ? hour - 12
      : hour;
  return '$displayHour:${normalizedMinute.toString().padLeft(2, '0')} '
      '${hour >= 12 ? 'PM' : 'AM'}';
}

String formatPlannerEventRange(
  int startMinute,
  int endMinute,
  bool use24HourTime,
) {
  return '${formatPlannerEventMinute(startMinute, use24HourTime)} - '
      '${formatPlannerEventMinute(endMinute, use24HourTime)}';
}

/// Shared visible content for centered and read-only adjacent Event blocks.
///
/// The caller supplies the density calculated from the exact visible block
/// height. This keeps the centered interactive card and the pager preview on
/// the same compact-content policy without giving either widget a visual
/// minimum height that would falsify Event duration.
final class PlannerEventBlockContentView extends StatelessWidget {
  const PlannerEventBlockContentView({
    super.key,
    required this.event,
    required this.use24HourTime,
    required this.displayStartMinute,
    required this.displayEndMinute,
    required this.awaitingReport,
    required this.content,
    this.accentColor,
    this.surfaceColor,
    this.titleKey,
    this.timeKey,
    this.recurrenceKey,
    this.statusKey,
  });

  final PlannerCalendarItem event;
  final bool use24HourTime;
  final int displayStartMinute;
  final int displayEndMinute;
  final bool awaitingReport;
  final PlannerEventBlockContent content;
  final Color? accentColor;
  final Color? surfaceColor;
  final Key? titleKey;
  final Key? timeKey;
  final Key? recurrenceKey;
  final Key? statusKey;

  @override
  Widget build(BuildContext context) {
    final density = content.density;
    final base = Color(event.activityTypeColorValue ?? 0xFFE91E63);
    final accent = accentColor ?? base;
    final surface =
        surfaceColor ?? PlannerEventBlockColorPolicy.surfaceColor(base);
    final textColor = PlannerEventBlockColorPolicy.textColor(surface);
    final titleStyle = TextStyle(
      color: textColor,
      fontWeight: FontWeight.w500,
      fontSize: PlannerEventBlockLayoutPolicy.titleFontSize(density),
      height: density == Density.veryShort ? 1.0 : 1.1,
    );
    final timeStyle = TextStyle(
      color: textColor.withValues(alpha: 0.92),
      fontWeight: FontWeight.w400,
      fontSize: PlannerEventBlockLayoutPolicy.timeFontSize(density),
      height: 1.1,
    );
    final timeText = formatPlannerEventRange(
      displayStartMinute,
      displayEndMinute,
      use24HourTime,
    );
    final inlineText = '${event.displayTitle}  $timeText';
    final verticalPadding = density == Density.veryShort ? 0.0 : 4.0;
    final rightPadding = event.isRecurring
        ? PlannerEventBlockLayoutPolicy.recurringContentRightPadding
        : PlannerEventBlockLayoutPolicy.contentHorizontalPadding;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              PlannerEventBlockLayoutPolicy.contentHorizontalPadding,
              verticalPadding,
              rightPadding,
              verticalPadding,
            ),
            child: Column(
              key: const Key('planner-event-block-content'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  content.showTimeInline ? inlineText : event.displayTitle,
                  key: titleKey,
                  style: titleStyle,
                  maxLines: content.titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                if (content.showTime && !content.showTimeInline)
                  Padding(
                    padding: EdgeInsets.only(
                      top: density == Density.tall ? 2 : 1,
                    ),
                    child: Text(
                      timeText,
                      key: timeKey,
                      style: timeStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                if (content.showStatusIcons)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _PlannerEventStatusRow(
                      key: statusKey,
                      event: event,
                      textColor: textColor,
                      awaitingReport: awaitingReport,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (event.isRecurring)
          Positioned(
            key: recurrenceKey,
            top: density == Density.veryShort ? 1 : 3,
            right: PlannerEventBlockLayoutPolicy.recurrenceRightInset,
            child: Icon(
              Icons.repeat,
              size: PlannerEventBlockLayoutPolicy.recurrenceIconSizeFor(
                density,
              ),
              color: accent.withValues(alpha: 0.92),
            ),
          ),
      ],
    );
  }
}

final class _PlannerEventStatusRow extends StatelessWidget {
  const _PlannerEventStatusRow({
    super.key,
    required this.event,
    required this.textColor,
    required this.awaitingReport,
  });

  final PlannerCalendarItem event;
  final Color textColor;
  final bool awaitingReport;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final String label;
    if (awaitingReport) {
      icon = Icons.assignment_late_outlined;
      label = 'Unreported';
    } else if (event.hasOutcomeReport) {
      icon = Icons.check_circle_outline;
      label = 'Completed';
    } else if (event.isBackupAppointment) {
      icon = Icons.layers_outlined;
      label = 'Backup';
    } else if (event.linkedTaskIds.isNotEmpty) {
      icon = Icons.task_alt_outlined;
      label = '${event.linkedTaskIds.length} linked';
    } else {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 11, color: textColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
