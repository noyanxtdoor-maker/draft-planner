import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';

/// Vertical-axis Timeline: 66 dp date/axis zone, 2 dp axis, 8-9 dp dots,
/// cards with 16 dp inner padding and 12 dp gaps.  Upcoming is future-facing;
/// only past/reportable records belong to History.  Cards open the exact
/// Event/occurrence detail.
final class ContactTimelineView extends StatelessWidget {
  const ContactTimelineView({required this.timeline, super.key});

  final ContactTimeline timeline;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.history,
                size: 48,
                color: AppTheme.outlineOf(context),
              ),
              const SizedBox(height: 12),
              const Text(
                'No event history yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Events that include this Contact will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondaryTextOf(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final children = <Widget>[];
    if (timeline.upcoming.isNotEmpty) {
      children.add(const _SectionLabel('UPCOMING'));
      for (final entry in timeline.upcoming) {
        children.add(_TimelineCard(entry: entry, isUpcoming: true));
      }
    }
    if (timeline.history.isNotEmpty) {
      children.add(const _SectionLabel('HISTORY'));
      int? currentYear;
      for (final entry in timeline.history) {
        if (currentYear != entry.date.year) {
          currentYear = entry.date.year;
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Text(
                '${entry.date.year}',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }
        children.add(_TimelineCard(entry: entry, isUpcoming: false));
      }
    }
    return ListView(
      key: const Key('contact-timeline-list'),
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppTheme.secondaryTextOf(context),
        ),
      ),
    );
  }
}

final class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry, required this.isUpcoming});

  final ContactTimelineEntry entry;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final isRecordCreated = entry.kind == ContactTimelineKind.recordCreated;
    final dotColor = isUpcoming
        ? AppTheme.rose
        : isRecordCreated
        ? AppTheme.secondaryTextOf(context)
        : AppTheme.eventAccent;

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceVariantOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 18,
              height: 22 / 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              entry.subtitle!,
              style: TextStyle(
                color: AppTheme.secondaryTextOf(context),
                fontSize: 15,
                height: 20 / 15,
              ),
            ),
          ],
          if (entry.statusLabel != null) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Icon(
                  _statusIcon(entry.status),
                  size: 16,
                  color: _statusColor(context, entry),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.statusLabel!,
                  style: TextStyle(
                    color: _statusColor(context, entry),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final dateBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          _monthLabel(entry.date.month),
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.secondaryTextOf(context),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          '${entry.date.day}',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 26,
            height: 30 / 26,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final row = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      // IntrinsicHeight bounds the axis column so its connector line can
      // flex to the card's height instead of hitting unbounded constraints
      // inside a scrolling view.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(width: 16),
            SizedBox(
              width: 50,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: dateBlock,
              ),
            ),
            SizedBox(
              width: 16,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 19),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dotColor,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppTheme.surfaceVariantOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: card,
              ),
            ),
          ],
        ),
      ),
    );

    if (!entry.isTappable) {
      return row;
    }
    return GestureDetector(
      key: Key('timeline-card-${entry.occurrenceId}'),
      onTap: () => context.push(
        RoutePaths.calendarEventDetail(entry.eventId!, entry.originalDate!),
      ),
      child: row,
    );
  }

  static IconData _statusIcon(CalendarEventStatus? status) {
    return switch (status) {
      CalendarEventStatus.completedHappened => Icons.check_circle_outline,
      CalendarEventStatus.partiallyCompleted => Icons.phone_missed_outlined,
      CalendarEventStatus.didNotHappen => Icons.radio_button_unchecked,
      CalendarEventStatus.cancelled => Icons.cancel_outlined,
      CalendarEventStatus.rescheduled => Icons.update,
      _ => Icons.schedule,
    };
  }

  static Color _statusColor(BuildContext context, ContactTimelineEntry entry) {
    final status = entry.status;
    if (status == CalendarEventStatus.completedHappened) {
      return AppTheme.eventAccent;
    }
    if (status == CalendarEventStatus.cancelled) {
      return AppTheme.secondaryTextOf(context);
    }
    if (entry.isUpcoming) {
      return AppTheme.rose;
    }
    return AppTheme.warningOf(context);
  }

  static String _monthLabel(int month) {
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return months[month - 1];
  }
}

/// Common Events panel: collapsed 56 dp bordered row; expanded shows repeated
/// completed patterns (at least 2 qualifying occurrences) with weekday, time,
/// and count.  Derived from happened/completed history only; no inference.
final class CommonEventsPanel extends StatefulWidget {
  const CommonEventsPanel({required this.patterns, super.key});

  final List<CommonEventPattern> patterns;

  @override
  State<CommonEventsPanel> createState() => _CommonEventsPanelState();
}

final class _CommonEventsPanelState extends State<CommonEventsPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final patterns = widget.patterns;
    return Container(
      key: const Key('common-events-panel'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceVariantOf(context)),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: patterns.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_repeat,
                    size: 24,
                    color: AppTheme.secondaryTextOf(context),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Common Events',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (patterns.isNotEmpty)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 24,
                      color: AppTheme.secondaryTextOf(context),
                    ),
                ],
              ),
            ),
          ),
          if (_expanded)
            for (final pattern in patterns)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        pattern.title,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      '${pattern.weekdayLabel}  ${pattern.startMinuteLabel}',
                      style: TextStyle(
                        color: AppTheme.secondaryTextOf(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${pattern.count}',
                      style: const TextStyle(
                        color: AppTheme.rose,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
