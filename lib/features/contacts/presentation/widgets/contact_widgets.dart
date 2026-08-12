import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

Color colorFromValue(ColorValue value) {
  return value.isNeutral ? const Color(0xFF9CA0A6) : Color(value.value);
}

/// Neutral circle with initials; the ring/background uses the primary group
/// color when present.
final class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    required this.summary,
    this.size = 40,
    this.showRing = true,
    super.key,
  });

  final ContactSummary summary;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final accent = colorFromValue(summary.colorValue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1C1E21),
        border: showRing
            ? Border.all(color: accent, width: 1.5)
            : Border.all(color: const Color(0xFF2A2D31), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        summary.contact.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 20 dp primary-group color indicator (neutral gray when no group).
final class ContactGroupDot extends StatelessWidget {
  const ContactGroupDot({required this.summary, super.key});

  final ContactSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorFromValue(summary.colorValue),
      ),
    );
  }
}

/// Standard list row: favorite star + group dot + name + subtitle + one
/// contextual line (Next Event / Last Event).  Minimum 72 dp, up to 3 lines.
final class ContactListRow extends StatelessWidget {
  const ContactListRow({
    required this.summary,
    this.onTap,
    this.trailing,
    this.leading,
    this.showContextLine = true,
    this.showTrailing = true,
    super.key,
  });

  final ContactSummary summary;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool showContextLine;
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = summary.subtitle;
    final contextLine = _contextLine(summary);
    final hasSubtitle = subtitle.isNotEmpty;
    final hasContext = showContextLine && (contextLine?.isNotEmpty ?? false);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 12),
              ],
              if (summary.contact.isFavorite) ...<Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AppTheme.rose,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ContactGroupDot(summary: summary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      summary.contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 18,
                        height: 22 / 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasSubtitle) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF9CA0A6),
                          fontSize: 14,
                          height: 18 / 14,
                        ),
                      ),
                    ],
                    if (hasContext) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        contextLine ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.rose,
                          fontSize: 13,
                          height: 17 / 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showTrailing && trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? _contextLine(ContactSummary summary) {
    final context = summary.context;
    final next = context.nextEventDate;
    if (context.nextEventTitle != null && next != null) {
      return 'Next Event: ${friendlyContactDate(next)}';
    }
    final last = context.lastEventDate;
    if (last != null) {
      return 'Last Event: ${friendlyContactDate(last)}';
    }
    return null;
  }
}

/// "Today", "Tomorrow", "Yesterday", "Aug 3", "Aug 3, 2025".
String friendlyContactDate(PlannerDate date) {
  final now = DateTime.now();
  final today = PlannerDate.fromDateTime(now);
  if (date == today) {
    return 'Today';
  }
  if (date == today.addDays(1)) {
    return 'Tomorrow';
  }
  if (date == today.addDays(-1)) {
    return 'Yesterday';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final label = '${months[date.month - 1]} ${date.day}';
  return date.year == today.year ? label : '$label, ${date.year}';
}
