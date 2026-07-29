import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class CalendarEventDetailScreen extends ConsumerStatefulWidget {
  const CalendarEventDetailScreen({
    required this.eventId,
    required this.originalDate,
    super.key,
  });

  final String eventId;
  final PlannerDate originalDate;

  @override
  ConsumerState<CalendarEventDetailScreen> createState() =>
      _CalendarEventDetailScreenState();
}

final class _CalendarEventDetailScreenState
    extends ConsumerState<CalendarEventDetailScreen> {
  late Future<CalendarEventOccurrence?> _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = ref
        .read(calendarEventControllerProvider.notifier)
        .readOccurrence(
          eventId: widget.eventId,
          originalDate: widget.originalDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(calendarEventControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar Event')),
      body: FutureBuilder<CalendarEventOccurrence?>(
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
              Text(
                occurrence.title,
                key: const Key('event-detail-title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text(calendarEventStatusLabel(occurrence.status)),
                  ),
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
                ],
              ),
              const SizedBox(height: 18),
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: occurrence.timing == CalendarEventTiming.allDay
                    ? '${occurrence.displayDate.iso8601} · All day'
                    : occurrence.displayDate.iso8601,
              ),
              if (occurrence.timing == CalendarEventTiming.timed)
                _DetailRow(
                  icon: Icons.schedule,
                  label:
                      '${_time(occurrence.startDisplay)} – '
                      '${_time(occurrence.endDisplay)}',
                ),
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
              const SizedBox(height: 22),
              FilledButton.tonalIcon(
                key: const Key('manage-event-task-links'),
                onPressed: () => _manageLinks(occurrence),
                icon: const Icon(Icons.link),
                label: const Text('Link or manage Tasks'),
              ),
              const SizedBox(height: 8),
              if (occurrence.status ==
                  CalendarEventStatus.scheduled) ...<Widget>[
                FilledButton.icon(
                  key: const Key('edit-event-button'),
                  onPressed: () =>
                      _openForm(occurrence: occurrence, reschedule: false),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('reschedule-event-button'),
                  onPressed: () =>
                      _openForm(occurrence: occurrence, reschedule: true),
                  icon: const Icon(Icons.event_repeat_outlined),
                  label: const Text('Reschedule'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('cancel-event-button'),
                  onPressed: () => _cancel(occurrence),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Cancel'),
                ),
              ],
              if (occurrence.requiresReport &&
                  occurrence.status ==
                      CalendarEventStatus.scheduled) ...<Widget>[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('open-event-report-button'),
                  onPressed: () => _openReport(occurrence),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Open Report'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('event-activity-history-button'),
                onPressed: () => context.push(RoutePaths.activityHistory),
                icon: const Icon(Icons.history),
                label: const Text('View Activity History'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm({
    required CalendarEventOccurrence occurrence,
    required bool reschedule,
  }) async {
    final scope = await _selectScope(occurrence);
    if (!mounted || scope == null) {
      return;
    }
    final path = reschedule
        ? RoutePaths.calendarEventReschedule(
            occurrence.eventId,
            occurrence.originalDate,
            scope,
          )
        : RoutePaths.calendarEventEdit(
            occurrence.eventId,
            occurrence.originalDate,
            scope,
          );
    final changed = await context.push<bool>(path);
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _manageLinks(CalendarEventOccurrence occurrence) async {
    await context.push<bool>(
      '${RoutePaths.calendarEventDetail(occurrence.eventId, occurrence.originalDate)}/link-task',
    );
    if (mounted) {
      setState(_reload);
    }
  }

  Future<void> _openReport(CalendarEventOccurrence occurrence) async {
    final changed = await context.push<bool>(
      RoutePaths.calendarEventReport(
        occurrence.eventId,
        occurrence.originalDate,
      ),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _cancel(CalendarEventOccurrence occurrence) async {
    final scope = await _selectScope(occurrence);
    if (!mounted || scope == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Calendar Event?'),
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
            key: const Key('confirm-cancel-event'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel Event'),
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
