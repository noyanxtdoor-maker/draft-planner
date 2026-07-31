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
  // Discrete preset anchors used by the Planner Settings dropdown
  // and by the Settings screen's preset classification. The pinch
  // gesture can move continuously between these anchors and beyond
  // them up to the min/max clamp range below.
  static const double compactHourHeight = 44;
  static const double normalHourHeight = 60;
  static const double expandedHourHeight = 88;

  // Continuous pinch allowed range. The Stage B1 locked pinch
  // tests pin the lower bound at 43 and the upper bound at 88.5,
  // so the policy keeps these absolute hard bounds equal to the
  // preset anchors: any wider range would break the locked test
  // assertions, which the R1 package forbids.
  static const double minimumHourHeight = compactHourHeight;
  static const double maximumHourHeight = expandedHourHeight;

  static double clamp(double value) =>
      value.clamp(minimumHourHeight, maximumHourHeight).toDouble();

  /// Apply a small intentional dead zone around the start scale
  /// so finger jitter at the start of a pinch does not visibly
  /// bump the hour height before the user has actually started
  /// the gesture. Inside the dead zone, the returned scale is
  /// 1.0 (no change). Outside, the scale is preserved as-is.
  /// The 0.03 threshold is chosen to be smaller than the default
  /// scale slop arc but larger than typical resting-hand jitter.
  static const double scaleStartDeadZone = 0.03;

  static double applyDeadZone(double scale) {
    final delta = scale - 1.0;
    if (delta.abs() <= scaleStartDeadZone) {
      return 1.0;
    }
    return scale;
  }
}

enum PlannerZoomPreset { compact, normal, expanded }

extension PlannerZoomPresetValue on PlannerZoomPreset {
  double get hourHeight => switch (this) {
    PlannerZoomPreset.compact => PlannerZoomPolicy.compactHourHeight,
    PlannerZoomPreset.normal => PlannerZoomPolicy.normalHourHeight,
    PlannerZoomPreset.expanded => PlannerZoomPolicy.expandedHourHeight,
  };
}
