import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/presentation/assigned_event_type_draft_screen.dart';
import 'package:rmplanner/features/indicators/application/indicator_providers.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class IndicatorEditScreen extends ConsumerStatefulWidget {
  const IndicatorEditScreen({
    required this.indicatorKey,
    required this.periodStart,
    super.key,
  });

  final String indicatorKey;
  final PlannerDate periodStart;

  @override
  ConsumerState<IndicatorEditScreen> createState() =>
      _IndicatorEditScreenState();
}

final class _IndicatorEditScreenState
    extends ConsumerState<IndicatorEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _indicatorController = TextEditingController();
  LifeIndicatorSummary? _indicator;
  EventType? _eventType;
  Object? _error;
  var _loading = true;
  var _saving = false;

  /// Current live presentation label for the linked Event Type (manual
  /// override, otherwise the Goal title). Null when the slot has no valid
  /// live Goal occupant — then the field is disabled.
  String? _linkedDisplayLabel;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final period = IndicatorPeriod(
      start: widget.periodStart,
      end: widget.periodStart.addDays(6),
    );
    try {
      final indicator = await ref
          .read(homeIndicatorControllerProvider.notifier)
          .readDetail(widget.indicatorKey, period);
      final eventType = await ref
          .read(eventTypeControllerProvider.notifier)
          .exactTypeForIndicator(widget.indicatorKey);
      if (!mounted) {
        return;
      }
      if (indicator == null || eventType == null) {
        setState(() {
          _loading = false;
          _error = StateError('The linked WLI Event Type was not found.');
        });
        return;
      }
      _indicatorController.text = indicator.summary.label;
      setState(() {
        _indicator = indicator.summary;
        _eventType = eventType;
        _loading = false;
      });
      unawaited(_loadLinkedLabel(eventType));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  /// Resolves the CURRENT live presentation label freshly from repositories:
  /// manual override for the live Goal, otherwise the Goal title. A raw
  /// canonical label is never shown for a valid live Goal; a slot without a
  /// valid live occupant disables the linked-name field.
  Future<void> _loadLinkedLabel(EventType eventType) async {
    try {
      final slot = CanonicalGoalSlot.tryByEventTypeKey(eventType.stableKey);
      if (slot == null || slot.indicatorKey != widget.indicatorKey) {
        return;
      }
      final profileId = ref.read(goalProfileIdProvider);
      final bindings = await ref
          .read(goalRepositoryProvider)
          .readLiveEventTypeBindings(profileId);
      final binding = bindings[slot.slotIndex];
      if (!mounted) {
        return;
      }
      setState(() {
        _linkedDisplayLabel = binding?.displayLabel;
      });
    } on Object {
      if (mounted) {
        setState(() => _linkedDisplayLabel = null);
      }
    }
  }

  @override
  void dispose() {
    _indicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: InternalAppBar(title: Text('Edit Indicator')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _indicator == null || _eventType == null) {
      return Scaffold(
        appBar: InternalAppBar(title: const Text('Edit Indicator')),
        body: Center(
          child: Text(
            _error == null
                ? 'Indicator unavailable.'
                : 'Unable to edit this indicator.',
          ),
        ),
      );
    }
    final hasLiveLinkedType = _linkedDisplayLabel != null;
    return Scaffold(
      appBar: InternalAppBar(
        title: const Text('Edit Indicator'),
        actions: <Widget>[
          FilledButton(
            key: const Key('save-indicator-names'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: <Widget>[
              Text(
                'WLI title and Event Type name are independent display labels. '
                'Their stable IDs and reporting relationship stay unchanged.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('indicator-display-name-field'),
                controller: _indicatorController,
                decoration: const InputDecoration(labelText: 'Life Goal title'),
                textInputAction: TextInputAction.next,
                validator: _requiredLabel,
              ),
              const SizedBox(height: 16),
              // Bounded UI (chosen): the linked Event Type name is no longer
              // a free text field saved through the raw rename path. It is a
              // ListTile showing the current live presentation alias with an
              // explicit Edit button opening the separate presentation
              // editor, so the indicator label save and the presentation
              // save remain explicit and independent.
              ListTile(
                key: const Key('event-type-display-name-field'),
                contentPadding: EdgeInsets.zero,
                title: Text('Linked Event Type name'),
                subtitle: Text(
                  hasLiveLinkedType
                      ? _linkedDisplayLabel!
                      : 'No active Goal is linked right now.',
                ),
                trailing: TextButton(
                  key: const Key('edit-linked-event-type'),
                  onPressed: hasLiveLinkedType && !_saving
                      ? () => unawaited(_openPresentationEditor())
                      : null,
                  child: const Text('Edit'),
                ),
                enabled: hasLiveLinkedType,
              ),
              const SizedBox(height: 20),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.lock_outline),
                title: Text('Relationship locked'),
                subtitle: Text(
                  'The first six Event Types remain linked and report-required.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredLabel(String? value) {
    return value == null || value.trim().isEmpty ? 'Enter a name.' : null;
  }

  Future<void> _openPresentationEditor() async {
    final type = _eventType;
    if (type == null) {
      return;
    }
    final committed = await showLiveGoalPresentationEditor(
      context,
      ref,
      eventTypeStableKey: type.stableKey,
    );
    if (!mounted) {
      return;
    }
    if (committed) {
      // Refresh the shown alias from freshly resolved live state.
      await _loadLinkedLabel(type);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final indicatorLabel = _indicatorController.text.trim();
    setState(() => _saving = true);
    try {
      await ref
          .read(homeIndicatorControllerProvider.notifier)
          .renameIndicator(
            indicatorKey: widget.indicatorKey,
            label: indicatorLabel,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The name was not saved. Active display names must be unique.',
            ),
          ),
        );
      }
    }
  }
}
