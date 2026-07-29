import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

final class EventTypeFormScreen extends ConsumerStatefulWidget {
  const EventTypeFormScreen.create({super.key}) : eventTypeId = null;

  const EventTypeFormScreen.edit({required this.eventTypeId, super.key});

  final String? eventTypeId;

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
  static const _colors = <int>[
    0xFFE91E63,
    0xFFB39DDB,
    0xFF7CB342,
    0xFFFF7043,
    0xFF42A5F5,
    0xFFAB47BC,
    0xFF26A69A,
    0xFFFFA726,
  ];

  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  late final String _id;
  EventTypeIcon _icon = EventTypeIcon.calendar;
  int _colorValue = _colors.first;
  bool _reportRequired = false;
  Set<String> _indicatorKeys = <String>{};
  bool _loading = false;
  bool _saving = false;

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
    if (type == null || type.isSystem) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _labelController.text = type.label;
      _durationController.text = type.defaultDurationMinutes.toString();
      _icon = type.icon;
      _colorValue = type.colorValue;
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
    return Scaffold(
      appBar: AppBar(
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
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
                    DropdownButtonFormField<EventTypeIcon>(
                      initialValue: _icon,
                      decoration: const InputDecoration(labelText: 'Icon'),
                      items: <DropdownMenuItem<EventTypeIcon>>[
                        for (final icon in EventTypeIcon.values)
                          DropdownMenuItem(value: icon, child: Text(icon.name)),
                      ],
                      onChanged: (value) => setState(() => _icon = value!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _colorValue,
                      decoration: const InputDecoration(labelText: 'Color'),
                      items: <DropdownMenuItem<int>>[
                        for (final color in _colors)
                          DropdownMenuItem(
                            value: color,
                            child: Row(
                              children: <Widget>[
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Color(color),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '#${color.toRadixString(16).substring(2).toUpperCase()}',
                                ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _colorValue = value!),
                    ),
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
                      'Life Indicator mappings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Choose None, one, or several explicitly. Names are never '
                      'used to guess a mapping.',
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
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('save-custom-event-type'),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final saved = await ref
        .read(eventTypeControllerProvider.notifier)
        .saveCustomType(
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
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop(true);
    }
  }
}
