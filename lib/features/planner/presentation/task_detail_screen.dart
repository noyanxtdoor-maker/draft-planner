import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_creation.dart';

final class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

final class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late Future<PlannerTask?> _task;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _task = ref
        .read(plannerControllerProvider.notifier)
        .readTask(widget.taskId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Edit Task',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<PlannerTask?>(
          future: _task,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final task = snapshot.data;
            if (task == null) {
              return const Center(child: Text('Task not found.'));
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  task.title,
                  key: const Key('task-detail-title'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_statusLabel(task.status)),
                const SizedBox(height: 16),
                _DetailRow(
                  icon: Icons.event_outlined,
                  label: task.dueDate == null
                      ? 'No due date'
                      : 'Due ${task.dueDate!.iso8601}',
                ),
                if (task.notes != null)
                  _DetailRow(icon: Icons.notes, label: task.notes!),
                _DetailRow(
                  icon: Icons.assignment_outlined,
                  label: task.requiresReport
                      ? 'Structured report required'
                      : 'No structured report required',
                ),
                if (task.linkedEventIds.isNotEmpty)
                  _DetailRow(
                    icon: Icons.event_note_outlined,
                    label:
                        '${task.linkedEventIds.length} linked Calendar Event(s)',
                  ),
                if (task.pathwayContextLabels.isNotEmpty)
                  _DetailRow(
                    icon: Icons.layers_outlined,
                    label: task.pathwayContextLabels.join(', '),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Calendar Event links',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const Key('manage-task-event-links'),
                  onPressed: _manageLinks,
                  icon: const Icon(Icons.link),
                  label: const Text('Link or manage Calendar Events'),
                ),
                OutlinedButton.icon(
                  key: const Key('create-event-from-task'),
                  onPressed: () => _createEvent(task),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Create Calendar Event from Task'),
                ),
                const SizedBox(height: 20),
                Text(
                  'Task status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (task.status == PlannerTaskStatus.incomplete) ...<Widget>[
                  FilledButton.tonalIcon(
                    key: const Key('complete-task-button'),
                    onPressed: task.requiresReport
                        ? () => _openReport(task)
                        : () => _changeStatus(PlannerTaskStatus.completed),
                    icon: Icon(
                      task.requiresReport
                          ? Icons.assignment_turned_in_outlined
                          : Icons.check,
                    ),
                    label: Text(
                      task.requiresReport
                          ? 'Complete with Report'
                          : 'Mark Completed',
                    ),
                  ),
                  if (!task.requiresReport)
                    OutlinedButton.icon(
                      key: const Key('open-task-report-button'),
                      onPressed: () => _openReport(task),
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Open Activity Report'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('skip-task-button'),
                    onPressed: () => _changeStatus(PlannerTaskStatus.skipped),
                    icon: const Icon(Icons.fast_forward_outlined),
                    label: const Text('Mark Skipped'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('cancel-task-button'),
                    onPressed: () => _changeStatus(PlannerTaskStatus.cancelled),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Mark Cancelled'),
                  ),
                ] else
                  OutlinedButton.icon(
                    key: const Key('reopen-task-button'),
                    onPressed: () =>
                        _changeStatus(PlannerTaskStatus.incomplete),
                    icon: const Icon(Icons.undo),
                    label: const Text('Reopen Task'),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('task-activity-history-button'),
                  onPressed: () => context.push(RoutePaths.activityHistory),
                  icon: const Icon(Icons.history),
                  label: const Text('View Activity History'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Changing a Task status never completes a linked Calendar '
                  'Event and never directly changes Actual.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final changed = await context.push<bool>(
      '${RoutePaths.tasks}/${widget.taskId}/edit',
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _manageLinks() async {
    await context.push<bool>('${RoutePaths.tasks}/${widget.taskId}/link-event');
    if (mounted) {
      setState(_reload);
    }
  }

  Future<void> _createEvent(PlannerTask task) async {
    final date =
        task.dueDate ?? ref.read(plannerControllerProvider).selectedDate;
    final changed = await launchCalendarEventCreation<bool>(
      context,
      ref,
      CalendarEventCreationContext(
        source: 'task',
        destinationPath: '${RoutePaths.tasks}/${widget.taskId}/create-event',
        date: date,
        sourceTaskId: widget.taskId,
      ),
    );
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _openReport(PlannerTask task) async {
    final changed = await context.push<bool>(RoutePaths.taskReport(task.id));
    if (changed == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _changeStatus(PlannerTaskStatus target) async {
    final operationId = ref.read(plannerIdentifierSourceProvider).nextUuid();
    final outcome = await ref
        .read(plannerControllerProvider.notifier)
        .changeStatus(
          taskId: widget.taskId,
          target: target,
          operationId: operationId,
        );
    if (!mounted) {
      return;
    }
    final message = switch (outcome) {
      TaskStatusChangeOutcome.reportRequired =>
        'This Task remains Incomplete. Its required report cannot be bypassed.',
      TaskStatusChangeOutcome.correctionRequired =>
        'A correction is required because this status has historical effects.',
      TaskStatusChangeOutcome.unchanged => 'Task status was unchanged.',
      TaskStatusChangeOutcome.changed => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    setState(_reload);
  }

  static String _statusLabel(PlannerTaskStatus status) {
    return switch (status) {
      PlannerTaskStatus.incomplete => 'Incomplete',
      PlannerTaskStatus.completed => 'Completed',
      PlannerTaskStatus.skipped => 'Skipped',
      PlannerTaskStatus.cancelled => 'Cancelled',
    };
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
