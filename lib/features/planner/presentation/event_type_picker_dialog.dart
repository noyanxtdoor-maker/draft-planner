import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/widgets/anchored_top_bar_popup.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_resolver.dart';

sealed class EventTypePickerSelection {
  const EventTypePickerSelection();
}

final class EventTypePickerEvent extends EventTypePickerSelection {
  const EventTypePickerEvent(this.eventType);

  final EventType eventType;
}

final class EventTypePickerTask extends EventTypePickerSelection {
  const EventTypePickerTask();
}

Future<EventTypePickerSelection?> showEventTypePicker({
  required BuildContext context,
  required WidgetRef ref,
  String? recommendedEventTypeId,
  String? recommendedIndicatorKey,
  Set<String>? allowedStableKeys,
  bool includeTask = true,
}) async {
  final controller = ref.read(eventTypeControllerProvider.notifier);
  await controller.load();
  if (!context.mounted) {
    return null;
  }

  var recommendedId = recommendedEventTypeId;
  if (recommendedId == null && recommendedIndicatorKey != null) {
    recommendedId = (await controller.exactTypeForIndicator(
      recommendedIndicatorKey,
    ))?.id;
  }
  if (!context.mounted) {
    return null;
  }

  final state = ref.read(eventTypeControllerProvider);
  if (state.message != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.message!)));
    return null;
  }
  final types = _orderedPickerTypes(
    state.eventTypes,
    recommendedId,
    allowedStableKeys: allowedStableKeys,
  );
  return showDialog<EventTypePickerSelection>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    useSafeArea: false,
    builder: (dialogContext) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final topOffset = media.padding.top + kToolbarHeight + 13;
          // Delta 4.2D restores the last known-good Next Transfer selector
          // width. Filtering and selection semantics remain unchanged.
          final cardWidth = math.min(347.0, constraints.maxWidth - 32);
          final cardHeight = math.max(
            1.0,
            math.min(672.0, constraints.maxHeight - topOffset - 16),
          );
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: topOffset),
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: _EventTypePickerSheet(
                  eventTypes: types,
                  recommendedEventTypeId: recommendedId,
                  eventColorsByTypeId: state.resolvedEventColorsByTypeId,
                  includeTask: includeTask,
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Opens the compact, text-only Event Type menu used by the shared form.
/// The large selector remains the entry flow's source picker; this anchored
/// menu is deliberately a separate presentation so changing a type in an
/// existing form does not replace the form with another card hierarchy.
Future<EventType?> showEventTypeDropdown({
  required BuildContext context,
  required WidgetRef ref,
  required GlobalKey anchorKey,
  String? selectedEventTypeId,
  String? recommendedIndicatorKey,
}) async {
  final fieldContext = anchorKey.currentContext;
  final fieldBox = fieldContext?.findRenderObject() as RenderBox?;
  if (fieldBox == null || !fieldBox.hasSize) {
    return null;
  }
  final controller = ref.read(eventTypeControllerProvider.notifier);
  await controller.load();
  if (!context.mounted) {
    return null;
  }

  var recommendedId = selectedEventTypeId;
  if (recommendedId == null && recommendedIndicatorKey != null) {
    recommendedId = (await controller.exactTypeForIndicator(
      recommendedIndicatorKey,
    ))?.id;
  }
  if (!context.mounted) {
    return null;
  }

  final state = ref.read(eventTypeControllerProvider);
  if (state.message != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.message!)));
    return null;
  }
  if (!context.mounted) {
    return null;
  }
  final types = _orderedPickerTypes(
    state.eventTypes,
    recommendedId,
    targetOrder: false,
  );
  EventType? selected;
  await showAnchoredTopBarPopup(
    context: context,
    triggerKey: anchorKey,
    width: fieldBox.size.width,
    maxHeight: 336,
    topGap: 5,
    borderRadius: 5,
    builder: (popupContext) => SingleChildScrollView(
      key: const Key('event-type-dropdown-scroll'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final type in types)
            SizedBox(
              height: 48,
              child: InkWell(
                key: Key('event-type-dropdown-option-${type.stableKey}'),
                onTap: () {
                  selected = type;
                  anchoredTopBarPopupController.dismiss();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: type.id == selectedEventTypeId
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (type.id == selectedEventTypeId)
                        const Icon(Icons.check, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  return selected;
}

List<EventType> _orderedPickerTypes(
  List<EventType> types,
  String? recommendedId, {
  bool targetOrder = true,
  Set<String>? allowedStableKeys,
}) {
  final mappedOrder = <String, int>{
    for (
      var index = 0;
      index < SystemEventTypeKeys.approvedCreationOrder.length;
      index += 1
    )
      SystemEventTypeKeys.approvedCreationOrder[index]: index,
  };
  final ordered =
      types
          .where(
            (type) =>
                type.isCreationVisible &&
                (allowedStableKeys == null ||
                    allowedStableKeys.contains(type.stableKey)),
          )
          .toList()
        ..sort((left, right) {
          if (targetOrder &&
              left.id == recommendedId &&
              right.id != recommendedId) {
            return -1;
          }
          if (targetOrder &&
              right.id == recommendedId &&
              left.id != recommendedId) {
            return 1;
          }
          final leftMapped = mappedOrder[left.stableKey];
          final rightMapped = mappedOrder[right.stableKey];
          if (leftMapped != null || rightMapped != null) {
            if (leftMapped == null) {
              return 1;
            }
            if (rightMapped == null) {
              return -1;
            }
            return leftMapped.compareTo(rightMapped);
          }
          final position = left.position.compareTo(right.position);
          return position == 0 ? left.label.compareTo(right.label) : position;
        });
  return ordered;
}

final class _EventTypePickerSheet extends StatelessWidget {
  const _EventTypePickerSheet({
    required this.eventTypes,
    required this.recommendedEventTypeId,
    required this.eventColorsByTypeId,
    required this.includeTask,
  });

  final List<EventType> eventTypes;
  final String? recommendedEventTypeId;
  final Map<String, EventColorPreference> eventColorsByTypeId;
  final bool includeTask;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('event-type-picker'),
      color: AppTheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
            child: SizedBox(
              height: 28,
              child: Text(
                'Select Event Type',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('event-type-picker-scroll'),
              child: eventTypes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text('No active Event Types are available.'),
                    )
                  : Column(
                      key: const Key('event-type-picker-list'),
                      children: <Widget>[
                        for (final type in eventTypes)
                          _buildEventTypeRow(context, type),
                        if (includeTask) _buildTaskRow(context),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 40, bottom: 46),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('event-type-picker-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                  foregroundColor: AppTheme.rose,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.rose,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTypeRow(BuildContext context, EventType type) {
    final recommended = type.id == recommendedEventTypeId;
    return Semantics(
      button: true,
      label: '${type.label} Event Type${recommended ? ', Recommended' : ''}',
      child: InkWell(
        key: Key('event-type-option-${type.stableKey}'),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: () => Navigator.of(context).pop(EventTypePickerEvent(type)),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Row(
              children: <Widget>[
                Container(
                  key: Key('event-type-icon-${type.stableKey}'),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: PlannerEventColorResolver.accentColorForType(
                      type,
                      eventColorsByTypeId,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 24 / 17,
                      fontWeight: recommended
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (recommended)
                  SizedBox(
                    key: Key('event-type-recommended-${type.stableKey}'),
                    width: 0,
                    height: 0,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Task entry',
      child: InkWell(
        key: const Key('event-type-option-task'),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        onTap: () => Navigator.of(context).pop(const EventTypePickerTask()),
        child: const SizedBox(
          height: 44,
          child: Padding(
            padding: EdgeInsets.only(left: 26),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFF2E9E0),
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 22, height: 22),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Task',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 24 / 17,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
