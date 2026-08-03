import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_slide_down_date_picker.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen.create({
    required this.initialDueDate,
    this.indicatorKey,
    this.indicatorPeriod,
    super.key,
  }) : taskId = null;

  const TaskFormScreen.edit({required this.taskId, super.key})
    : initialDueDate = null,
      indicatorKey = null,
      indicatorPeriod = null;

  final String? taskId;
  final PlannerDate? initialDueDate;
  final String? indicatorKey;
  final IndicatorGoalPeriod? indicatorPeriod;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

final class _TaskFormScreenState extends ConsumerState<TaskFormScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final String _stableTaskId;
  PlannerDate? _dueDate;
  int? _dueMinute;
  PlannerTaskRecurrence _recurrence = PlannerTaskRecurrence.none;
  List<String> _people = <String>[];
  bool _requiresReport = false;
  bool _setDueDate = false;
  bool _notificationsUnavailable = false;
  bool _remindersUnavailable = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stableTaskId =
        widget.taskId ?? ref.read(plannerIdentifierSourceProvider).nextUuid();
    _dueDate = widget.initialDueDate;
    _setDueDate = widget.initialDueDate != null;
    _dueMinute = widget.initialDueDate == null ? null : 18 * 60;
    unawaited(_refreshCapabilities());
    if (widget.taskId != null) {
      _loading = true;
      unawaited(_loadExisting());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _setDueDate) {
      unawaited(_refreshCapabilities());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _refreshCapabilities() async {
    final status = await ref
        .read(permissionGatewayProvider)
        .status(OptionalPermission.notifications);
    if (!mounted) {
      return;
    }
    final unavailable = status != OperatingSystemPermissionState.granted;
    setState(() {
      _notificationsUnavailable = unavailable;
      // The current release has no independent reminder scheduler. Until one
      // is introduced, reminder capability follows notification capability.
      _remindersUnavailable = unavailable;
    });
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
    _descriptionController.text = task.notes ?? '';
    setState(() {
      _dueDate = task.dueDate;
      _dueMinute = task.dueMinute ?? (task.dueDate == null ? null : 18 * 60);
      _recurrence = task.recurrence;
      _people = List<String>.unmodifiable(task.people);
      _setDueDate = task.dueDate != null;
      _requiresReport = task.requiresReport;
      _loading = false;
    });
    if (_setDueDate) {
      await _refreshCapabilities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final use24HourTime = ref
        .watch(eventTypeControllerProvider)
        .settings
        .use24HourTime;
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('task-form-drag-handle'),
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          key: const Key('task-form-close'),
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.close, size: 30),
                        ),
                        const Spacer(),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        key: const Key('task-form-scroll'),
                        padding: EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          28 + MediaQuery.of(context).viewInsets.bottom,
                        ),
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
                            maxLines: 1,
                            decoration: _inputDecoration('Title'),
                            validator: (value) {
                              return value == null || value.trim().isEmpty
                                  ? 'Enter a Task title.'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('task-notes-field'),
                            controller: _descriptionController,
                            minLines: 3,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            decoration: _inputDecoration('Description'),
                          ),
                          const SizedBox(height: 18),
                          SwitchListTile(
                            key: const Key('task-set-due-date-switch'),
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Set Due Date'),
                            value: _setDueDate,
                            onChanged: _toggleDueDate,
                          ),
                          if (_setDueDate) ...<Widget>[
                            const SizedBox(height: 12),
                            _TaskValueField(
                              key: const Key('task-due-date-field'),
                              label: 'Due Date',
                              value: _dueDate?.iso8601 ?? 'Choose date',
                              icon: Icons.calendar_month_outlined,
                              onTap: _pickDueDate,
                            ),
                            const SizedBox(height: 16),
                            _TaskValueField(
                              key: const Key('task-due-time-field'),
                              label: 'Time',
                              value: _formatTime(context, use24HourTime),
                              onTap: _pickDueTime,
                            ),
                            const SizedBox(height: 12),
                            _TaskRepeatField(
                              key: const Key('task-repeat-field'),
                              value: _recurrence,
                              onTap: _pickRecurrence,
                            ),
                            if (_notificationsUnavailable) ...<Widget>[
                              const SizedBox(height: 18),
                              _CapabilityNotice(
                                key: const Key('task-notifications-notice'),
                                message: 'Notifications are disabled',
                                supportingText:
                                    'Enabling notifications in the app will allow you to be notified of new referrals, upcoming events, tasks due, and other important notifications',
                                onEnable: _openSettings,
                              ),
                            ],
                            if (_remindersUnavailable) ...<Widget>[
                              const SizedBox(height: 18),
                              _CapabilityNotice(
                                key: const Key('task-reminders-notice'),
                                message:
                                    'Cannot show reminders: Alarms & reminders is disabled',
                                onEnable: _openSettings,
                              ),
                            ],
                          ],
                          const SizedBox(height: 26),
                          const _TaskSectionHeader(label: 'People'),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: const Key('task-add-people-button'),
                              onPressed: _addPerson,
                              style: _rightAlignedActionStyle(),
                              icon: const Icon(Icons.add, size: 24),
                              label: const Text('People'),
                            ),
                          ),
                          if (_people.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            for (final person in _people)
                              Padding(
                                key: Key('task-person-row-$person'),
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(child: Text(person)),
                                    IconButton(
                                      key: Key('task-remove-person-$person'),
                                      tooltip: 'Remove $person',
                                      onPressed: () => _removePerson(person),
                                      icon: const Icon(Icons.close, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Semantics(
      button: true,
      label: 'Save',
      child: FilledButton(
        key: const Key('save-task-button'),
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          backgroundColor: AppTheme.rose,
          foregroundColor: AppTheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text('Save', style: AppTypography.button),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: AppTypography.micro,
      floatingLabelStyle: AppTypography.micro,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white54),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.rose, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  ButtonStyle _rightAlignedActionStyle() {
    return TextButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: EdgeInsets.zero,
      alignment: Alignment.centerRight,
      foregroundColor: AppTheme.rose,
      textStyle: AppTypography.button,
    );
  }

  void _toggleDueDate(bool value) {
    FocusScope.of(context).unfocus();
    setState(() {
      _setDueDate = value;
      if (value) {
        _dueDate ??= ref.read(plannerControllerProvider).selectedDate;
        _dueDate ??= PlannerDate.fromDateTime(DateTime.now());
        _dueMinute ??= 18 * 60;
      } else {
        _dueDate = null;
        _dueMinute = null;
        _recurrence = PlannerTaskRecurrence.none;
      }
    });
    if (value) {
      unawaited(_refreshCapabilities());
    }
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate?.asLocalDate ?? DateTime.now();
    final value = await showSharedPlannerDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: 'Select Task due date',
    );
    if (value != null && mounted) {
      setState(() => _dueDate = PlannerDate.fromDateTime(value));
    }
  }

  Future<void> _pickDueTime() async {
    final initial = _timeFromMinute(_dueMinute ?? 18 * 60);
    final value = await showTimePicker(context: context, initialTime: initial);
    if (value != null && mounted) {
      setState(() => _dueMinute = value.hour * 60 + value.minute);
    }
  }

  Future<void> _pickRecurrence() async {
    final value = await showModalBottomSheet<PlannerTaskRecurrence>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final recurrence in PlannerTaskRecurrence.values)
              ListTile(
                key: Key('task-repeat-option-${recurrence.name}'),
                title: Text(_recurrenceLabel(recurrence)),
                onTap: () => Navigator.of(sheetContext).pop(recurrence),
              ),
            TextButton(
              key: const Key('task-repeat-cancel'),
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      setState(() => _recurrence = value);
    }
  }

  Future<void> _openSettings() async {
    await ref.read(permissionGatewayProvider).openSystemSettings();
    if (mounted) {
      await _refreshCapabilities();
    }
  }

  Future<void> _addPerson() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _TaskPersonDialog(),
    );
    if (!mounted) {
      return;
    }
    final normalized = name?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    if (_people.contains(normalized)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That person is already selected.')),
      );
      return;
    }
    setState(() {
      _people = List<String>.unmodifiable(<String>[..._people, normalized]);
    });
  }

  void _removePerson(String person) {
    setState(() {
      _people = List<String>.unmodifiable(
        _people.where((selected) => selected != person),
      );
    });
  }

  String _formatTime(BuildContext context, bool use24HourTime) {
    final time = _timeFromMinute(_dueMinute ?? 18 * 60);
    if (use24HourTime) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    return time.format(context);
  }

  static TimeOfDay _timeFromMinute(int minute) {
    return TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
  }

  static String _recurrenceLabel(PlannerTaskRecurrence recurrence) {
    return switch (recurrence) {
      PlannerTaskRecurrence.none => 'Does not repeat',
      PlannerTaskRecurrence.daily => 'Daily',
      PlannerTaskRecurrence.weekly => 'Weekly',
      PlannerTaskRecurrence.monthly => 'Monthly',
      PlannerTaskRecurrence.yearly => 'Yearly',
    };
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
            notes: _descriptionController.text,
            dueDate: _setDueDate ? _dueDate : null,
            dueMinute: _setDueDate ? _dueMinute : null,
            recurrence: _setDueDate ? _recurrence : PlannerTaskRecurrence.none,
            requiresReport: _requiresReport,
            people: _people,
          ),
        );
    if (!mounted) {
      return;
    }
    if (saved) {
      if (widget.indicatorKey != null) {
        final startup = ref.read(startupControllerProvider);
        if (startup is StartupReady) {
          await ref
              .read(indicatorRepositoryProvider)
              .linkCommitment(
                profileId: startup.profile.id,
                indicatorKey: widget.indicatorKey!,
                period:
                    widget.indicatorPeriod ??
                    IndicatorGoalPeriod.weekly(
                      _dueDate ?? PlannerDate.fromDateTime(DateTime.now()),
                    ),
                entityType: IndicatorCommitmentEntityType.task,
                entityId: _stableTaskId,
                linkId: ref.read(plannerIdentifierSourceProvider).nextUuid(),
                operationId: ref
                    .read(plannerIdentifierSourceProvider)
                    .nextUuid(),
              );
        }
      }
      if (!mounted) {
        return;
      }
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

final class _TaskPersonDialog extends StatefulWidget {
  const _TaskPersonDialog();

  @override
  State<_TaskPersonDialog> createState() => _TaskPersonDialogState();
}

final class _TaskPersonDialogState extends State<_TaskPersonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('task-people-dialog'),
      title: const Text('Add Person'),
      content: TextField(
        key: const Key('task-person-name-field'),
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('task-person-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('task-person-add'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

final class _TaskValueField extends StatelessWidget {
  const _TaskValueField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 60,
        child: InputDecorator(
          isFocused: false,
          decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            labelStyle: AppTypography.micro,
            floatingLabelStyle: AppTypography.micro,
            suffixIcon: icon == null ? null : Icon(icon, size: 24),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white54),
              borderRadius: BorderRadius.circular(4),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppTheme.rose, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(value, style: AppTypography.body),
        ),
      ),
    );
  }
}

