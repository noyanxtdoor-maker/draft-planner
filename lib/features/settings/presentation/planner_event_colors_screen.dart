import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_preview.dart';
import 'package:rmplanner/features/settings/presentation/event_color_picker_dialog.dart';

final class PlannerEventColorsScreen extends ConsumerWidget {
  const PlannerEventColorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventTypeControllerProvider);
    final controller = ref.read(eventTypeControllerProvider.notifier);
    final eventTypes = state.eventTypes
        .where((type) => !type.isArchived)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Planner Event Colors')),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('planner-event-colors-list'),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: <Widget>[
                  Text(
                    'Planner Event Colors',
                    key: const Key('planner-event-colors-heading'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose a muted accent and background pair for each '
                    'Event Type. Changes apply to current and future Planner '
                    'Events of that type.',
                  ),
                  const SizedBox(height: 16),
                  if (state.message != null) ...<Widget>[
                    MaterialBanner(
                      content: Text(state.message!),
                      actions: <Widget>[
                        TextButton(
                          onPressed: controller.clearMessage,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  for (final type in eventTypes) ...<Widget>[
                    _EventColorRow(
                      type: type,
                      preference: _preferenceFor(state, type),
                      onAccent: () => _editColor(
                        context,
                        controller,
                        type,
                        EventColorRole.accent,
                      ),
                      onSurface: () => _editColor(
                        context,
                        controller,
                        type,
                        EventColorRole.surface,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      key: const Key('planner-event-colors-restore-defaults'),
                      onPressed: eventTypes.isEmpty
                          ? null
                          : () => _confirmRestore(context, controller),
                      child: const Text(
                        'Restore Defaults',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static EventColorPreference _preferenceFor(
    EventTypeState state,
    EventType type,
  ) {
    return state.eventColors[type.stableKey] ??
        PlannerEventColorDefaults.forEventType(type);
  }

  Future<void> _editColor(
    BuildContext context,
    EventTypeController controller,
    EventType type,
    EventColorRole role,
  ) async {
    final state = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(eventTypeControllerProvider);
    final current = _preferenceFor(state, type);
    final chosen = await showPlannerEventColorPicker(
      context: context,
      eventTypeLabel: type.label,
      role: role,
      initialColor: Color(
        role == EventColorRole.accent
            ? current.accentArgb
            : current.surfaceArgb,
      ),
      otherColor: Color(
        role == EventColorRole.accent
            ? current.surfaceArgb
            : current.accentArgb,
      ),
    );
    if (chosen == null || !context.mounted) {
      return;
    }
    final updated = role == EventColorRole.accent
        ? EventColorPreference(
            accentArgb: chosen.toARGB32(),
            surfaceArgb: current.surfaceArgb,
          )
        : EventColorPreference(
            accentArgb: current.accentArgb,
            surfaceArgb: chosen.toARGB32(),
          );
    await controller.saveEventColor(type, updated);
  }

  Future<void> _confirmRestore(
    BuildContext context,
    EventTypeController controller,
  ) async {
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('planner-event-colors-restore-dialog'),
        title: const Text('Restore default Event colors?'),
        content: const Text(
          'Your custom Planner Event colors will be replaced with the '
          'original defaults.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('planner-event-colors-restore-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('planner-event-colors-restore-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (restore == true && context.mounted) {
      await controller.restoreEventColorDefaults();
    }
  }
}

final class _EventColorRow extends StatelessWidget {
  const _EventColorRow({
    required this.type,
    required this.preference,
    required this.onAccent,
    required this.onSurface,
  });

  final EventType type;
  final EventColorPreference preference;
  final VoidCallback onAccent;
  final VoidCallback onSurface;

  @override
  Widget build(BuildContext context) {
    final preview = PlannerEventColorPreview(
      eventType: type,
      preference: preference,
    );
    final controls = _EventColorControls(
      type: type,
      preference: preference,
      onAccent: onAccent,
      onSurface: onSurface,
    );
    return Semantics(
      container: true,
      label: '${type.label} Event colors',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canFitSideBySide = constraints.maxWidth >= 326;
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: canFitSideBySide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 230),
                          child: preview,
                        ),
                      ),
                      const SizedBox(width: 8),
                      controls,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      preview,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: controls),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

final class _EventColorControls extends StatelessWidget {
  const _EventColorControls({
    required this.type,
    required this.preference,
    required this.onAccent,
    required this.onSurface,
  });

  final EventType type;
  final EventColorPreference preference;
  final VoidCallback onAccent;
  final VoidCallback onSurface;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _ColorControl(
            key: Key('event-color-accent-${type.stableKey}'),
            roleLabel: 'accent',
            typeLabel: type.label,
            color: Color(preference.accentArgb),
            onPressed: onAccent,
          ),
          _ColorControl(
            key: Key('event-color-surface-${type.stableKey}'),
            roleLabel: 'Event background',
            typeLabel: type.label,
            color: Color(preference.surfaceArgb),
            onPressed: onSurface,
          ),
        ],
      ),
    );
  }
}

final class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.roleLabel,
    required this.typeLabel,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String roleLabel;
  final String typeLabel;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final value = colorHex(color);
    return SizedBox(
      height: 44,
      child: Row(
        children: <Widget>[
          Semantics(
            button: true,
            label: '$typeLabel $roleLabel color, current value $value',
            onTap: onPressed,
            child: InkWell(
              key: Key('event-color-swatch-$typeLabel-$roleLabel'),
              onTap: onPressed,
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              tooltip: 'Edit $typeLabel $roleLabel color',
              onPressed: onPressed,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
