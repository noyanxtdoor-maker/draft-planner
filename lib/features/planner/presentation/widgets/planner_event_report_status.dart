import 'package:flutter/material.dart';

import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_report_status_icons.dart';

/// The four selectable reporting statuses for report-required elapsed
/// Calendar Events, shared by the Planner Event block badge and the
/// Calendar Event detail status row.
///
/// The mapping is the locked VS-08 final-polish contract, with the Planner
/// Polish Delta 2 label corrections applied:
///
///   Unreported          → [!] exclamation, muted amber/warning;
///   Did Not Attempt     → [○] circle, neutral gray;
///   Missed - Attempted  → [／] slash, muted rose/coral;
///   Completed           → [✓] check, success green.
///
/// Delta 2 locks the user-facing outcome vocabulary for both Contact and
/// generic Events (Contact: Unreported / Did Not Attempt / Missed —
/// Attempted / Completed; generic: Unreported / Missed / Completed), so the
/// single [completed] kind is the only success state — there is no separate
/// 'Contacted' kind to avoid duplicated semantics.
///
/// Selection is never communicated by color alone: the Event block badge is
/// display-only (its Semantics label announces the state) and the detail
/// controls pair the icon with a filled-versus-outline treatment.
enum PlannerReportStatusKind {
  unreported,
  didNotAttempt,
  missedAttempted,
  completed,
  backup,
  linked,
}

abstract final class PlannerEventReportStatus {
  /// Muted amber warning for Unreported. Restrained (never neon): the
  /// Correction Pack replaces the shared bright warning token with a
  /// low-saturation amber that reads on the dark surface.
  static const Color unreportedColor = Color(0xFFE2BE6E);

  /// Neutral gray for Did Not Attempt.
  static const Color didNotAttemptColor = Color(0xFF9CA0A6);

  /// Muted rose/coral for Missed - Attempted.
  static const Color missedAttemptedColor = Color(0xFFE27386);

  /// Muted success green for Completed/Contacted.
  static const Color completedColor = Color(0xFF86CC7B);

  /// Neutral badge tint for non-report block affordances (backup/linked).
  static const Color neutralBadgeColor = Color(0xFFB9BEC4);

  static IconData iconFor(PlannerReportStatusKind kind) {
    return switch (kind) {
      PlannerReportStatusKind.unreported => Icons.error_outline,
      PlannerReportStatusKind.didNotAttempt => Icons.remove_circle_outline,
      PlannerReportStatusKind.missedAttempted => Icons.block_outlined,
      PlannerReportStatusKind.completed => Icons.check_circle_outline,
      PlannerReportStatusKind.backup => Icons.layers_outlined,
      PlannerReportStatusKind.linked => Icons.task_alt_outlined,
    };
  }

  static Color colorFor(PlannerReportStatusKind kind) {
    return switch (kind) {
      PlannerReportStatusKind.unreported => unreportedColor,
      PlannerReportStatusKind.didNotAttempt => didNotAttemptColor,
      PlannerReportStatusKind.missedAttempted => missedAttemptedColor,
      PlannerReportStatusKind.completed => completedColor,
      PlannerReportStatusKind.backup ||
      PlannerReportStatusKind.linked => neutralBadgeColor,
    };
  }

  static String labelFor(
    PlannerReportStatusKind kind, {
    bool isContactEvent = false,
  }) {
    return switch (kind) {
      PlannerReportStatusKind.unreported => 'Unreported',
      PlannerReportStatusKind.didNotAttempt => 'Did Not Attempt',
      // Planner Polish Delta 2: 'Missed' for generic non-Contact Events,
      // 'Missed — Attempted' for Contact Events.  Both read the same stored
      // partial outcome, so history is untouched.  The completed outcome is
      // 'Completed' for BOTH Contact and generic Events (Delta 2 final
      // status matrix); there is no separate 'Contacted' label.
      PlannerReportStatusKind.missedAttempted =>
        isContactEvent ? 'Missed — Attempted' : 'Missed',
      PlannerReportStatusKind.completed => 'Completed',
      PlannerReportStatusKind.backup => 'Backup Appointment',
      PlannerReportStatusKind.linked => 'Linked Tasks',
    };
  }

