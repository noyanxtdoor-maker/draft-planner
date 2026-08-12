import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/widgets/event_color_picker_components.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

final class EventTypeFormScreen extends ConsumerStatefulWidget {
  const EventTypeFormScreen.create({super.key})
    : eventTypeId = null,
      fixedAssignmentLabel = null;

  const EventTypeFormScreen.edit({
    required this.eventTypeId,
    this.fixedAssignmentLabel,
    super.key,
  });

  final String? eventTypeId;
  final String? fixedAssignmentLabel;

  @override
  ConsumerState<EventTypeFormScreen> createState() =>
      _EventTypeFormScreenState();
}

final class _EventTypeFormScreenState
    extends ConsumerState<EventTypeFormScreen> {
  static const _indicatorLabels = <String, String>{
    'temple_visit': 'Temple Visit',
    'scripture_study': 'Scripture Study',
    'exercise': 'Exercise',
    'budget_review': 'Budget Review',
    'job_applications': 'Job Applications',
    'meaningful_connections': 'Meaningful Connections',
  };

  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  late final String _id;
  EventTypeIcon _icon = EventTypeIcon.calendar;
  int _colorValue = 0xFF868A8D;
  bool _reportRequired = false;
  Set<String> _indicatorKeys = <String>{};
  bool _loading = false;
  bool _saving = false;
  EventType? _eventType;

  bool get _isFixedGoalAssignment =>
      widget.eventTypeId != null && widget.fixedAssignmentLabel != null;

  @override
  void initState() {
    super.initState();
    _id =
        widget.eventTypeId ??
        ref.read(plannerIdentifierSourceProvider).nextUuid();
    if (widget.eventTypeId != null) {
      _loading = true;
      unawaited(Future<void>.microtask(_load));
    }
  }

  Future<void> _load() async {
    final type = await ref
        .read(eventTypeControllerProvider.notifier)
        .readType(widget.eventTypeId!);
    if (!mounted) {
      return;
    }
    if (type == null || (type.isSystem && !_isFixedGoalAssignment)) {
      Navigator.of(context).pop();
      return;
    }
    final state = ref.read(eventTypeControllerProvider);
    final preference = state.eventColors[type.stableKey];
    setState(() {
      _eventType = type;
      _labelController.text = type.label;
      _durationController.text = type.defaultDurationMinutes.toString();
      _icon = type.icon;
      _colorValue = preference?.accentArgb ?? type.colorValue;
      _reportRequired = type.reportRequiredDefault;
      _indicatorKeys = Set<String>.of(type.indicatorKeys);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _labelController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fixedAssignmentLabel = widget.fixedAssignmentLabel;
    return Scaffold(
      appBar: InternalAppBar(
        title: Text(
          widget.eventTypeId == null ? 'New Event Type' : 'Edit Event Type',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: InternalScreen.pagePadding,
                  children: <Widget>[
                    TextFormField(
                      key: const Key('custom-event-type-label'),
                      controller: _labelController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (_isFixedGoalAssignment &&
                        fixedAssignmentLabel != null) ...<Widget>[
                      Text(
                        'Fixed Goal Assignment',
                        style: InternalScreen.sectionHeading,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Events of this type contribute toward this Goal. '
                        'The assignment is fixed.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('This assignment cannot be changed.'),
                      const SizedBox(height: 6),
                      Text('Assigned Goal: $fixedAssignmentLabel'),
                      const SizedBox(height: 10),
                      _buildColorField(),
                      const SizedBox(height: 10),
                      const Text(
                        'Renaming the Event Type affects newly created Events '
                        'only. Existing Events keep the names they had when '
                        'created.',
                      ),
                    ] else ...<Widget>[
                      DropdownButtonFormField<EventTypeIcon>(
                        initialValue: _icon,
                        decoration: const InputDecoration(labelText: 'Icon'),
                        items: <DropdownMenuItem<EventTypeIcon>>[
                          for (final icon in EventTypeIcon.values)
                            DropdownMenuItem(
                              value: icon,
                              child: Text(icon.name),
                            ),
                        ],
                        onChanged: (value) => setState(() => _icon = value!),
                      ),
                      const SizedBox(height: 12),
                      _buildColorField(),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('custom-event-type-duration'),
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Default duration in minutes',
                        ),
                        validator: (value) {
                          final duration = int.tryParse(value ?? '');
                          return duration == null ||
                                  duration < 15 ||
                                  duration > 1440
                              ? 'Enter 15 to 1440 minutes'
                              : null;
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Report required by default'),
                        value: _reportRequired,
                        onChanged: (value) =>
                            setState(() => _reportRequired = value),
                      ),
                      const Divider(),
                      Text(
                        'Life Goal mappings',
                        style: InternalScreen.sectionHeading,
                      ),
                      const Text(
                        'Choose None, one, or several explicitly. Names are '
                        'never used to guess a mapping.',
                      ),
                      CheckboxListTile(
                        key: const Key('custom-event-type-mapping-none'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('None'),
                        value: _indicatorKeys.isEmpty,
                        onChanged: (value) {
                          if (value ?? false) {
                            setState(_indicatorKeys.clear);
                          }
                        },
                      ),
                      for (final entry in _indicatorLabels.entries)
                        CheckboxListTile(
                          key: Key('custom-event-type-mapping-${entry.key}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.value),
                          value: _indicatorKeys.contains(entry.key),
                          onChanged: (value) => setState(() {
                            if (value ?? false) {
                              _indicatorKeys.add(entry.key);
                            } else {
                              _indicatorKeys.remove(entry.key);
                            }
                          }),
                        ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const Key('save-custom-event-type'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving…' : 'Save Event Type'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildColorField() {
    return EventTypeColorPanel(
      key: const Key('event-type-color-panel'),
      eventTypeLabel: _labelController.text.trim().isEmpty
          ? 'Event Type'
          : _labelController.text.trim(),
      initialColor: Color(_colorValue),
      onColorChanged: (color) => setState(() => _colorValue = color.toARGB32()),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(eventTypeControllerProvider.notifier);
    final saved = _isFixedGoalAssignment && _eventType != null
        ? await _saveFixedAssignment(controller)
        : await _saveCustomType(controller);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _saveCustomType(EventTypeController controller) async {
    final saved = await controller.saveCustomType(
      EventTypeDraft(
        id: _id,
        label: _labelController.text,
        icon: _icon,
        colorValue: _colorValue,
        reportRequiredDefault: _reportRequired,
        defaultDurationMinutes: int.parse(_durationController.text),
        indicatorKeys: Set<String>.of(_indicatorKeys),
      ),
    );
    if (!saved) {
      return false;
    }
    // The Event Type row and the canonical color preference are written
    // together at Save so Event Colors Settings and Edit Event Type always
    // read the same current value through the same repository path.
    final state = ref.read(eventTypeControllerProvider);
    final type = state.eventTypes
        .where((candidate) => candidate.id == _id)
        .firstOrNull;
    if (type == null) {
      return true;
    }
    final current =
        state.eventColors[type.stableKey] ??
        PlannerEventColorDefaults.forEventType(type);
    return controller.saveEventColor(
      type,
      EventColorPreference(
        accentArgb: _colorValue,
        // The surface derives from the canonical accent whenever the accent
        // changes, so a stale old-color surface can never linger after an
        // Edit Event Type Save.
        surfaceArgb: PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
          accentArgb: _colorValue,
          currentAccentArgb: current.accentArgb,
          currentSurfaceArgb: current.surfaceArgb,
        ),
      ),
    );
  }

  Future<bool> _saveFixedAssignment(EventTypeController controller) async {
    final type = _eventType!;
    final renamed = await controller.renameSystemType(
      eventTypeId: type.id,
      label: _labelController.text.trim(),
    );
    if (!renamed) {
      return false;
    }
    final current =
        ref.read(eventTypeControllerProvider).eventColors[type.stableKey] ??
        PlannerEventColorDefaults.forEventType(type);
    return controller.saveEventColor(
      type,
      EventColorPreference(
        accentArgb: _colorValue,
        // The surface derives from the canonical accent whenever the accent
        // changes, so a stale old-color surface can never linger after an
        // Edit Event Type Save.
        surfaceArgb: PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
          accentArgb: _colorValue,
          currentAccentArgb: current.accentArgb,
          currentSurfaceArgb: current.surfaceArgb,
        ),
      ),
    );
  }
}
