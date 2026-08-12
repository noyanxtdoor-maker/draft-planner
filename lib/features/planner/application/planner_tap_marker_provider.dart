import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';

/// Transient generic Event placeholder shown immediately when the user taps a
/// Planner time, before the Event Type selector appears (Delta 4.2D). It holds
/// no database state and is cleared when the selector is canceled or an Event
/// Type is selected (the type-specific provisional draft then takes over).
final class PlannerTapMarker {
  const PlannerTapMarker({
    required this.date,
    required this.startMinute,
    required this.endMinute,
  });

  final PlannerDate date;
  final int startMinute;
  final int endMinute;
}

final plannerTapMarkerProvider =
    NotifierProvider<PlannerTapMarkerController, PlannerTapMarker?>(
      PlannerTapMarkerController.new,
    );

final class PlannerTapMarkerController extends Notifier<PlannerTapMarker?> {
  @override
  PlannerTapMarker? build() => null;

  void show({
    required PlannerDate date,
    required int startMinute,
    required int defaultDurationMinutes,
  }) {
    final endMinute = (startMinute + defaultDurationMinutes)
        .clamp(kPlannerCivilDayStartMinute, kPlannerCivilDayEndMinute)
        .toInt();
    state = PlannerTapMarker(
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  void clear() {
    state = null;
  }
}
