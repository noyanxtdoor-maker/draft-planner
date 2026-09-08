import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final plannerEventCreationDraftProvider =
    NotifierProvider<
      PlannerEventCreationDraftController,
      PlannerEventCreationDraft?
    >(PlannerEventCreationDraftController.new);

final class PlannerEventCreationDraft {
  const PlannerEventCreationDraft({
    required this.id,
    required this.date,
    required this.startMinute,
    required this.endMinute,
    required this.eventTypeId,
    required this.eventTypeLabel,
    required this.eventTypeColorValue,
    this.title = '',
  });

  final String id;
  final PlannerDate date;
  final int startMinute;
  final int endMinute;
  final String eventTypeId;
  final String eventTypeLabel;
  final int eventTypeColorValue;
  final String title;

  PlannerEventCreationDraft copyWith({
    PlannerDate? date,
    int? startMinute,
    int? endMinute,
    EventType? eventType,
    String? title,
  }) {
    return PlannerEventCreationDraft(
      id: id,
      date: date ?? this.date,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      eventTypeId: eventType?.id ?? eventTypeId,
      eventTypeLabel: eventType?.label ?? eventTypeLabel,
      eventTypeColorValue: eventType?.colorValue ?? eventTypeColorValue,
      title: title ?? this.title,
    );
  }
}

final class PlannerEventCreationDraftController
    extends Notifier<PlannerEventCreationDraft?> {
  @override
  PlannerEventCreationDraft? build() => null;

  void begin({
    required String id,
    required PlannerDate date,
    required int startMinute,
    required EventType eventType,
    int? defaultDurationMinutes,
  }) {
    final minimumEnd = (startMinute + 15).clamp(1, 1440).toInt();
    // Delta 4.2R R9: the provisional draft must use the SAME configured
    // default duration as the pre-type tap placeholder. Timeline creation
    // passes the Planner default; all other creation paths keep the Event
    // Type's own default when none is supplied.
    final duration = defaultDurationMinutes ?? eventType.defaultDurationMinutes;
    final endMinute = (startMinute + duration)
        .clamp(minimumEnd, 1440)
        .toInt();
    state = PlannerEventCreationDraft(
      id: id,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      eventTypeId: eventType.id,
      eventTypeLabel: eventType.label,
      eventTypeColorValue: eventType.colorValue,
    );
  }

  void updateTimes({required int startMinute, required int endMinute}) {
    final current = state;
    if (current == null || endMinute <= startMinute) {
      return;
    }
    state = current.copyWith(
      startMinute: startMinute.clamp(0, 1425).toInt(),
      endMinute: endMinute.clamp(15, 1440).toInt(),
    );
  }

  void updateDate(PlannerDate date) {
    final current = state;
    if (current != null) {
      state = current.copyWith(date: date);
    }
  }

  void updateEventType(EventType eventType) {
    final current = state;
    if (current != null) {
      state = current.copyWith(eventType: eventType);
    }
  }

  void updateTitle(String title) {
    final current = state;
    if (current != null && current.title != title) {
      state = current.copyWith(title: title);
    }
  }

  void clear(String id) {
    if (state?.id == id) {
      state = null;
    }
  }

  void clearCurrentAfterLifecycle() {
    scheduleMicrotask(() {
      if (ref.mounted) {
        state = null;
      }
    });
  }
}