  /// Resolve the block badge kind for a Planner Event item.
  ///
  /// The visibility rules are locked:
  ///   - Report Required OFF            → no badge;
  ///   - Report Required ON + future    → no badge, no Unreported warning;
  ///   - Report Required ON + elapsed
  ///     + no saved status              → Unreported [!];
  ///   - Report Required ON + elapsed
  ///     + saved status                 → the corresponding status icon.
  /// Non-report block affordances (Backup stripes, linked Tasks) keep their
  /// compact icons only when the Event does not carry a report status.
  static PlannerReportStatusKind? kindFor({
    required PlannerEventState state,
    required bool requiresReport,
    required bool awaitingReport,
    required bool isBackupAppointment,
    required bool hasLinkedTasks,
    required bool isContactEvent,
  }) {
    if (awaitingReport && requiresReport) {
      return PlannerReportStatusKind.unreported;
    }
    if (requiresReport && state == PlannerEventState.completedHappened) {
      // Delta 2 final matrix: the success state is 'Completed' for both
      // Contact and generic Events.  The parameter is retained for the
      // badge label context but never changes the success kind.
      return PlannerReportStatusKind.completed;
    }
    if (requiresReport && state == PlannerEventState.partiallyCompleted) {
      return PlannerReportStatusKind.missedAttempted;
    }
    if (requiresReport && state == PlannerEventState.didNotHappen) {
      return PlannerReportStatusKind.didNotAttempt;
    }
    if (isBackupAppointment) {
      return PlannerReportStatusKind.backup;
    }
    if (hasLinkedTasks) {
      return PlannerReportStatusKind.linked;
    }
    return null;
  }

  /// Resolve the detail-control kind from a saved [CalendarEventStatus].
  static PlannerReportStatusKind kindForStatus(
    CalendarEventStatus status, {
    required bool isContactEvent,
  }) {
    return switch (status) {
      CalendarEventStatus.scheduled => PlannerReportStatusKind.unreported,
      // Delta 2 final matrix: the success state is 'Completed' for both
      // Contact and generic Events.
      CalendarEventStatus.completedHappened =>
        PlannerReportStatusKind.completed,
      CalendarEventStatus.partiallyCompleted =>
        PlannerReportStatusKind.missedAttempted,
      CalendarEventStatus.didNotHappen => PlannerReportStatusKind.didNotAttempt,
      CalendarEventStatus.cancelled ||
      CalendarEventStatus.rescheduled => PlannerReportStatusKind.unreported,
    };
  }
}

/// Compact circular status badge shown at the right of an eligible Planner
/// Event block. Display-only: it never opens reporting directly, and its
/// [Semantics] label announces the state so selection is not color-only.
///
/// The badge is a thin adapter over the canonical sheet-accurate
/// [PlannerReportStatusIcon] component: amber [!], gray [−], rose [／], and
/// green [✓] are painted as scalable vector geometry (no raster sheet, no
/// emoji, no Material glyph), matching the new authoritative icon sheet.
class PlannerEventStatusBadge extends StatelessWidget {
  const PlannerEventStatusBadge({
    required this.kind,
    this.diameter = 20,
    this.isContactEvent = false,
    super.key,
  });

  final PlannerReportStatusKind kind;
  final double diameter;

  /// Contact Events announce 'Missed - Attempted'; generic Events announce
  /// 'Missed' (Planner Polish Delta 2).
  final bool isContactEvent;

  @override
  Widget build(BuildContext context) {
    return PlannerReportStatusIcon(
      kind: kind,
      size: diameter,
      style: PlannerReportStatusIconStyle.canonical,
      isContactEvent: isContactEvent,
    );
  }
}
