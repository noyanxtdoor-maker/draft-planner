import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/assigned_event_type_draft.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/presentation/widgets/event_color_picker_components.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// Draft-only Assigned Event Type editor (value-only child route).
///
/// Visual arrangement mirrors EventTypeFormScreen's fixed-assignment mode:
/// InternalAppBar, Name field, EventTypeColorPanel, assigned Goal text, and
/// the existing button styles. ONLY name/color controls exist here — no
/// duration, icon, mapping, or report controls, and no Save path: Apply pops
/// an [AssignedEventTypeDraftResult], Cancel/system back pops null and
/// discards every child change. No repository or controller is ever called.
final class AssignedEventTypeDraftScreen extends StatefulWidget {
  const AssignedEventTypeDraftScreen({
    required this.initialDraft,
    required this.goalTitle,
    super.key,
  });

  /// Parent-owned draft the child initializes from (name from the effective
  /// parent draft; color from the draft's current effective pair).
  final AssignedEventTypeDraft initialDraft;

  /// Current parent Goal title, shown as the assigned Goal and used by the
  /// "Use Goal name" preview semantics.
  final String goalTitle;

  @override
  State<AssignedEventTypeDraftScreen> createState() =>
      _AssignedEventTypeDraftScreenState();
}

/// Global-settings entry point for one LIVE canonical row (Event Types
/// settings and the Indicator editor's linked-name editor).
///
/// Resolves the live Goal binding, stored override, and effective color
/// FRESHLY from repositories (never from cached UI provider state), opens
/// the same draft-only child editor, and commits an explicit change
/// atomically through [EventTypeRepository.saveLiveGoalPresentation] — name
/// override and changed slot color only, no Goal row/target write, no raw
/// type rename. The live occupant is re-checked inside the save; an
/// archive/replacement race rejects without writing and the caller keeps
/// its editor open.
///
/// Returns true when a change was committed or nothing changed; false when
/// the editor was cancelled or the save was rejected.
Future<bool> showLiveGoalPresentationEditor(
  BuildContext context,
  WidgetRef ref, {
  required String eventTypeStableKey,
}) async {
  final slot = CanonicalGoalSlot.tryByEventTypeKey(eventTypeStableKey);
  if (slot == null) {
    return false;
  }
  final profileId = ref.read(goalProfileIdProvider);
  try {
    final bindings = await ref
        .read(goalRepositoryProvider)
        .readLiveEventTypeBindings(profileId);
    final binding = bindings[slot.slotIndex];
    if (binding == null || binding.title.trim().isEmpty) {
      if (context.mounted) {
        _showUnavailable(context);
      }
      return false;
    }
    final repository = ref.read(eventTypeRepositoryProvider);
    final overrides = await repository.readGoalEventTypeNameOverrides(
      profileId,
    );
    final storedEntry = overrides[binding.goalId];
    final validStored =
        storedEntry != null &&
            storedEntry.eventTypeStableKey == eventTypeStableKey
        ? storedEntry
        : null;
    final colors = await repository.readEventColorPreferences(
      profileId: profileId,
    );
    final effectiveColor =
        colors[eventTypeStableKey] ??
        PlannerEventColorDefaults.pmgStableKeyDefaults[eventTypeStableKey] ??
        PlannerEventColorDefaults.other;

    final draft = AssignedEventTypeDraft(
      expectedSlotIndex: slot.slotIndex,
      expectedEventTypeId: slot.eventTypeId,
      expectedStableKey: slot.eventTypeStableKey,
      originalNameMode: validStored == null
          ? AssignedEventTypeNameMode.auto
          : AssignedEventTypeNameMode.manual,
      originalNameOverride: validStored?.name,
      currentNameMode: validStored == null
          ? AssignedEventTypeNameMode.auto
          : AssignedEventTypeNameMode.manual,
      currentNameOverride: validStored?.name,
      nameDirty: false,
      originalColor: effectiveColor,
      changedColor: null,
      colorDirty: false,
    );

    if (!context.mounted) {
      return false;
    }
    final result = await Navigator.of(context).push<
        AssignedEventTypeDraftResult>(
      MaterialPageRoute<AssignedEventTypeDraftResult>(
        builder: (_) => AssignedEventTypeDraftScreen(
          initialDraft: draft,
          goalTitle: binding.title,
        ),
      ),
    );
    if (result == null) {
      return false;
    }

    String? nameOverride;
    var clearNameOverride = false;
    var nameEdited = false;
    if (result.action == AssignedEventTypeDraftActionResult.useGoalName) {
      clearNameOverride = true;
      nameEdited = true;
    } else if (result.nameEdited) {
      final trimmed = (result.nameText ?? '').trim();
      if (trimmed.isEmpty) {
        return true;
      }
      nameOverride = trimmed;
      nameEdited = true;
    }
    final changedColor = result.changedColor;
    if (!nameEdited && changedColor == null) {
      // Nothing changed: no repository call, no preference write.
      return true;
    }
    if (!context.mounted) {
      return false;
    }
    try {
      await repository.saveLiveGoalPresentation(
        profileId: profileId,
        expectedSlotIndex: slot.slotIndex,
        expectedGoalId: binding.goalId,
        expectedEventTypeId: slot.eventTypeId,
        expectedStableKey: slot.eventTypeStableKey,
        originalValues: LiveGoalPresentationOriginals(
          observedNameOverride: validStored,
          observedColor: effectiveColor,
        ),
        patch: LiveGoalPresentationPatch(
          nameOverride: nameOverride,
          clearNameOverride: clearNameOverride,
          colorPreference: changedColor,
        ),
      );
      return true;
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return false;
    }
  } on Object {
    if (context.mounted) {
      _showUnavailable(context);
    }
    return false;
  }
}

