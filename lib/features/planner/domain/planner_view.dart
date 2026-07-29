enum PlannerPresentation { schedule, day, week, tasks, awaitingReports }

final class PlannerContentFilters {
  const PlannerContentFilters({
    required this.events,
    required this.backupEvents,
    required this.tasks,
    required this.completedTasks,
  });

  const PlannerContentFilters.defaults()
    : events = true,
      backupEvents = true,
      tasks = true,
      completedTasks = false;

  final bool events;
  final bool backupEvents;
  final bool tasks;
  final bool completedTasks;

  PlannerContentFilters copyWith({
    bool? events,
    bool? backupEvents,
    bool? tasks,
    bool? completedTasks,
  }) {
    final nextTasks = tasks ?? this.tasks;
    return PlannerContentFilters(
      events: events ?? this.events,
      backupEvents: backupEvents ?? this.backupEvents,
      tasks: nextTasks,
      completedTasks: nextTasks ? completedTasks ?? this.completedTasks : false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlannerContentFilters &&
      other.events == events &&
      other.backupEvents == backupEvents &&
      other.tasks == tasks &&
      other.completedTasks == completedTasks;

  @override
  int get hashCode => Object.hash(events, backupEvents, tasks, completedTasks);
}

enum PlannerSelectionKind { event, task }

final class PlannerSelectionId {
  const PlannerSelectionId({required this.kind, required this.id});

  final PlannerSelectionKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is PlannerSelectionId && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

abstract final class PlannerZoomPolicy {
  static const double compactHourHeight = 44;
  static const double normalHourHeight = 60;
  static const double expandedHourHeight = 88;
  static const double minimumHourHeight = compactHourHeight;
  static const double maximumHourHeight = expandedHourHeight;

  static double clamp(double value) =>
      value.clamp(minimumHourHeight, maximumHourHeight).toDouble();
}

enum PlannerZoomPreset { compact, normal, expanded }

extension PlannerZoomPresetValue on PlannerZoomPreset {
  double get hourHeight => switch (this) {
    PlannerZoomPreset.compact => PlannerZoomPolicy.compactHourHeight,
    PlannerZoomPreset.normal => PlannerZoomPolicy.normalHourHeight,
    PlannerZoomPreset.expanded => PlannerZoomPolicy.expandedHourHeight,
  };
}
