import 'package:rmplanner/features/planner/domain/planner_date.dart';

enum IndicatorProjectionState { current, stale, rebuilding, failed }

final class IndicatorPeriod {
  const IndicatorPeriod({required this.start, required this.end});

  final PlannerDate start;
  final PlannerDate end;

  factory IndicatorPeriod.currentWeek(PlannerDate today) {
    final mondayOffset = today.asLocalDate.weekday - DateTime.monday;
    final start = today.addDays(-mondayOffset);
    return IndicatorPeriod(start: start, end: start.addDays(6));
  }

  bool contains(PlannerDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  String get key => start.iso8601;

  @override
  bool operator ==(Object other) {
    return other is IndicatorPeriod && start == other.start && end == other.end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

enum IndicatorGoalPeriodType { daily, weekly, monthly }

/// A local-calendar goal period.  The serialized key is deliberately based
/// on the period type and start date so midnight/month transitions never
/// overwrite another period.
final class IndicatorGoalPeriod {
  const IndicatorGoalPeriod({
    required this.type,
    required this.start,
    required this.end,
  });

  final IndicatorGoalPeriodType type;
  final PlannerDate start;
  final PlannerDate end;

  factory IndicatorGoalPeriod.daily(PlannerDate date) {
    return IndicatorGoalPeriod(
      type: IndicatorGoalPeriodType.daily,
      start: date,
      end: date,
    );
  }

  factory IndicatorGoalPeriod.weekly(PlannerDate date) {
    final mondayOffset = date.asLocalDate.weekday - DateTime.monday;
    final start = date.addDays(-mondayOffset);
    return IndicatorGoalPeriod(
      type: IndicatorGoalPeriodType.weekly,
      start: start,
      end: start.addDays(6),
    );
  }

  factory IndicatorGoalPeriod.monthly(PlannerDate date) {
    final start = PlannerDate(year: date.year, month: date.month, day: 1);
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    final end = PlannerDate.fromDateTime(
      nextMonth.subtract(const Duration(days: 1)),
    );
    return IndicatorGoalPeriod(
      type: IndicatorGoalPeriodType.monthly,
      start: start,
      end: end,
    );
  }

  IndicatorPeriod get indicatorPeriod =>
      IndicatorPeriod(start: start, end: end);

  String get key => '${type.name}:${start.iso8601}';

  @override
  bool operator ==(Object other) {
    return other is IndicatorGoalPeriod &&
        type == other.type &&
        start == other.start &&
        end == other.end;
  }

  @override
  int get hashCode => Object.hash(type, start, end);
}

final class IndicatorAmount {
  const IndicatorAmount({
    required this.scaledValue,
    required this.scale,
    required this.unit,
  });

  final int scaledValue;
  final int scale;
  final String unit;

  String get display {
    if (scale == 0) {
      return '$scaledValue';
    }
    final negative = scaledValue < 0;
    final digits = scaledValue.abs().toString().padLeft(scale + 1, '0');
    final split = digits.length - scale;
    return '${negative ? '-' : ''}${digits.substring(0, split)}.'
        '${digits.substring(split)}';
  }
}

final class IndicatorTarget {
  const IndicatorTarget.notSet() : value = null;
  const IndicatorTarget.explicit(this.value);

  final IndicatorAmount? value;

  bool get isSet => value != null;
  bool get isExplicitZero => value?.scaledValue == 0;
  String get display => value?.display ?? 'Not set';
}

final class ScheduledIndicatorSource {
  const ScheduledIndicatorSource({
    required this.sourceType,
    required this.sourceId,
    required this.label,
    required this.date,
    required this.value,
    required this.explanation,
  });

  final String sourceType;
  final String sourceId;
  final String label;
  final PlannerDate date;
  final IndicatorAmount value;
  final String explanation;
}

final class IndicatorContributionHistoryItem {
  const IndicatorContributionHistoryItem({
    required this.entryId,
    required this.reportId,
    required this.sourceLabel,
    required this.activityDate,
    required this.value,
    required this.isReversal,
  });

  final String entryId;
  final String reportId;
  final String sourceLabel;
  final PlannerDate activityDate;
  final IndicatorAmount value;
  final bool isReversal;
}

final class LifeIndicatorSummary {
  const LifeIndicatorSummary({
    required this.key,
    required this.label,
    required this.unit,
    required this.position,
    required this.actual,
    required this.target,
    required this.scheduledPotential,
    required this.scheduledSources,
    required this.projectionState,
    this.failureMessage,
  });

  final String key;
  final String label;
  final String unit;
  final int position;
  final IndicatorAmount actual;
  final IndicatorTarget target;
  final IndicatorAmount scheduledPotential;
  final List<ScheduledIndicatorSource> scheduledSources;
  final IndicatorProjectionState projectionState;
  final String? failureMessage;
}

final class HomeIndicatorSnapshot {
  const HomeIndicatorSnapshot({
    required this.period,
    required this.indicators,
    required this.overdueTaskCount,
    required this.awaitingReportCount,
    this.nextTempleVisit,
    this.currentWeekPlanned = false,
    this.monthlyTempleActual,
    this.monthlyTempleTarget,
    this.dailyJobApplications,
  });

  final IndicatorPeriod period;
  final List<LifeIndicatorSummary> indicators;
  final int overdueTaskCount;
  final int awaitingReportCount;
  final PlannerDate? nextTempleVisit;
  final bool currentWeekPlanned;
  final IndicatorAmount? monthlyTempleActual;
  final IndicatorTarget? monthlyTempleTarget;
  final IndicatorGoalSnapshot? dailyJobApplications;

  bool get hasPartialFailure => indicators.any(
    (indicator) => indicator.projectionState == IndicatorProjectionState.failed,
  );
}

final class IndicatorGoalSnapshot {
  const IndicatorGoalSnapshot({
    required this.indicatorKey,
    required this.period,
    required this.actual,
    required this.target,
  });

  final String indicatorKey;
  final IndicatorGoalPeriod period;
  final IndicatorAmount actual;
  final IndicatorTarget target;
}

final class IndicatorGoalRevisionDraft {
  const IndicatorGoalRevisionDraft({
    required this.id,
    required this.operationId,
    required this.indicatorKey,
    required this.period,
    required this.value,
  });

  final String id;
  final String operationId;
  final String indicatorKey;
  final IndicatorGoalPeriod period;
  final IndicatorAmount? value;
}

final class IndicatorDetail {
  const IndicatorDetail({
    required this.summary,
    required this.period,
    required this.contributionHistory,
  });

  final LifeIndicatorSummary summary;
  final IndicatorPeriod period;
  final List<IndicatorContributionHistoryItem> contributionHistory;
}

final class IndicatorTargetRevisionDraft {
  const IndicatorTargetRevisionDraft({
    required this.id,
    required this.operationId,
    required this.indicatorKey,
    required this.period,
    required this.value,
  });

  final String id;
  final String operationId;
  final String indicatorKey;
  final IndicatorPeriod period;
  final IndicatorAmount? value;
}

final class IndicatorTargetRevision {
  const IndicatorTargetRevision({
    required this.id,
    required this.target,
    required this.createdAtUtc,
  });

  final String id;
  final IndicatorTarget target;
  final DateTime createdAtUtc;
}

final class ScheduledPotentialRule {
  const ScheduledPotentialRule({
    required this.indicatorKey,
    required this.value,
  });

  static const String _prefix = 'life-indicator';

  final String indicatorKey;
  final IndicatorAmount value;

  static ScheduledPotentialRule? tryParse(String? raw) {
    final parts = raw?.split(':');
    if (parts == null || parts.length != 5 || parts.first != _prefix) {
      return null;
    }
    final scaled = int.tryParse(parts[2]);
    final scale = int.tryParse(parts[3]);
    if (parts[1].isEmpty ||
        scaled == null ||
        scaled <= 0 ||
        scale == null ||
        scale < 0 ||
        parts[4].isEmpty) {
      return null;
    }
    return ScheduledPotentialRule(
      indicatorKey: parts[1],
      value: IndicatorAmount(scaledValue: scaled, scale: scale, unit: parts[4]),
    );
  }

  String encode() =>
      '$_prefix:$indicatorKey:${value.scaledValue}:${value.scale}:'
      '${value.unit}';
}
