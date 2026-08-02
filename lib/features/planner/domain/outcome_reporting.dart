import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:uuid/uuid.dart';

enum OutcomeSourceType { task, event, manual }

enum OutcomeReportStatus { draft, submitted, superseded }

enum OutcomeKind { completedHappened, partiallyCompleted, didNotHappen }

enum ActivityLedgerEntryType { contribution, reversal }

final class IndicatorValue {
  const IndicatorValue({
    required this.scaledValue,
    required this.scale,
    required this.unit,
  });

  final int scaledValue;
  final int scale;
  final String unit;

  String get displayValue {
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

abstract final class IndicatorUnitPolicy {
  static const int maximumScaledValue = 9223372036854775807;

  static int allowedScale(String unit) {
    return switch (unit) {
      'count' || 'minutes' || 'boolean' || 'milestone' || 'streak' => 0,
      'hours' => 2,
      _ => 0,
    };
  }

  static void validate(IndicatorValue value) {
    final normalizedUnit = value.unit.trim();
    if (normalizedUnit.isEmpty) {
      throw const OutcomeReportValidationException(
        'A factual value requires an explicit unit.',
      );
    }
    if (value.scaledValue <= 0 || value.scaledValue > maximumScaledValue) {
      throw const OutcomeReportValidationException(
        'A factual value must be a positive supported amount.',
      );
    }
    final allowed = allowedScale(normalizedUnit);
    if (value.scale < 0 || value.scale > allowed) {
      throw OutcomeReportValidationException(
        '$normalizedUnit values allow at most $allowed decimal places.',
      );
    }
  }
}

final class OutcomeReportSource {
  const OutcomeReportSource({
    required this.type,
    required this.sourceId,
    required this.label,
    required this.activityDate,
    this.eventId,
    this.occurrenceId,
    this.originalDate,
    this.eventTypeLabel,
    this.isContactEvent = false,
  });

  final OutcomeSourceType type;
  final String sourceId;
  final String label;
  final PlannerDate activityDate;
  final String? eventId;
  final String? occurrenceId;
  final PlannerDate? originalDate;
  final String? eventTypeLabel;
  final bool isContactEvent;

  String get slotKey {
    return switch (type) {
      OutcomeSourceType.task => 'task:$sourceId',
      OutcomeSourceType.event => 'event:$eventId:$occurrenceId',
      OutcomeSourceType.manual => 'manual:$sourceId',
    };
  }

  OutcomeReportSource normalized() {
    final normalizedLabel = label.trim();
    if (sourceId.trim().isEmpty || normalizedLabel.isEmpty) {
      throw const OutcomeReportValidationException(
        'A report requires a stable source and factual label.',
      );
    }
    if (type == OutcomeSourceType.event &&
        ((eventId?.trim().isEmpty ?? true) ||
            (occurrenceId?.trim().isEmpty ?? true) ||
            originalDate == null)) {
      throw const OutcomeReportValidationException(
        'An Event report requires a stable occurrence identity.',
      );
    }
    return OutcomeReportSource(
      type: type,
      sourceId: sourceId.trim(),
      label: normalizedLabel,
      activityDate: activityDate,
      eventId: _normalizeOptional(eventId),
      occurrenceId: _normalizeOptional(occurrenceId),
      originalDate: originalDate,
      eventTypeLabel: _normalizeOptional(eventTypeLabel),
      isContactEvent: isContactEvent,
    );
  }
}

final class ContributionDraft {
  const ContributionDraft({
    required this.ruleKey,
    required this.indicatorKey,
    required this.value,
  });

  final String ruleKey;
  final String indicatorKey;
  final IndicatorValue value;

  ContributionDraft normalized() {
    final normalizedRule = ruleKey.trim();
    final normalizedIndicator = indicatorKey.trim();
    if (normalizedRule.isEmpty || normalizedIndicator.isEmpty) {
      throw const OutcomeReportValidationException(
        'A contribution requires explicit rule and indicator identities.',
      );
    }
    IndicatorUnitPolicy.validate(value);
    return ContributionDraft(
      ruleKey: normalizedRule,
      indicatorKey: normalizedIndicator,
      value: IndicatorValue(
        scaledValue: value.scaledValue,
        scale: value.scale,
        unit: value.unit.trim(),
      ),
    );
  }
}

final class OutcomeReportDraft {
  const OutcomeReportDraft({
    required this.id,
    required this.source,
    required this.activityDate,
    this.outcome,
    this.factualValue,
    this.privateNotes,
    this.correctsReportId,
    this.correctionReason,
    this.contributions = const <ContributionDraft>[],
    this.allowUnstructuredPartial = false,
  });

  final String id;
  final OutcomeReportSource source;
  final PlannerDate activityDate;
  final OutcomeKind? outcome;
  final IndicatorValue? factualValue;
  final String? privateNotes;
  final String? correctsReportId;
  final String? correctionReason;
  final List<ContributionDraft> contributions;

  /// Event Current Status writes intentionally do not open a factual-value
  /// form. Task and manual reports keep the stricter structured partial
  /// requirement by leaving this disabled.
  final bool allowUnstructuredPartial;

  OutcomeReportDraft normalized({required bool forSubmission}) {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw const OutcomeReportValidationException(
        'A report requires a stable UUID before it can be saved.',
      );
    }
    final normalizedSource = source.normalized();
    final normalizedContributions = contributions
        .map((item) => item.normalized())
        .toList(growable: false);
    final duplicateRules = <String>{};
    for (final contribution in normalizedContributions) {
      if (!duplicateRules.add(contribution.ruleKey)) {
        throw const OutcomeReportValidationException(
          'A qualifying rule can contribute only once per report.',
        );
      }
    }

    final normalizedReason = _normalizeOptional(correctionReason);
    final normalizedCorrects = _normalizeOptional(correctsReportId);
    if (normalizedCorrects != null &&
        !Uuid.isValidUUID(fromString: normalizedCorrects)) {
      throw const OutcomeReportValidationException(
        'A correction requires a stable original report identity.',
      );
    }

    if (forSubmission) {
      final selectedOutcome = outcome;
      if (selectedOutcome == null) {
        throw const OutcomeReportValidationException(
          'Choose what factually happened before submitting.',
        );
      }
      if (selectedOutcome == OutcomeKind.partiallyCompleted &&
          !allowUnstructuredPartial) {
        final value = factualValue;
        if (value == null) {
          throw const OutcomeReportValidationException(
            'Partial completion requires a structured factual value.',
          );
        }
        IndicatorUnitPolicy.validate(value);
      }
      if (selectedOutcome == OutcomeKind.didNotHappen &&
          normalizedContributions.isNotEmpty) {
        throw const OutcomeReportValidationException(
          'Did Not Attempt cannot create a contribution.',
        );
      }
    }

    return OutcomeReportDraft(
      id: id,
      source: normalizedSource,
      activityDate: activityDate,
      outcome: outcome,
      factualValue: factualValue,
      privateNotes: _normalizeOptional(privateNotes),
      correctsReportId: normalizedCorrects,
      correctionReason: normalizedReason,
      contributions: normalizedContributions,
      allowUnstructuredPartial: allowUnstructuredPartial,
    );
  }
}

final class OutcomeReport {
  const OutcomeReport({
    required this.id,
    required this.profileId,
    required this.source,
    required this.status,
    required this.activityDate,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.outcome,
    this.factualValue,
    this.privateNotes,
    this.correctsReportId,
    this.correctionReason,
    this.submittedAtUtc,
    this.contributionCount = 0,
    this.draftContributions = const <ContributionDraft>[],
  });