final class _TaskRepeatField extends StatelessWidget {
  const _TaskRepeatField({required this.value, required this.onTap, super.key});

  final PlannerTaskRecurrence value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('task-repeat-value'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Repeat', style: AppTypography.micro),
                  const SizedBox(height: 4),
                  Text(
                    _TaskFormScreenState._recurrenceLabel(value),
                    style: AppTypography.body,
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 26),
          ],
        ),
      ),
    );
  }
}

final class _TaskSectionHeader extends StatelessWidget {
  const _TaskSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: AppTypography.sectionTitle),
        const SizedBox(height: 8),
        const Divider(height: 1, color: Colors.white38),
      ],
    );
  }
}

final class _CapabilityNotice extends StatelessWidget {
  const _CapabilityNotice({
    required this.message,
    required this.onEnable,
    this.supportingText,
    super.key,
  });

  final String message;
  final String? supportingText;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFFB915),
              child: Text(
                'i',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(message, style: AppTypography.body)),
            TextButton(
              key: Key(
                'enable-${message.startsWith('Notifications') ? 'notifications' : 'reminders'}',
              ),
              onPressed: onEnable,
              style: TextButton.styleFrom(
                minimumSize: const Size(96, 48),
                foregroundColor: AppTheme.background,
                backgroundColor: AppTheme.rose,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: AppTypography.button,
              ),
              child: const Text('Enable'),
            ),
          ],
        ),
        if (supportingText != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(supportingText!, style: AppTypography.secondary),
        ],
      ],
    );
  }
}
