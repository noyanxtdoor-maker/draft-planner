import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/outcome_reporting_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/outcome_reporting.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/anchored_top_bar_popup.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_report_status.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_report_status_icons.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_top_bar_icons.dart';
import 'package:rmplanner/features/planner/presentation/widgets/repeating_event_scope_choices.dart';

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
  final GlobalKey _overflowAnchorKey = GlobalKey();
  bool _statusSaving = false;

  /// Draft status staged in the preview but not yet persisted. Tapping a
  /// different status enters draft mode (no write); the top-right check icon
  /// commits the draft through the canonical reporting engine; closing or
  /// Android Back cancels the draft first.
  CalendarEventStatus? _draftStatus;

  bool get _draftActive => _draftStatus != null;

  /// Most recently loaded occurrence, kept so the app-bar check action can
  /// commit the draft without re-reading the occurrence.
  CalendarEventOccurrence? _latestOccurrence;

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
        _latestOccurrence = occurrence;
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
        final nowUtc = DateTime.now().toUtc();
        final displayToday = PlannerDate.fromDateTime(DateTime.now());
        final isFuture = occurrence.timing == CalendarEventTiming.allDay
            ? occurrence.displayDate.compareTo(displayToday) > 0
            : occurrence.startUtc?.isAfter(nowUtc) ?? false;
        final showStatus = occurrence.requiresReport && !isFuture;
        final eventTypeLabel = occurrence.activityTypeLabel;
        final isContactEvent = _isContactEvent(
          occurrence.activityTypeStableKey,
          eventTypeLabel,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            // The compact four-state status row sits immediately below the
            // app bar: the current status label on the left and the four
            // direct-selection controls on the right. Details begin directly
            // beneath it. There is deliberately no Schedule Next Appointment,
            // Reschedule, or other hero/action CTA in this area.
            if (showStatus)
              _EventStatusControlRow(
                currentStatus: occurrence.status,
                optimisticStatus: _draftStatus,
                isContactEvent: isContactEvent,
                saving: _statusSaving,
                onSelect: (selected) => _handleStatusTap(occurrence, selected),
              ),
            if (showStatus) ...<Widget>[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
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
              const SizedBox(height: 8),
            ],
            _DetailField(
              key: const Key('event-detail-title'),
              icon: Icons.title_outlined,
              label: 'Title',
              value: occurrence.displayTitle,
            ),
            const SizedBox(height: 8),
            if (occurrence.isBackupAppointment)
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    key: Key('event-detail-backup-badge'),
                    avatar: Icon(Icons.layers_outlined, size: 18),
                    label: Text('Backup Appointment'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
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
            // Delta 3: recurrence is persisted and must be VISIBLE.  The row
            // sits between Time and Event Type (Date, Time, Repeats, Event
            // Type order) and reads e.g. 'Daily' or 'Weekly • Until Aug 31,
            // 2026'.  A This-Event-Only occurrence exception stays
            // series-linked and therefore still shows its Repeats row.
            if (occurrence.isRecurring)
              _DetailField(
                key: const Key('event-detail-repeats'),
                icon: Icons.repeat,
                label: 'Repeats',
                value: calendarRecurrenceRuleLabel(occurrence.recurrence),
              ),
            if (eventTypeLabel != null)
              _DetailField(
                icon: Icons.category_outlined,
                label: isContactEvent ? 'Contact Type' : 'Event Type',
                value: eventTypeLabel,
              ),
            if (occurrence.timing == CalendarEventTiming.allDay)
              const _DetailRow(icon: Icons.today_outlined, label: 'All day'),
            // Delta 3: the user-facing 'Original time zone' row is REMOVED.
            // The internal IANA time-zone identity (occurrence.timeZoneId /
            // displayTimeZoneId) remains stored and is still used by
            // recurrence, DST, occurrence generation, and export — only the
            // preview row is gone.
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
                label: 'Life Goal',
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
            const Divider(height: 28),
            ListTile(
              key: const Key('event-activity-history-button'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: const Text('Activity History'),
              subtitle: const Text('Read-only status and activity records'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.activityHistory),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
    final Widget detailContent;
    if (!widget.sheetPresentation) {
      detailContent = Scaffold(
        appBar: InternalAppBar(
          title: Text(_detailHeading),
          actions: _draftActive
              ? <Widget>[
                  IconButton(
                    key: const Key('event-status-save'),
                    tooltip: 'Save report status',
                    // 48 x 48 default touch target; disabled while the
                    // canonical transaction is in flight so duplicate taps
                    // cannot double-submit.
                    onPressed: _statusSaving ? null : _saveDraft,
                    icon: _statusSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                  ),
                ]
              : <Widget>[
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
    } else {
      detailContent = Material(
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
                    key: const Key('event-detail-sheet-close'),
                    tooltip: _draftActive
                        ? 'Cancel status draft'
                        : 'Close Calendar Event details',
                    onPressed: _draftActive
                        ? () => setState(() => _draftStatus = null)
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      _detailHeading,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        height: 26 / 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_draftActive)
                    IconButton(
                      key: const Key('event-status-save'),
                      tooltip: 'Save report status',
                      // 48 x 48 default touch target; disabled while the
                      // canonical transaction is in flight so duplicate taps
                      // cannot double-submit.
                      onPressed: _statusSaving ? null : _saveDraft,
                      icon: _statusSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                    )
                  else ...<Widget>[
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
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      );
    }
    // Draft-mode Back handling: Android Back cancels the staged status draft
    // first; a second Back exits the preview. The persisted status is never
    // changed by cancelling the draft.
    return PopScope<void>(
      canPop: !_draftActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }
        if (_draftActive) {
          setState(() => _draftStatus = null);
        }
      },
      child: detailContent,
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

  /// Draft-mode status tap. Entering draft mode never writes: the tapped
  /// status is only staged until Save. Tapping the persisted status (or
  /// Unreported, which represents the absence of a saved status) while a
  /// draft is active cancels the draft back to the persisted status.
  void _handleStatusTap(
    CalendarEventOccurrence occurrence,
    CalendarEventStatus selected,
  ) {
    if (_statusSaving) {
      return;
    }
    if (!_draftActive) {
      if (selected == occurrence.status ||
          selected == CalendarEventStatus.scheduled) {
        return;
      }
      setState(() => _draftStatus = selected);
      return;
    }
    if (selected == occurrence.status ||
        selected == CalendarEventStatus.scheduled) {
      setState(() => _draftStatus = null);
      return;
    }
    setState(() => _draftStatus = selected);
  }

  /// Commits the staged draft (via the top-right check icon) through the
  /// canonical reporting engine: one outcome, one Activity History state, one
  /// operation/outbox state, and one contribution state. On success the
  /// preview returns to normal mode and the Planner Event block refreshes
  /// through the shared provider reload.
  Future<void> _saveDraft() async {
    final occurrence = _latestOccurrence;
    final status = _draftStatus;
    if (occurrence == null || status == null || _statusSaving) {
      return;
    }
    final outcome = switch (status) {
      CalendarEventStatus.completedHappened => OutcomeKind.completedHappened,
      CalendarEventStatus.partiallyCompleted => OutcomeKind.partiallyCompleted,
      CalendarEventStatus.didNotHappen => OutcomeKind.didNotHappen,
      _ => null,
    };
    if (outcome == null) {
      setState(() => _draftStatus = null);
      return;
    }
    setState(() => _statusSaving = true);
    try {
      final result = await ref
          .read(outcomeReportingControllerProvider.notifier)
          .submitEventStatus(
            eventId: occurrence.eventId,
            originalDate: occurrence.originalDate,
            outcome: outcome,
            operationId: ref.read(plannerIdentifierSourceProvider).nextUuid(),
            contributionRuleKey: occurrence.contributionRuleKey,
          );
      if (mounted && result != null) {
        setState(() {
          _draftStatus = null;
          _reload();
        });
      } else if (mounted) {
        // Honest failure feedback: the canonical submit path reports
        // failures through the outcome controller's own state (it does not
        // rethrow), so a null result is read back and shown here. The draft
        // stays staged and the check icon remains available for retry — the
        // persisted status, Activity History, operations, and contributions
        // were never partially updated.
        final message = ref.read(outcomeReportingControllerProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message == null || message.isEmpty
                  ? 'Unable to save the Event status.'
                  : message,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save the Event status.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _statusSaving = false);
      }
    }
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
    // Delta 4.1 edit flow: Edit ALWAYS opens the Edit Event form first — for
    // normal, repeating, Backup, Contact, reported, and unreported Events
    // alike.  For a repeating Event the recurrence scope chooser must not
    // appear before the user reaches the form; it is shown only when the
    // user commits a change on Save (the form defers the scope decision via
    // [RoutePaths.calendarEventEdit]'s `deferScope` flag).  The passed
    // occurrence scope is a placeholder that the form ignores when deferral
    // is active.
    final path = RoutePaths.calendarEventEdit(
      occurrence.eventId,
      occurrence.originalDate,
      CalendarEventEditScope.occurrence,
      deferScopeToSave: occurrence.isRecurring,
    );
    final changed = await context.push<bool>(path);
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _cancel(
    CalendarEventOccurrence occurrence, {
    bool delete = false,
  }) async {
    if (delete) {
      final operationId = ref.read(plannerIdentifierSourceProvider).nextUuid();
      if (occurrence.isRecurring) {
        // One clear destructive dialog: the scope is part of the dialog
        // itself (Delete This Event / Delete All Events), so no
        // informational scope sheet plus a second confirmation is ever
        // shown.
        final scope = await _selectRecurringDeleteScope();
        if (!mounted || scope == null) {
          return;
        }
        await _performCancel(
          occurrence,
          scope: scope,
          operationId: operationId,
        );
        return;
      }
      // Non-recurring Events keep the canonical simple confirmation dialog.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete Calendar Event?'),
          content: const Text('Historical records and reports will remain.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Event'),
            ),
            FilledButton(
              key: const Key('confirm-delete-event'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Event'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await _performCancel(
        occurrence,
        scope: CalendarEventEditScope.occurrence,
        operationId: operationId,
      );
      return;
    }
    final scope = await _selectScope(occurrence);
    if (!mounted || scope == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Calendar Event?'),
        content: Text(
          'Scope: ${_scopeLabel(scope)}. Historical records '
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
    await _performCancel(occurrence, scope: scope, operationId: operationId);
  }

  Future<void> _performCancel(
    CalendarEventOccurrence occurrence, {
    required CalendarEventEditScope scope,
    required String operationId,
  }) async {
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

  /// Single destructive dialog for a recurring Event deletion. The scope is
  /// chosen inside the dialog itself, so the previous two-step scope sheet +
  /// confirmation flow is gone. Keep Event changes nothing. Non-recurring
  /// Events never route through this dialog.
  Future<CalendarEventEditScope?> _selectRecurringDeleteScope() {
    return showDialog<CalendarEventEditScope>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          key: const Key('recurring-delete-dialog'),
          title: const Text('Delete Repeating Event?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Choose which Events to delete. Historical reports and '
                'activity records will remain.',
              ),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('recurring-delete-this-event'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(CalendarEventEditScope.occurrence),
                child: const Text('Delete This Event'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('recurring-delete-all-events'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(CalendarEventEditScope.series),
                child: const Text('Delete All Events'),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              key: const Key('recurring-delete-keep-event'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep Event'),
            ),
          ],
        );
      },
    );
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
                'Change repeating event',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              RepeatingEventScopeChoices(
                originalDate: occurrence.originalDate,
                keyPrefix: 'event-scope',
                onSelected: (scope) => Navigator.of(sheetContext).pop(scope),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const Key('event-scope-cancel'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _scopeLabel(CalendarEventEditScope scope) {
    return switch (scope) {
      CalendarEventEditScope.occurrence => 'This event only',
      CalendarEventEditScope.series => 'All events',
      CalendarEventEditScope.thisAndFuture => 'This event only',
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

  static bool _isContactEvent(String? stableKey, String? label) {
    if (stableKey == SystemEventTypeKeys.meaningfulConnection) {
      return true;
    }
    final normalized = label?.trim().toLowerCase();
    return normalized != null && normalized.contains('contact');
  }
}

/// Compact status row for the Calendar Event preview.
///
/// The current status label sits on the left and the direct-selection
/// controls sit on the right, immediately below the app bar. Tapping a
/// different status only stages a draft — no reporting write happens until
/// the top-right check icon commits it. The selected control uses a filled
/// treatment while the unselected ones use a neutral outline, so the state
/// never relies on color alone.
///
/// Planner Polish Delta 2 status matrix:
///   Contact Events  → Unreported / Did Not Attempt / Missed - Attempted /
///                     Completed (four controls);
///   generic Events  → Unreported / Missed / Completed (three controls;
///                     Did Not Attempt is no longer offered).  Legacy
///                     non-Contact Did Not Attempt records remain readable
///                     through the label but are not re-selectable.
final class _EventStatusControlRow extends StatelessWidget {
  const _EventStatusControlRow({
    required this.currentStatus,
    required this.optimisticStatus,
    required this.isContactEvent,
    required this.saving,
    required this.onSelect,
  });

  final CalendarEventStatus currentStatus;
  final CalendarEventStatus? optimisticStatus;
  final bool isContactEvent;
  final bool saving;
  final ValueChanged<CalendarEventStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    final effective = optimisticStatus ?? currentStatus;
    final currentKind = PlannerEventReportStatus.kindForStatus(
      effective,
      isContactEvent: isContactEvent,
    );
    return Row(
      key: const Key('event-status-control'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Current Status',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 3),
              Text(
                calendarEventOutcomeLabel(
                  status: effective,
                  isContactEvent: isContactEvent,
                ),
                key: const Key('event-status-current-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PlannerEventReportStatus.colorFor(currentKind),
                  fontSize: 17,
                  height: 20 / 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        for (final (status) in _selectableStatuses(
          isContactEvent: isContactEvent,
        )) ...<Widget>[
          _EventStatusControlButton(
            key: Key('event-status-option-${status.name}'),
            status: status,
            isContactEvent: isContactEvent,
            selected: effective == status,
            enabled: !saving,
            onTap: () => onSelect(status),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  /// The selectable Current Status set for this Event.  Contact Events keep
  /// the richer four-state set (including Did Not Attempt); generic
  /// non-Contact Events offer exactly Unreported / Missed / Completed.
  static List<CalendarEventStatus> _selectableStatuses({
    required bool isContactEvent,
  }) {
    return isContactEvent
        ? const <CalendarEventStatus>[
            CalendarEventStatus.scheduled,
            CalendarEventStatus.didNotHappen,
            CalendarEventStatus.partiallyCompleted,
            CalendarEventStatus.completedHappened,
          ]
        : const <CalendarEventStatus>[
            CalendarEventStatus.scheduled,
            CalendarEventStatus.partiallyCompleted,
            CalendarEventStatus.completedHappened,
          ];
  }
}

final class _EventStatusControlButton extends StatelessWidget {
  const _EventStatusControlButton({
    required this.status,
    required this.isContactEvent,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final CalendarEventStatus status;
  final bool isContactEvent;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = PlannerEventReportStatus.kindForStatus(
      status,
      isContactEvent: isContactEvent,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: PlannerEventReportStatus.labelFor(
        kind,
        isContactEvent: isContactEvent,
      ),
      child: Tooltip(
        message: PlannerEventReportStatus.labelFor(
          kind,
          isContactEvent: isContactEvent,
        ),
        child: GestureDetector(
          key: Key('event-status-button-${status.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          // Combined delta: the VISIBLE control shrinks to ~21 dp while the
          // touch target stays the full 48 x 48 interactive square, so the
          // icon reads as a compact selector (not a large circular button)
          // without losing accessibility.
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: PlannerReportStatusIcon(
                kind: kind,
                size: 21,
                style: selected
                    ? PlannerReportStatusIconStyle.selected
                    : PlannerReportStatusIconStyle.unselected,
              ),
            ),
          ),
        ),
      ),
    );
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