  final String id;
  final String profileId;
  final OutcomeReportSource source;
  final OutcomeReportStatus status;
  final OutcomeKind? outcome;
  final PlannerDate activityDate;
  final IndicatorValue? factualValue;
  final String? privateNotes;
  final String? correctsReportId;
  final String? correctionReason;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? submittedAtUtc;
  final int contributionCount;
  final List<ContributionDraft> draftContributions;

  bool get affectedActual => contributionCount > 0;
}

final class ActivityLedgerEntry {
  const ActivityLedgerEntry({
    required this.id,
    required this.profileId,
    required this.sourceReportId,
    required this.type,
    required this.indicatorKey,
    required this.value,
    required this.activityDate,
    required this.ruleKey,
    required this.recordedAtUtc,
    this.reversalOfEntryId,
    this.replacesEntryId,
    this.isEffective = true,
  });

  final String id;
  final String profileId;
  final String sourceReportId;
  final ActivityLedgerEntryType type;
  final String indicatorKey;
  final IndicatorValue value;
  final PlannerDate activityDate;
  final String ruleKey;
  final DateTime recordedAtUtc;
  final String? reversalOfEntryId;
  final String? replacesEntryId;
  final bool isEffective;
}

final class IndicatorActual {
  const IndicatorActual({required this.indicatorKey, required this.value});

  final String indicatorKey;
  final IndicatorValue value;
}

final class LedgerProjectionAudit {
  const LedgerProjectionAudit({
    required this.isConsistent,
    required this.issueCount,
  });

  final bool isConsistent;
  final int issueCount;
}

final class ReportSubmissionResult {
  const ReportSubmissionResult({
    required this.report,
    required this.entries,
    required this.unchanged,
  });

  final OutcomeReport report;
  final List<ActivityLedgerEntry> entries;
  final bool unchanged;
}

abstract final class OutcomeReportIdentity {
  static const Uuid _uuid = Uuid();

  static String ledgerEntry({
    required String reportId,
    required String ruleKey,
    required ActivityLedgerEntryType type,
  }) {
    return _uuid.v5(
      Namespace.url.value,
      'com.nexttransfer.rmplanner:ledger:$reportId:$ruleKey:${type.name}',
    );
  }

  static String reversalEntry({
    required String reportId,
    required String originalEntryId,
  }) {
    return _uuid.v5(
      Namespace.url.value,
      'com.nexttransfer.rmplanner:ledger-reversal:'
      '$reportId:$originalEntryId',
    );
  }
}

final class OutcomeReportValidationException implements Exception {
  const OutcomeReportValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String? _normalizeOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
