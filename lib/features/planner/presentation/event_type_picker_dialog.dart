import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

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
    barrierColor: Colors.black.withValues(alpha: 0.62),
    useSafeArea: false,
    builder: (dialogContext) => Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: 1,
        heightFactor: 0.72,
        child: _EventTypePickerSheet(
          eventTypes: types,
          recommendedEventTypeId: recommendedId,
        ),
      ),
    ),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Text(
                      'Select Event Type',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Flexible(
                    child: eventTypes.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Text('No active Event Types are available.'),
                          )
                        : ListView.builder(
                            key: const Key('event-type-picker-list'),
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                            itemCount: eventTypes.length,
                            itemBuilder: (context, index) {
                              final type = eventTypes[index];
                              final recommended =
                                  type.id == recommendedEventTypeId;
                              return Semantics(
                                button: true,
                                label:
                                    '${type.label} Event Type'
                                    '${recommended ? ', Recommended' : ''}',
                                child: InkWell(
                                  key: Key(
                                    'event-type-option-${type.stableKey}',
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context).pop(type),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Container(
                                          width: 18,
                                          height: 18,
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
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
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
