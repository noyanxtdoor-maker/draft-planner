import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class CalendarEventCreationContext {
  const CalendarEventCreationContext({
    required this.source,
    required this.destinationPath,
    required this.date,
    this.startMinute,
    this.indicatorKey,
    this.recommendedEventTypeId,
  });

  final String source;
  final String destinationPath;
  final PlannerDate date;
  final int? startMinute;
  final String? indicatorKey;
  final String? recommendedEventTypeId;

  Uri destinationFor(EventType eventType) {
    final queryParameters = <String, String>{
      'date': date.iso8601,
      'eventType': eventType.id,
    };
    final capturedStartMinute = startMinute;
    if (capturedStartMinute != null) {
      queryParameters['startMinute'] = '$capturedStartMinute';
    }
    final capturedIndicatorKey = indicatorKey;
    if (capturedIndicatorKey != null) {
      queryParameters['indicator'] = capturedIndicatorKey;
    }
    return Uri(path: destinationPath, queryParameters: queryParameters);
  }
}

Future<T?> launchCalendarEventCreation<T>(
  BuildContext context,
  WidgetRef ref,
  CalendarEventCreationContext creationContext,
) async {
  final selected = await showEventTypePicker(
    context: context,
    ref: ref,
    recommendedEventTypeId: creationContext.recommendedEventTypeId,
    recommendedIndicatorKey: creationContext.indicatorKey,
  );
  if (selected == null || !context.mounted) {
    return null;
  }
  return context.push<T>(creationContext.destinationFor(selected).toString());
}

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
    builder: (dialogContext) => _EventTypePickerDialog(
      eventTypes: types,
      recommendedEventTypeId: recommendedId,
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

final class _EventTypePickerDialog extends StatelessWidget {
  const _EventTypePickerDialog({
    required this.eventTypes,
    required this.recommendedEventTypeId,
  });

  final List<EventType> eventTypes;
  final String? recommendedEventTypeId;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    return Dialog(
      key: const Key('event-type-picker'),
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.outline),
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: viewport.height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Select Event Type',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.outline),
              Flexible(
                child: eventTypes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No active Event Types are available.'),
                      )
                    : ListView.separated(
                        key: const Key('event-type-picker-list'),
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: eventTypes.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          indent: 58,
                          color: AppTheme.outline,
                        ),
                        itemBuilder: (context, index) {
                          final type = eventTypes[index];
                          final recommended = type.id == recommendedEventTypeId;
                          return Semantics(
                            button: true,
                            label:
                                '${type.label} Event Type'
                                '${recommended ? ', Recommended' : ''}',
                            child: ListTile(
                              key: Key('event-type-option-${type.stableKey}'),
                              minTileHeight: 56,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 2,
                              ),
                              leading: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Color(type.colorValue),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              title: Text(
                                type.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: recommended
                                  ? Container(
                                      key: Key(
                                        'event-type-recommended-${type.stableKey}',
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.rose.withValues(
                                          alpha: 0.14,
                                        ),
                                        border: Border.all(
                                          color: AppTheme.rose,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Recommended',
                                        style: TextStyle(
                                          color: AppTheme.rose,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () => Navigator.of(context).pop(type),
                            ),
                          );
                        },
                      ),
              ),
              const Divider(height: 1, color: AppTheme.outline),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
  }
}
