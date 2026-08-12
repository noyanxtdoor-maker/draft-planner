import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/application/task_event_link_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/task_event_link.dart';

final class TaskEventLinkScreen extends ConsumerStatefulWidget {
  const TaskEventLinkScreen.forTask({required this.taskId, super.key})
    : eventId = null,
      occurrenceId = null,
      originalDate = null;

  const TaskEventLinkScreen.forEvent({
    required this.eventId,
    required this.occurrenceId,
    required this.originalDate,
    super.key,
  }) : taskId = null;

  final String? taskId;
  final String? eventId;
  final String? occurrenceId;
  final PlannerDate? originalDate;

  bool get isTaskOrigin => taskId != null;

  @override
  ConsumerState<TaskEventLinkScreen> createState() =>
      _TaskEventLinkScreenState();
}

final class _TaskEventLinkScreenState
    extends ConsumerState<TaskEventLinkScreen> {
  late Future<_LinkPageData> _load;
  TaskEventCanonicalSource _canonicalSource = TaskEventCanonicalSource.task;
  TaskEventLinkScope _scope = TaskEventLinkScope.series;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _canonicalSource = widget.isTaskOrigin
        ? TaskEventCanonicalSource.task
        : TaskEventCanonicalSource.event;
    _reload();
  }

  void _reload() {
    final controller = ref.read(taskEventLinkControllerProvider.notifier);
    _load = widget.isTaskOrigin
        ? Future.wait<Object>(<Future<Object>>[
            controller.readForTask(widget.taskId!),
            controller.readEventCandidates(),
          ]).then(
            (values) => _LinkPageData(
              links: values[0] as List<TaskEventLinkView>,
              eventCandidates: values[1] as List<TaskEventEventCandidate>,
            ),
          )
        : Future.wait<Object>(<Future<Object>>[
            controller.readForEvent(
              eventId: widget.eventId!,
              occurrenceId: widget.occurrenceId!,
            ),
            controller.readTaskCandidates(),
          ]).then(
            (values) => _LinkPageData(
              links: values[0] as List<TaskEventLinkView>,
              taskCandidates: values[1] as List<TaskEventTaskCandidate>,
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(taskEventLinkControllerProvider);
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Task and Event links')),
      body: SafeArea(
        child: FutureBuilder<_LinkPageData>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Center(
                child: Text('Links could not be opened. No data was changed.'),
              );
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (message != null)
                  Card(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(message),
                    ),
                  ),
                Text(
                  'Current links',
                  style: InternalScreen.sectionHeading.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (data.links.isEmpty)
                  const Text('No active links.')
                else
                  for (final view in data.links) _linkTile(view),
                const SizedBox(height: 18),
                Text(
                  widget.isTaskOrigin ? 'Link a Calendar Event' : 'Link a Task',
                  style: InternalScreen.sectionHeading.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TaskEventCanonicalSource>(
                  key: const Key('link-canonical-source'),
                  initialValue: _canonicalSource,
                  decoration: const InputDecoration(
                    labelText: 'Planning source counted once',
                    helperText:
                        'The link itself never adds progress or Actual.',
                  ),
                  items: TaskEventCanonicalSource.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(taskEventCanonicalSourceLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _canonicalSource = value!),
                ),
                if (widget.isTaskOrigin) ...<Widget>[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskEventLinkScope>(
                    key: const Key('link-scope'),
                    initialValue: _scope,
                    decoration: const InputDecoration(labelText: 'Link scope'),
                    items: TaskEventLinkScope.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(taskEventLinkScopeLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _scope = value!),
                  ),
                  const SizedBox(height: 12),
                  for (final candidate in data.eventCandidates)
                    ListTile(
                      key: Key('link-event-${candidate.id}'),
                      title: Text(candidate.title),
                      subtitle: Text(
                        '${candidate.startDate.iso8601} · '
                        '${candidate.statusLabel}'
                        '${candidate.isRecurring ? ' · Recurring' : ''}',
                      ),
                      trailing: const Icon(Icons.add_link),
                      onTap: _saving ? null : () => _linkEvent(candidate),
                    ),
                ] else ...<Widget>[
                  const SizedBox(height: 12),
                  for (final candidate in data.taskCandidates)
                    ListTile(
                      key: Key('link-task-${candidate.id}'),
                      title: Text(candidate.title),
                      subtitle: Text(candidate.statusLabel),
                      trailing: const Icon(Icons.add_link),
                      onTap: _saving ? null : () => _linkTask(candidate),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _linkTile(TaskEventLinkView view) {
    final relatedTitle = widget.isTaskOrigin ? view.eventTitle : view.taskTitle;
    return Card(
      key: Key('task-event-link-${view.link.id}'),
      child: ListTile(
        title: Text(relatedTitle),
        subtitle: Text(
          view.isBroken
              ? 'Broken reference · repair or remove safely'
              : '${taskEventLinkScopeLabel(view.link.scope)} · '
                    'Source: ${taskEventCanonicalSourceLabel(view.link.canonicalSource)}\n'
                    '${view.link.scheduledPotentialExplanation}',
        ),
        isThreeLine: !view.isBroken,
        onTap: view.isBroken ? null : () => _openRelated(view),
        trailing: IconButton(
          tooltip: 'Remove link',
          onPressed: _saving ? null : () => _confirmRemove(view),
          icon: const Icon(Icons.link_off),
        ),
      ),
    );
  }

  Future<void> _linkEvent(TaskEventEventCandidate candidate) async {
    final occurrence = _scope == TaskEventLinkScope.occurrence
        ? CalendarEventOccurrenceIdentity.forDate(
            eventId: candidate.id,
            originalDate: candidate.startDate,
          )
        : null;
    await _create(
      TaskEventLinkDraft(
        id: _id(),
        taskId: widget.taskId!,
        eventId: candidate.id,
        scope: _scope,
        occurrenceId: occurrence,
        originalDate: _scope == TaskEventLinkScope.occurrence
            ? candidate.startDate
            : null,
        canonicalSource: _canonicalSource,
      ),
    );
  }

  Future<void> _linkTask(TaskEventTaskCandidate candidate) {
    return _create(
      TaskEventLinkDraft(
        id: _id(),
        taskId: candidate.id,
        eventId: widget.eventId!,
        scope: TaskEventLinkScope.occurrence,
        occurrenceId: widget.occurrenceId,
        originalDate: widget.originalDate,
        canonicalSource: _canonicalSource,
      ),
    );
  }

  Future<void> _create(TaskEventLinkDraft draft) async {
    setState(() => _saving = true);
    final success = await ref
        .read(taskEventLinkControllerProvider.notifier)
        .createLink(draft: draft, operationId: _id());
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (success) {
        _reload();
      }
    });
  }

  Future<void> _confirmRemove(TaskEventLinkView view) async {
    var removeOnlyOccurrence = false;
    if (view.link.scope == TaskEventLinkScope.series && !widget.isTaskOrigin) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove link'),
          content: const Text(
            'Remove this link only from the open occurrence? '
            'Choose “Entire series” to remove it everywhere. '
            'Neither the Task nor Calendar Event will be deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Entire series'),
            ),
            FilledButton(
              key: const Key('remove-link-occurrence'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('This occurrence'),
            ),
          ],
        ),
      );
      if (choice == null) {
        return;
      }
      removeOnlyOccurrence = choice;
    }
    if (!mounted) {
      return;
    }
    if (view.link.scope != TaskEventLinkScope.series || widget.isTaskOrigin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove link?'),
          content: const Text(
            'Only the relationship will be removed. The Task and Calendar '
            'Event remain unchanged.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep link'),
            ),
            FilledButton(
              key: const Key('confirm-remove-link'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove link'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }
    setState(() => _saving = true);
    final success = await ref
        .read(taskEventLinkControllerProvider.notifier)
        .removeLink(
          linkId: view.link.id,
          operationId: _id(),
          occurrenceOverrideId: removeOnlyOccurrence
              ? widget.occurrenceId
              : null,
          occurrenceOverrideDate: removeOnlyOccurrence
              ? widget.originalDate
              : null,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (success) {
        _reload();
      }
    });
  }

  void _openRelated(TaskEventLinkView view) {
    if (widget.isTaskOrigin) {
      final date = view.link.originalDate ?? view.eventStartDate;
      if (date != null) {
        unawaited(
          context.push(RoutePaths.calendarEventDetail(view.link.eventId, date)),
        );
      }
    } else {
      unawaited(context.push('${RoutePaths.tasks}/${view.link.taskId}'));
    }
  }

  String _id() => ref.read(plannerIdentifierSourceProvider).nextUuid();
}

final class _LinkPageData {
  const _LinkPageData({
    required this.links,
    this.taskCandidates = const <TaskEventTaskCandidate>[],
    this.eventCandidates = const <TaskEventEventCandidate>[],
  });

  final List<TaskEventLinkView> links;
  final List<TaskEventTaskCandidate> taskCandidates;
  final List<TaskEventEventCandidate> eventCandidates;
}