void _showUnavailable(BuildContext context) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Event Type unavailable'),
    ),
  );
}

final class _AssignedEventTypeDraftScreenState
    extends State<AssignedEventTypeDraftScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late Color _accent;
  bool _nameEdited = false;

  AssignedEventTypeDraft get _draft => widget.initialDraft;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _initialNameText());
    _accent = Color(_currentPair.accentArgb);
  }

  /// Child Name initializes from the effective parent draft (MANUAL override,
  /// otherwise the Goal title). Programmatic initialization is NOT manual
  /// intent — only a real user edit sets _nameEdited.
  String _initialNameText() {
    if (_draft.currentNameMode == AssignedEventTypeNameMode.manual) {
      return _draft.currentNameOverride ?? '';
    }
    return widget.goalTitle.trim();
  }

  /// The color pair the child edits from: the draft's pending change when
  /// present, otherwise the original persisted pair. Manual surfaces are
  /// preserved when the accent is unchanged via the panel's own policy.
  EventColorPreference get _currentPair =>
      _draft.changedColor ?? _draft.originalColor;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _apply() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final accentArgb = _accent.toARGB32();
    final changed = accentArgb != _currentPair.accentArgb;
    final next = changed
        ? EventColorPreference(
            accentArgb: accentArgb,
            // Surface follows the accent whenever the accent changes; the
            // untouched pair is forwarded verbatim so a manual surface can
            // never be silently re-derived.
            surfaceArgb: PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
              accentArgb: accentArgb,
              currentAccentArgb: _currentPair.accentArgb,
              currentSurfaceArgb: _currentPair.surfaceArgb,
            ),
          )
        : null;
    Navigator.of(context).pop(
      AssignedEventTypeDraftResult.applied(
        nameEdited: _nameEdited,
        nameText: _nameController.text,
        changedColor: next,
      ),
    );
  }

  void _useGoalName() {
    Navigator.of(context).pop(
      AssignedEventTypeDraftResult.useGoalName(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Edit Event Type')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: InternalScreen.pagePadding,
            children: <Widget>[
              TextFormField(
                key: const Key('custom-event-type-label'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => _nameEdited = true,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Enter a name' : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('assigned-event-type-use-goal-name'),
                  onPressed: _useGoalName,
                  child: Text('Use Goal name (${widget.goalTitle.trim()})'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Assigned Goal',
                style: InternalScreen.sectionHeading,
              ),
              const SizedBox(height: 4),
              Text(
                'Events of this type contribute toward this Goal. '
                'The assignment is fixed.',
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 14,
                  height: 20 / 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text('This assignment cannot be changed.'),
              const SizedBox(height: 6),
              Text('Assigned Goal: ${widget.goalTitle.trim()}'),
              const SizedBox(height: 10),
              EventTypeColorPanel(
                key: const Key('event-type-color-panel'),
                eventTypeLabel: _nameController.text.trim().isEmpty
                    ? 'Event Type'
                    : _nameController.text.trim(),
                currentPreference: _currentPair,
                initialColor: _accent,
                onColorChanged: (color) =>
                    setState(() => _accent = color),
                peerAccentColors: const <int>[],
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('assigned-event-type-apply'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _apply,
                child: const Text('Apply'),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('assigned-event-type-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
