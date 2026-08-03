import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_preview.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_resolver.dart';
import 'package:rmplanner/features/settings/presentation/event_color_picker_dialog.dart';

const double _eventPreviewWidth = 183;
const double _eventRowHeight = 44;
const double _eventPreviewToControlsGap = 12;
const double _eventControlsWidth = 150;

final class PlannerEventColorsScreen extends ConsumerStatefulWidget {
  const PlannerEventColorsScreen({super.key});

  @override
  ConsumerState<PlannerEventColorsScreen> createState() =>
      _PlannerEventColorsScreenState();
}

final class _PlannerEventColorsScreenState
    extends ConsumerState<PlannerEventColorsScreen> {
  final Map<String, EventColorPreference> _liveEventColors =
      <String, EventColorPreference>{};
  final Map<String, int> _liveGroupColors = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventTypeControllerProvider);
    final controller = ref.read(eventTypeControllerProvider.notifier);
    final eventTypes = _orderedEventTypes(state.eventTypes);
    return Scaffold(
      appBar: AppBar(title: const Text('Colors')),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                key: const Key('planner-event-colors-list'),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                children: <Widget>[
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
                  const _ColorsSectionHeader(
                    key: Key('planner-event-colors-events-section'),
                    label: 'Events',
                  ),
                  const SizedBox(height: 14),
                  for (final type in eventTypes) ...<Widget>[
                    _EventColorRow(
                      key: Key('event-color-row-${type.stableKey}'),
                      type: type,
                      preference:
                          _liveEventColors[type.stableKey] ??
                          _preferenceFor(state, type),
                      onAccent: () => _editEventColor(
                        context,
                        controller,
                        type,
                        EventColorRole.accent,
                      ),
                      onSurface: () => _editEventColor(
                        context,
                        controller,
                        type,
                        EventColorRole.surface,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      key: const Key('planner-event-colors-restore-defaults'),
                      onPressed: eventTypes.isEmpty
                          ? null
                          : () => _confirmRestoreEvents(context, controller),
                      child: const Text('Restore Event Defaults'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _ColorsSectionHeader(
                    key: Key('planner-event-colors-groups-section'),
                    label: 'Contact Group Colors',
                  ),
                  const SizedBox(height: 10),
                  for (final group in ContactGroupDefaults.ordered) ...<Widget>[
                    _GroupColorRow(
                      group: group,
                      color: Color(
                        _liveGroupColors[group.id] ??
                            state.groupColors[group.id] ??
                            group.defaultColorArgb,
                      ),
                      onPressed: () =>
                          _editGroupColor(context, controller, group),
                    ),
                    const SizedBox(height: 2),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      key: const Key('planner-group-colors-restore-defaults'),
                      onPressed: () =>
                          _confirmRestoreGroups(context, controller),
                      child: const Text('Restore Group Defaults'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static List<EventType> _orderedEventTypes(List<EventType> types) {
    final order = <String, int>{
      for (
        var index = 0;
        index < SystemEventTypeKeys.approvedCreationOrder.length;
        index += 1
      )
        SystemEventTypeKeys.approvedCreationOrder[index]: index,
    };
    final result = types.where((type) => type.isCreationVisible).toList();
    result.sort((left, right) {
      final leftOrder = order[left.stableKey];
      final rightOrder = order[right.stableKey];
      if (leftOrder != null && rightOrder != null) {
        return leftOrder.compareTo(rightOrder);
      }
      if (leftOrder != null) {
        return -1;
      }
      if (rightOrder != null) {
        return 1;
      }
      final position = left.position.compareTo(right.position);
      return position == 0 ? left.label.compareTo(right.label) : position;
    });
    return result;
  }

  static EventColorPreference _preferenceFor(
    EventTypeState state,
    EventType type,
  ) {
    return PlannerEventColorResolver.preferenceForType(type, state.eventColors);
  }

  Future<void> _editEventColor(
    BuildContext context,
    EventTypeController controller,
    EventType type,
    EventColorRole role,
  ) async {
    final state = ref.read(eventTypeControllerProvider);
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
      onChanged: (color) {
        if (!mounted) {
          return;
        }
        setState(() {
          _liveEventColors[type.stableKey] = role == EventColorRole.accent
              ? EventColorPreference(
                  accentArgb: color.toARGB32(),
                  surfaceArgb: current.surfaceArgb,
                )
              : EventColorPreference(
                  accentArgb: current.accentArgb,
                  surfaceArgb: color.toARGB32(),
                );
        });
      },
    );
    if (!mounted) {
      return;
    }
    if (chosen == null) {
      setState(() {
        _liveEventColors.remove(type.stableKey);
      });
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
    if (mounted) {
      setState(() {
        _liveEventColors.remove(type.stableKey);
      });
    }
  }

  Future<void> _editGroupColor(
    BuildContext context,
    EventTypeController controller,
    ContactGroup group,
  ) async {
    final state = ref.read(eventTypeControllerProvider);
    final current = Color(
      _liveGroupColors[group.id] ??
          state.groupColors[group.id] ??
          group.defaultColorArgb,
    );
    final chosen = await showPlannerEventColorPicker(
      context: context,
      eventTypeLabel: group.label,
      role: EventColorRole.accent,
      initialColor: current,
      otherColor: Theme.of(context).scaffoldBackgroundColor,
      onChanged: (color) {
        if (!mounted) {
          return;
        }
        setState(() {
          _liveGroupColors[group.id] = color.toARGB32();
        });
      },
    );
    if (!mounted) {
      return;
    }
    if (chosen == null) {
      setState(() {
        _liveGroupColors.remove(group.id);
      });
      return;
    }
    await controller.saveContactGroupColor(
      groupId: group.id,
      colorArgb: chosen.toARGB32(),
    );
    if (mounted) {
      setState(() {
        _liveGroupColors.remove(group.id);
      });
    }
  }

  Future<void> _confirmRestoreEvents(
    BuildContext context,
    EventTypeController controller,
  ) async {
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('planner-event-colors-restore-dialog'),
        title: const Text('Restore Event color defaults?'),
        content: const Text(
          'Your custom Event colors will be replaced with the approved '
          'defaults. Group colors will not change.',
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
      if (mounted) {
        setState(_liveEventColors.clear);
      }
    }
  }

  Future<void> _confirmRestoreGroups(
    BuildContext context,
    EventTypeController controller,
  ) async {
    final restore = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('planner-group-colors-restore-dialog'),
        title: const Text('Restore Group color defaults?'),
        content: const Text(
          'Your custom Contact Group colors will be replaced with the '
          'approved defaults. Event colors will not change.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('planner-group-colors-restore-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('planner-group-colors-restore-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (restore == true && context.mounted) {
      await controller.restoreContactGroupColorDefaults();
      if (mounted) {
        setState(_liveGroupColors.clear);
      }
    }
  }
}

final class _ColorsSectionHeader extends StatelessWidget {
  const _ColorsSectionHeader({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }
}

final class _EventColorRow extends StatelessWidget {
  const _EventColorRow({
    required this.type,
    required this.preference,
    required this.onAccent,
    required this.onSurface,
    super.key,
  });

  final EventType type;
  final EventColorPreference preference;
  final VoidCallback onAccent;
  final VoidCallback onSurface;

  @override
  Widget build(BuildContext context) {
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
          final previewWidth =
              (constraints.maxWidth -
                      _eventControlsWidth -
                      _eventPreviewToControlsGap)
                  .clamp(0.0, _eventPreviewWidth)
                  .toDouble();
          return SizedBox(
            height: _eventRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: previewWidth,
                  height: 40,
                  child: PlannerEventColorPreview(
                    eventType: type,
                    preference: preference,
                  ),
                ),
                const SizedBox(width: _eventPreviewToControlsGap),
                controls,
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
      width: _eventControlsWidth,
      height: _eventRowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
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
      width: 70,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            child: Semantics(
              button: true,
              label: '$typeLabel $roleLabel color, current value $value',
              onTap: onPressed,
              child: InkWell(
                key: Key('event-color-swatch-$typeLabel-$roleLabel'),
                onTap: onPressed,
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
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
          ),
          Positioned(
            left: 30,
            top: 0,
            child: Semantics(
              button: true,
              label: 'Edit $typeLabel $roleLabel color',
              onTap: onPressed,
              child: Tooltip(
                message: 'Edit $typeLabel $roleLabel color',
                child: InkWell(
                  key: Key('event-color-pencil-$typeLabel-$roleLabel'),
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: Icon(Icons.edit_outlined, size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _GroupColorRow extends StatelessWidget {
  const _GroupColorRow({
    required this.group,
    required this.color,
    required this.onPressed,
  });

  final ContactGroup group;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${group.label} group color, current value ${colorHex(color)}',
      child: SizedBox(
        key: Key('planner-group-color-row-${group.id}'),
        height: 52,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                group.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontSize: 16),
              ),
            ),
            InkWell(
              key: Key('group-color-swatch-${group.id}'),
              onTap: onPressed,
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const SizedBox(width: 28, height: 28),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                key: Key('group-color-edit-${group.id}'),
                tooltip: 'Edit ${group.label} group color',
                onPressed: onPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
