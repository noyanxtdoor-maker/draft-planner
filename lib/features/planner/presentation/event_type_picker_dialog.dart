import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_date_strip.dart';

Future<EventType?> showEventTypePicker({
  required BuildContext context,
  required WidgetRef ref,
  String? recommendedEventTypeId,
  String? recommendedIndicatorKey,
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
  final types = _orderedPickerTypes(state.eventTypes, recommendedId);
  return showDialog<EventType>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    useSafeArea: false,
    builder: (dialogContext) {
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const topGap = 8.0;
              final topOffset =
                  kToolbarHeight + PlannerDateStrip.stripHeight + 2 + topGap;
              final maxHeight = math.max<double>(
                0,
                constraints.maxHeight - topOffset - 16,
              );
              return Padding(
                padding: EdgeInsets.fromLTRB(16, topOffset, 16, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(360, constraints.maxWidth),
                    maxHeight: maxHeight,
                  ),
                  child: _EventTypePickerSheet(
                    eventTypes: types,
                    recommendedEventTypeId: recommendedId,
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

List<EventType> _orderedPickerTypes(
  List<EventType> types,
  String? recommendedId,
) {
  const mappedOrder = <String, int>{
    SystemEventTypeKeys.templeVisit: 0,
    SystemEventTypeKeys.scriptureStudy: 1,
    SystemEventTypeKeys.exercise: 2,
    SystemEventTypeKeys.budgetReview: 3,
    SystemEventTypeKeys.jobApplication: 4,
    SystemEventTypeKeys.meaningfulConnection: 5,
  };
  final ordered = types.where((type) => !type.isArchived).toList()
    ..sort((left, right) {
      if (left.id == recommendedId && right.id != recommendedId) {
        return -1;
      }
      if (right.id == recommendedId && left.id != recommendedId) {
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
  });

  final List<EventType> eventTypes;
  final String? recommendedEventTypeId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Material(
          key: const Key('event-type-picker'),
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: true,
            bottom: true,
            minimum: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              key: const Key('event-type-picker-scroll'),
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text(
                      'Select Event Type',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (eventTypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Text('No active Event Types are available.'),
                    )
                  else
                    ListView.builder(
                      key: const Key('event-type-picker-list'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: eventTypes.length,
                      itemBuilder: (context, index) {
                        final type = eventTypes[index];
                        final recommended = type.id == recommendedEventTypeId;
                        return Semantics(
                          button: true,
                          label:
                              '${type.label} Event Type'
                              '${recommended ? ', Recommended' : ''}',
                          child: InkWell(
                            key: Key('event-type-option-${type.stableKey}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(type),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                              child: Row(
                                children: <Widget>[
                                  Container(
                                    key: Key(
                                      'event-type-icon-${type.stableKey}',
                                    ),
                                    width: 21,
                                    height: 21,
                                    decoration: BoxDecoration(
                                      color: Color(type.colorValue),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      type.label,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (recommended)
                                    Text(
                                      'Recommended',
                                      key: Key(
                                        'event-type-recommended-${type.stableKey}',
                                      ),
                                      style: const TextStyle(
                                        color: AppTheme.rose,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                      child: TextButton(
                        key: const Key('event-type-picker-cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppTheme.rose),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
