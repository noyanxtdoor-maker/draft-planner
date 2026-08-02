import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/anchored_top_bar_popup.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_top_bar_icons.dart';

enum _CalendarEventDetailAction { duplicate, delete }

final class CalendarEventDetailScreen extends ConsumerStatefulWidget {
  const CalendarEventDetailScreen({
    required this.eventId,
    required this.originalDate,
    this.sheetPresentation = false,
    super.key,
  });

  final String eventId;
  final PlannerDate originalDate;
  final bool sheetPresentation;

  @override
  ConsumerState<CalendarEventDetailScreen> createState() =>
      _CalendarEventDetailScreenState();
}

final class _CalendarEventDetailScreenState
    extends ConsumerState<CalendarEventDetailScreen> {
  late Future<CalendarEventOccurrence?> _load;
  String _detailHeading = 'Calendar Event';
  final GlobalKey _statusControlAnchorKey = GlobalKey();
  final GlobalKey _overflowAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final future = ref
        .read(calendarEventControllerProvider.notifier)
        .readOccurrence(
          eventId: widget.eventId,
          originalDate: widget.originalDate,
        );
    _load = future;
    unawaited(
      future.then((occurrence) {
        if (!mounted || occurrence == null) {
          return;
        }
        final nextHeading =
            occurrence.activityTypeLabel?.trim().isNotEmpty == true
            ? occurrence.activityTypeLabel!
            : occurrence.displayTitle;
        if (nextHeading.isNotEmpty && nextHeading != _detailHeading) {
          setState(() => _detailHeading = nextHeading);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(calendarEventControllerProvider);
    final content = FutureBuilder<CalendarEventOccurrence?>(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final occurrence = snapshot.data;
        if (occurrence == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This Calendar Event occurrence is no longer available. '
                'No local record was changed.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final awaitingReport = occurrence.isAwaitingReport(
          nowUtc: DateTime.now().toUtc(),
          displayToday: PlannerDate.fromDateTime(DateTime.now()),
        );
        final isContactEvent = _isContactEvent(occurrence.activityTypeLabel);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            if (message != null) ...<Widget>[
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(message),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _DetailField(
              key: const Key('event-detail-title'),
              icon: Icons.title_outlined,
              label: 'Title',
              value: occurrence.displayTitle,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (occurrence.activityTypeLabel != null)
                  Chip(
                    key: const Key('event-detail-event-type'),
                    avatar: Icon(
                      Icons.category_outlined,
                      size: 18,
                      color: Color(
                        occurrence.activityTypeColorValue ?? 0xFFE91E63,
                      ),
                    ),
                    label: Text(occurrence.activityTypeLabel!),
                  ),
                if (occurrence.isRecurring)
                  const Chip(
                    avatar: Icon(Icons.repeat, size: 18),
                    label: Text('Recurring'),
                  ),
                if (occurrence.requiresReport)
                  const Chip(label: Text('Report required')),
                if (occurrence.isBackupAppointment)
                  const Chip(
                    key: Key('event-detail-backup-badge'),
                    avatar: Icon(Icons.layers_outlined, size: 18),
                    label: Text('Backup Appointment'),
                  ),
                if (awaitingReport)
                  const Chip(
                    key: Key('event-detail-awaiting-report'),
                    avatar: Icon(Icons.assignment_late_outlined, size: 18),
                    label: Text('Awaiting Report'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: _statusControlAnchorKey,
              child: ListTile(
                key: const Key('event-status-control'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _statusIcon(occurrence.status),
                  color: _statusColor(occurrence.status),
                ),
                title: const Text('Current Status'),
                subtitle: Text(
                  calendarEventOutcomeLabel(
                    status: occurrence.status,
                    isContactEvent: isContactEvent,
                  ),
                ),
                trailing: const Icon(Icons.expand_more),
                onTap: () => _showStatusMenu(occurrence),
              ),
            ),
            const SizedBox(height: 18),
            _DetailField(
              icon: Icons.calendar_today_outlined,
              label: 'Date',
              value: occurrence.displayDate.iso8601,
            ),
            if (occurrence.timing == CalendarEventTiming.timed)
              _DetailField(
                icon: Icons.schedule,
                label: 'Time',
                value:
                    '${_time(occurrence.startDisplay)} – '
                    '${_time(occurrence.endDisplay)}',
              ),
            if (occurrence.activityTypeLabel != null)
              _DetailField(
                icon: Icons.category_outlined,
                label: isContactEvent ? 'Contact Type' : 'Event Type',
                value: occurrence.activityTypeLabel!,
              ),
            if (occurrence.timing == CalendarEventTiming.allDay)
              const _DetailRow(icon: Icons.today_outlined, label: 'All day'),
            if (occurrence.timeZoneId != null)
              _DetailRow(
                icon: Icons.public,
                label: occurrence.timeZoneId == occurrence.displayTimeZoneId
                    ? 'Original time zone: ${occurrence.timeZoneId}'
                    : 'Original: ${occurrence.timeZoneId} · Shown in '
                          '${occurrence.displayTimeZoneId}',
              ),
            if (occurrence.locationText != null)
              _DetailRow(
                icon: Icons.place_outlined,
                label: occurrence.locationText!,
              ),
            if (occurrence.notes != null)
              _DetailRow(icon: Icons.notes, label: occurrence.notes!),
            if (occurrence.createdAtUtc != null)
              _DetailField(
                icon: Icons.add_circle_outline,
                label: 'Created',
                value: _metadataTime(occurrence.createdAtUtc!),
              ),
            if (occurrence.updatedAtUtc != null)
              _DetailField(
                icon: Icons.update_outlined,
                label: 'Updated',
                value: _metadataTime(occurrence.updatedAtUtc!),
              ),
            if (occurrence.contributionRuleKey != null)
              const _DetailField(
                icon: Icons.track_changes_outlined,
                label: 'Weekly Life Indicator',
                value: 'Linked for completion reporting',
              ),
            if (occurrence.linkedTaskIds.isNotEmpty)
              _DetailRow(
                icon: Icons.link,
                label:
                    '${occurrence.linkedTaskIds.length} linked Task(s); '
                    'statuses remain independent',
              ),
            if (occurrence.replacementEventId != null)
              _DetailRow(
                icon: Icons.redo,
                label: 'Replacement Event: ${occurrence.replacementEventId}',
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
    if (!widget.sheetPresentation) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_detailHeading),
          actions: <Widget>[
            PlannerTopBarIconButton(
              key: const Key('event-detail-edit-icon'),
              tooltip: 'Edit Event',
              onPressed: _openTopEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            KeyedSubtree(
              key: _overflowAnchorKey,
              child: PlannerTopBarIconButton(
                key: const Key('event-detail-overflow-icon'),
                tooltip: 'Event actions',
                onPressed: _openTopOverflow,
                icon: const Icon(Icons.more_vert),
              ),
            ),
          ],
        ),
        body: content,
      );
    }
    return Material(
      key: const Key('calendar-event-existing-detail-sheet'),
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Close Calendar Event details',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    _detailHeading,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PlannerTopBarIconButton(
                  key: const Key('event-detail-sheet-edit-icon'),
                  tooltip: 'Edit Event',
                  onPressed: _openTopEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                KeyedSubtree(
                  key: _overflowAnchorKey,
                  child: PlannerTopBarIconButton(
                    key: const Key('event-detail-sheet-overflow-icon'),
                    tooltip: 'Event actions',
                    onPressed: _openTopOverflow,
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  Future<CalendarEventOccurrence?> _readCurrentOccurrence() {
    return ref
        .read(calendarEventControllerProvider.notifier)
        .readOccurrence(
          eventId: widget.eventId,
          originalDate: widget.originalDate,
        );
  }

  Future<void> _openTopEdit() async {
    final occurrence = await _readCurrentOccurrence();
    if (!mounted || occurrence == null) {
      return;
    }
    await _openForm(occurrence: occurrence);
  }

  Future<void> _openTopOverflow() async {
    final occurrence = await _readCurrentOccurrence();
    if (!mounted || occurrence == null) {
      return;
    }
    _CalendarEventDetailAction? action;
    await showAnchoredTopBarPopup(
      context: context,
      triggerKey: _overflowAnchorKey,
      width: 228,
      maxHeight: 220,
      builder: (popupContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _DetailOverflowItem(
            key: const Key('event-overflow-duplicate'),
            icon: Icons.copy_outlined,
            label: 'Duplicate',
            onTap: () {
              action = _CalendarEventDetailAction.duplicate;
              anchoredTopBarPopupController.dismiss();
            },
          ),
          _DetailOverflowItem(
            key: const Key('event-overflow-delete'),
            icon: Icons.delete_outline,
            label: 'Delete',
            destructive: true,
            onTap: () {
              action = _CalendarEventDetailAction.delete;
              anchoredTopBarPopupController.dismiss();
            },
          ),
        ],
      ),
    );
    final selectedAction = action;
    if (!mounted || selectedAction == null) {
      return;
    }
    switch (selectedAction) {
      case _CalendarEventDetailAction.duplicate:
        await _duplicate(occurrence);
      case _CalendarEventDetailAction.delete:
        await _cancel(occurrence, delete: true);
    }
  }

  Future<void> _showStatusMenu(CalendarEventOccurrence occurrence) async {
    final anchorContext = _statusControlAnchorKey.currentContext;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchor = anchorContext?.findRenderObject() as RenderBox?;
    if (anchor == null) {
      return;
    }
    final topLeft = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final selected = await showMenu<CalendarEventStatus>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      color: AppTheme.surface,
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        for (final status in <CalendarEventStatus>[
          CalendarEventStatus.scheduled,
          CalendarEventStatus.completedHappened,
          CalendarEventStatus.partiallyCompleted,
          CalendarEventStatus.didNotHappen,
        ])
          PopupMenuItem<CalendarEventStatus>(
            key: Key('event-status-option-${status.name}'),
            value: status,
            height: 56,
            child: Row(
              children: <Widget>[
                Icon(_statusIcon(status), color: _statusColor(status)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    calendarEventOutcomeLabel(
                      status: status,
                      isContactEvent: _isContactEvent(
                        occurrence.activityTypeLabel,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (!mounted || selected == null) {
      return;
    }
    if (selected == CalendarEventStatus.scheduled) {
      return;
    }
    final outcome = switch (selected) {
      CalendarEventStatus.completedHappened => OutcomeKind.completedHappened,
      CalendarEventStatus.partiallyCompleted => OutcomeKind.partiallyCompleted,
      CalendarEventStatus.didNotHappen => OutcomeKind.didNotHappen,
      _ => null,
    };
    if (outcome == null) {
      return;
    }
    final reporting = ref.read(outcomeReportingControllerProvider.notifier);
    final source = await reporting.readEventSource(
      eventId: occurrence.eventId,
      originalDate: occurrence.originalDate,
    );
    if (!mounted || source == null) {
      return;
    }
    final currentReport = (await reporting.readHistory())
        .where(
          (report) =>
              report.status == OutcomeReportStatus.submitted &&
              report.source.slotKey == source.slotKey,
        )
        .firstOrNull;
    if (!mounted) {
      return;
    }
    if (currentReport != null) {
      final changed = await context.push<bool>(
        RoutePaths.outcomeReportCorrection(currentReport.id),
      );
      if (changed == true && mounted) {
        setState(_reload);
      }
      return;
    }
    await _openReport(occurrence, initialOutcome: outcome);
  }

  Future<void> _duplicate(CalendarEventOccurrence occurrence) async {
    final saved = await ref
        .read(calendarEventControllerProvider.notifier)
        .duplicateEvent(
          eventId: occurrence.eventId,
          originalDate: occurrence.originalDate,
          duplicateId: ref.read(plannerIdentifierSourceProvider).nextUuid(),
          operationId: ref.read(plannerIdentifierSourceProvider).nextUuid(),
        );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calendar Event duplicated.')),
      );
    }
  }

  Future<void> _openForm({required CalendarEventOccurrence occurrence}) async {
    final scope = await _selectScope(occurrence);
    if (!mounted || scope == null) {
      return;
    }
    final path = RoutePaths.calendarEventEdit(
      occurrence.eventId,
      occurrence.originalDate,
      scope,
    );
    final changed = await context.push<bool>(path);
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _openReport(
    CalendarEventOccurrence occurrence, {
    OutcomeKind? initialOutcome,
  }) async {
    final changed = await context.push<bool>(
      RoutePaths.calendarEventReport(
        occurrence.eventId,
        occurrence.originalDate,
        initialOutcome: initialOutcome,
      ),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _cancel(
    CalendarEventOccurrence occurrence, {
    bool delete = false,
  }) async {
    final scope = await _selectScope(occurrence);
    if (!mounted || scope == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          delete ? 'Delete Calendar Event?' : 'Cancel Calendar Event?',
        ),
        content: Text(
          'Scope: ${calendarEventScopeLabel(scope)}. Historical records '
          'and reports will be preserved.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            key: Key(delete ? 'confirm-delete-event' : 'confirm-cancel-event'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(delete ? 'Delete Event' : 'Cancel Event'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final operationId = ref.read(plannerIdentifierSourceProvider).nextUuid();
    final success = await ref
        .read(calendarEventControllerProvider.notifier)
        .cancelEvent(
          eventId: occurrence.eventId,
          originalDate: occurrence.originalDate,
          scope: scope,
          operationId: operationId,
        );
    if (success && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(_reload);
    }
  }

  Future<CalendarEventEditScope?> _selectScope(
    CalendarEventOccurrence occurrence,
  ) {
    if (!occurrence.isRecurring) {
      return Future<CalendarEventEditScope?>.value(
        CalendarEventEditScope.occurrence,
      );
    }
    return showModalBottomSheet<CalendarEventEditScope>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Choose recurrence scope',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              for (final scope in CalendarEventEditScope.values)
                ListTile(
                  key: Key('event-scope-${scope.name}'),
                  title: Text(calendarEventScopeLabel(scope)),
                  subtitle: Text(_scopeHelp(scope)),
                  onTap: () => Navigator.of(sheetContext).pop(scope),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _scopeHelp(CalendarEventEditScope scope) {
    return switch (scope) {
      CalendarEventEditScope.occurrence =>
        'Change only this independently reportable occurrence',
      CalendarEventEditScope.thisAndFuture =>
        'Preserve earlier occurrences and start a stable continuation',
      CalendarEventEditScope.series =>
        'Apply to the series while preserving reported history',
    };
  }

  static String _time(DateTime? value) {
    if (value == null) {
      return 'Time not set';
    }
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    return '$hour:${value.minute.toString().padLeft(2, '0')} '
        '${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _metadataTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${_time(local)}';
  }

  static bool _isContactEvent(String? label) {
    final normalized = label?.trim().toLowerCase();
    return normalized != null && normalized.contains('contact');
  }

  static IconData _statusIcon(CalendarEventStatus status) {
    return switch (status) {
      CalendarEventStatus.scheduled => Icons.error_outline,
      CalendarEventStatus.completedHappened => Icons.check_circle_outline,
      CalendarEventStatus.partiallyCompleted => Icons.phone_callback_outlined,
      CalendarEventStatus.didNotHappen => Icons.remove_circle_outline,
      _ => Icons.flag_outlined,
    };
  }

  static Color _statusColor(CalendarEventStatus status) {
    return switch (status) {
      CalendarEventStatus.scheduled => Colors.amber,
      CalendarEventStatus.completedHappened => Colors.lightGreen,
      CalendarEventStatus.partiallyCompleted => Colors.pinkAccent,
      CalendarEventStatus.didNotHappen => Colors.white70,
      _ => Colors.white70,
    };
  }
}

Future<T?> showCalendarEventDetailSheet<T>({
  required BuildContext context,
  required String eventId,
  required PlannerDate originalDate,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.92,
      child: CalendarEventDetailScreen(
        eventId: eventId,
        originalDate: originalDate,
        sheetPresentation: true,
      ),
    ),
  );
}

final class _DetailOverflowItem extends StatelessWidget {
  const _DetailOverflowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

final class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.white60),
                ),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
