import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

final class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen.create({required this.initialDueDate, super.key})
    : taskId = null;

  const TaskFormScreen.edit({required this.taskId, super.key})
    : initialDueDate = null;

  final String? taskId;
  final PlannerDate? initialDueDate;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

final class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  late final String _stableTaskId;
  PlannerDate? _dueDate;
  bool _requiresReport = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stableTaskId =
        widget.taskId ?? ref.read(plannerIdentifierSourceProvider).nextUuid();
    _dueDate = widget.initialDueDate;
    if (widget.taskId != null) {
      _loading = true;
      unawaited(_loadExisting());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final task = await ref
        .read(plannerControllerProvider.notifier)
        .readTask(_stableTaskId);
    if (!mounted) {
      return;
    }
    if (task == null) {
      setState(() {
        _loading = false;
        _error = 'This Task no longer exists.';
      });
      return;
    }
    _titleController.text = task.title;
    _notesController.text = task.notes ?? '';
    setState(() {
      _dueDate = task.dueDate;
      _requiresReport = task.requiresReport;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskId == null ? 'New Task' : 'Edit Task'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    if (_error != null) ...<Widget>[
                      Text(
                        _error!,
                        key: const Key('task-form-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const Key('task-title-field'),
                      controller: _titleController,
                      autofocus: widget.taskId == null,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        hintText: 'What needs to be done?',
                      ),
                      validator: (value) {
                        return value == null || value.trim().isEmpty
                            ? 'Enter a Task title.'
                            : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('task-notes-field'),
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      key: const Key('task-due-date-button'),
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _dueDate == null
                            ? 'No due date'
                            : 'Due ${_dueDate!.iso8601}',
                      ),
                    ),
                    if (_dueDate != null)
                      TextButton(
                        onPressed: () => setState(() => _dueDate = null),
                        child: const Text('Remove due date'),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const Key('task-report-required-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Structured report required'),
                      subtitle: const Text(
                        'Completion stays Incomplete until the report and '
                        'completion can save together.',
                      ),
                      value: _requiresReport,
                      onChanged: (value) {
                        setState(() => _requiresReport = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('save-task-button'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save Task'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate?.asLocalDate ?? DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) {
      setState(() => _dueDate = PlannerDate.fromDateTime(value));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await ref
        .read(plannerControllerProvider.notifier)
        .saveTask(
          PlannerTaskDraft(
            id: _stableTaskId,
            title: _titleController.text,
            notes: _notesController.text,
            dueDate: _dueDate,
            requiresReport: _requiresReport,
          ),
        );
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error =
          ref.read(plannerControllerProvider).message ??
          'Task could not be saved. Your input remains available.';
    });
  }
}
