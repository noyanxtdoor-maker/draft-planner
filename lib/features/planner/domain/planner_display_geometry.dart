import 'package:flutter/foundation.dart' show immutable;

import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';

/// Delta 4.2R R10: longest logical duration that may receive the display-only
/// readability floor. 15/30/45-minute Events are exactly the short
/// blocks that collapse to unusable slivers at wide zoom-out. The floor is
/// PRESENTATION ONLY: stored duration, drag/resize math, overlap, reporting,
/// and recurrence all keep the exact canonical minutes.
const int kPlannerMaxZoomReadabilityDurationMinutes = 45;

/// Delta 4.2R2 R2-06 (R3-04 corrected): the READABILITY PIXEL THRESHOLD.
/// When a short Event's canonical rendered height (exact duration x
/// pixels-per-minute) drops below this value it switches from EXACT MODE to
/// OVERVIEW MODE (its whole hour row), so there is no intermediate-zoom dead
/// zone where a 15/30/45-minute Event becomes a useless tiny strip. The
/// transition is a pure function of the rendered height, so crossing it
/// during pinch is deterministic (one layout per frame) and never touches
/// stored/logical intervals.
///
/// Delta 4.2R3 R3-04: the owner confirmed the inherited 15px value was
/// physically too low (15/30/45-minute Events still collapsed to tiny strips
/// at intermediate ~80% zoom-out AND at extreme/max zoom). The value is
/// derived from the actual production event-block typography: title 14px /
/// line-height 1.1 (~15.4px), time 13px / 1.1 (~14.3px), inner vertical
/// padding 11px, and the existing density taxonomy that treats <=24px as
/// "veryShort" (title-only). 28px is the smallest stable threshold that:
///   - floors a 15-minute Event at normal zoom (15px) and everywhere below;
///   - floors a 30-minute Event at ~80% zoom-out (24px) and at compact/max
///     zoom-out (22px / ~14.6px);
///   - floors a 45-minute Event at the runtime max zoom-out (~21.75px on a
///     700dp / 24h window);
///   - keeps a 30-minute Event EXACT at normal zoom (30px >= 28) and a
///     45-minute Event EXACT at normal/intermediate zoom (45px / 36px),
///     so the default-zoom look of normal-length blocks is unchanged.
const double kPlannerReadableEventHeightThreshold = 28;

/// Exact display placement derived from the Planner's canonical minute grid.
///
/// Delta 4.2A deliberately has no second visual-time model. Zoom changes only
/// pixels-per-minute: painted top, bottom, height, and horizontal overlap
/// regions always come from the same logical interval used by persistence,
/// drag, resize, conflict, and reporting behavior.
///
/// Delta 4.2R R10 adds ONE display-only exception at the extreme zoom-out end
/// (see [PlannerDisplayGeometry.resolve]): a short Event may occupy its whole
/// hour row so its title/time stay readable. That readability footprint is
/// resolved strictly inside this display layer and is never exposed to the
/// logical domain.
@immutable
final class PlannerDisplayPlacement {
  const PlannerDisplayPlacement({
    required this.event,
    required this.top,
    required this.height,
    required this.column,
    required this.columnCount,
    this.widthFactor,
    this.offsetFactor,
    this.spanStart,
    this.spanCount,
    this.squareTop = false,
    this.squareBottom = false,
  });

  final PlannerCalendarItem event;

  /// Exact clipped top in logical pixels.
  final double top;

  /// Exact clipped temporal height in logical pixels.
  final double height;

  /// Canonical lane (0-based) used for the x position.
  final int column;

  /// Canonical lane count for this logical overlap region.
  final int columnCount;

  /// Optional normalized width/offset for the locked primary/Backup split.
  final double? widthFactor;
  final double? offsetFactor;

  /// Delta 3 local free-space expansion from the canonical logical layout.
  final int? spanStart;
  final int? spanCount;

  /// Delta 4.2R R12: when the Event's rendered bottom is exactly contiguous
  /// with the rendered top of another block (A.end == B.start), the shared
  /// boundary must touch with no decorative rounded-corner notch. These flags
  /// zero the corner radius on the contiguous edge only.
  final bool squareTop;
  final bool squareBottom;

  double get bottom => top + height;
}

abstract final class PlannerDisplayGeometry {
  /// Resolves exact full-day placements for [events].
  ///
  /// [viewportHeight] and [configuredHours] remain in the call contract so
  /// the mounted center timeline and read-only pager previews share one API.
  /// They define the runtime maximum zoom-out hour height (the smallest
  /// height that still fits the configured planning window); at that extreme
  /// the Delta 4.2R R10 readability floor may engage for short Events.
  /// [previewStartMinutes] and [previewEndMinutes] alter only the exact
  /// minute endpoints used to paint a live gesture preview; Delta 4.2B owns
  /// recomputing logical lanes while those endpoints move.
  static List<PlannerDisplayPlacement> resolve({
    required List<PlannerCalendarItem> events,
    required double hourHeight,
    required double viewportHeight,
    required int configuredHours,
    Map<String, int>? previewStartMinutes,
    Map<String, int>? previewEndMinutes,
  }) {
    final timed = events
        .where((event) => event.startLocal != null && event.endLocal != null)
        .toList(growable: false);
    // Delta 4.2R2 R2-06: no global "maximum zoom only" gate. The overview
    // mode is decided per-Event from its OWN canonical rendered height
    // against the readability pixel threshold (see _withDisplayInterval), so
    // there is no intermediate-zoom dead zone. `viewportHeight` and
    // `configuredHours` stay in the contract for the runtime zoom clamp; the
    // display pass itself only needs the live hour height.

    // R4-06: horizontal lanes are owned ONLY by exact logical [start, end)
    // intervals. A live drag/resize preview substitutes its exact preview
    // minutes, but the readability floor must never enter this list: doing so
    // made visually enlarged short Events reserve lanes against neighbors
    // they did not logically overlap.
    final layoutEvents = <PlannerCalendarItem>[
      for (final event in timed)
        _withPreviewInterval(
          event,
          startMinute: previewStartMinutes?[event.id],
          endMinute: previewEndMinutes?[event.id],
        ),
    ];
    // The display list is a separate, presentation-only projection. It may
    // enlarge a short block to its readable hour footprint, but its minutes
    // are used only for y/height and contiguous-corner painting below.
    final displayEvents = <PlannerCalendarItem>[
      for (final event in layoutEvents)
        _withDisplayInterval(
          event,
          startMinute: event.startLocal!.hour * 60 + event.startLocal!.minute,
          endMinute: plannerEndMinuteOfDay(event.startLocal!, event.endLocal!),
          hourHeight: hourHeight,
        ),
    ];
    final originalById = <String, PlannerCalendarItem>{
      for (final event in timed) event.id: event,
    };
    final canonical = PlannerTimelineLayout.arrange(
      layoutEvents,
      hourHeight: hourHeight,
    );
    if (canonical.isEmpty) {
      return const <PlannerDisplayPlacement>[];
    }

    final displayById = <String, PlannerCalendarItem>{
      for (final event in displayEvents) event.id: event,
    };
    final geometry = <String, PlannerTimelineEventGeometry>{};
    for (final event in displayEvents) {
      final startMinute =
          event.startLocal!.hour * 60 + event.startLocal!.minute;
      final endMinute = plannerEndMinuteOfDay(
        event.startLocal!,
        event.endLocal!,
      );
      geometry[event.id] = PlannerTimelineGeometry.event(
        startMinute: startMinute,
        endMinute: endMinute,
        visibleStartMinute: kPlannerCivilDayStartMinute,
        visibleEndMinute: kPlannerCivilDayEndMinute,
        hourHeight: hourHeight,
      );
    }

    // Delta 4.2R R12: detect truly contiguous rendered boundaries
    // (A.end == B.start on the display grid, with horizontally overlapping
    // rectangles) so both blocks square their corners on the shared edge and
    // no decorative rounded-corner notch creates a false vertical gap.
    final squareTopOf = <String, bool>{};
    final squareBottomOf = <String, bool>{};
    for (final placement in canonical) {
      final displayEvent = displayById[placement.event.id]!;
      final endMinute = plannerEndMinuteOfDay(
        displayEvent.startLocal!,
        displayEvent.endLocal!,
      );
      for (final other in canonical) {
        if (identical(placement, other)) {
          continue;
        }
        final otherDisplayEvent = displayById[other.event.id]!;
        final otherStartMinute =
            otherDisplayEvent.startLocal!.hour * 60 +
            otherDisplayEvent.startLocal!.minute;
        if (endMinute == otherStartMinute &&
            _horizontallyOverlapping(placement, other)) {
          squareBottomOf[placement.event.id] = true;
          squareTopOf[other.event.id] = true;
        }
      }
    }

    return <PlannerDisplayPlacement>[
      for (final placement in canonical)
        PlannerDisplayPlacement(
          event: originalById[placement.event.id]!,
          top: geometry[placement.event.id]!.top,
          height: geometry[placement.event.id]!.height,
          column: placement.column,
          columnCount: placement.columnCount,
          widthFactor: placement.widthFactor,
          offsetFactor: placement.offsetFactor,
          spanStart: placement.spanStart,
          spanCount: placement.spanCount,
          squareTop: squareTopOf[placement.event.id] ?? false,
          squareBottom: squareBottomOf[placement.event.id] ?? false,
        ),
    ];
  }

  static PlannerCalendarItem _withPreviewInterval(
    PlannerCalendarItem event, {
    int? startMinute,
    int? endMinute,
  }) {
    final eventStart = event.startLocal!.hour * 60 + event.startLocal!.minute;
    final eventEnd = plannerEndMinuteOfDay(event.startLocal!, event.endLocal!);
    final previewStart = startMinute ?? eventStart;
    final previewEnd = endMinute ?? eventEnd;
    if (previewStart == eventStart && previewEnd == eventEnd) {
      return event;
    }
    return _withMinutes(
      event,
      startMinute: previewStart,
      endMinute: previewEnd,
    );
  }

  /// Whether the two placements' horizontal rectangles overlap. The rendered
  /// x-range is derived from the canonical span (free-space expansion) when
  /// present, otherwise from the base lane, so only blocks that actually
  /// share a vertical boundary region square their corners.
  static bool _horizontallyOverlapping(
    PlannerTimelinePlacement left,
    PlannerTimelinePlacement right,
  ) {
    double leftStart(PlannerTimelinePlacement p) {
      final span = p.spanStart ?? p.column;
      return span / p.columnCount;
    }

    double leftEnd(PlannerTimelinePlacement p) {
      final spanEnd = (p.spanStart ?? p.column) + (p.spanCount ?? 1);
      return spanEnd / p.columnCount;
    }

    return leftStart(left) < leftEnd(right) && leftStart(right) < leftEnd(left);
  }

  static PlannerCalendarItem _withDisplayInterval(
    PlannerCalendarItem event, {
    required int startMinute,
    required int endMinute,
    required double hourHeight,
  }) {
    var displayStart = startMinute;
    var displayEnd = endMinute;
    // Delta 4.2R2 R2-06: OVERVIEW MODE is engaged when this Event's OWN
    // canonical rendered height (exact duration x pixels-per-minute) falls
    // below the readability pixel threshold — regardless of zoom percent.
    // The display interval becomes the whole hour row (start-of-hour ..
    // start-of-hour + 60), which stays visually owned by its own hour and
    // never spills into the neighboring row. EXACT MODE keeps the canonical
    // interval whenever enough pixels exist. The stored/logical interval is
    // never changed: this clone is a strict display/lane input only.
    final canonicalHeight =
        (endMinute - startMinute) *
        PlannerTimelineGeometry.pixelsPerMinute(hourHeight);
    if (canonicalHeight < kPlannerReadableEventHeightThreshold &&
        endMinute - startMinute <= kPlannerMaxZoomReadabilityDurationMinutes) {
      displayStart = (startMinute ~/ 60) * 60;
      displayEnd = displayStart + 60;
    }
    // Clone whenever the resolved (preview / floor) interval differs from the
    // Event's stored minutes: a live drag/resize preview must ALWAYS carry
    // its preview endpoints into the layout pass, even when the floor is
    // inactive. The clone stays a strict layout input and is mapped back to
    // the original domain item before any callback can see it.
    final eventStart = event.startLocal!.hour * 60 + event.startLocal!.minute;
    final eventEnd = plannerEndMinuteOfDay(event.startLocal!, event.endLocal!);
    if (displayStart == eventStart && displayEnd == eventEnd) {
      return event;
    }
    return _withMinutes(
      event,
      startMinute: displayStart,
      endMinute: displayEnd,
    );
  }

  static PlannerCalendarItem _withMinutes(
    PlannerCalendarItem event, {
    required int startMinute,
    required int endMinute,
  }) {
    final originalStart = event.startLocal!;
    final midnight = DateTime(
      originalStart.year,
      originalStart.month,
      originalStart.day,
    );
    return PlannerCalendarItem(
      id: event.id,
      title: event.title,
      date: event.date,
      timing: event.timing,
      state: event.state,
      requiresReport: event.requiresReport,
      hasOutcomeReport: event.hasOutcomeReport,
      startLocal: midnight.add(Duration(minutes: startMinute)),
      endLocal: midnight.add(Duration(minutes: endMinute)),
      startUtc: event.startUtc,
      endUtc: event.endUtc,
      locationText: event.locationText,
      isRecurring: event.isRecurring,
      replacementId: event.replacementId,
      linkedTaskIds: event.linkedTaskIds,
      eventId: event.eventId,
      originalDate: event.originalDate,
      timeZoneId: event.timeZoneId,
      displayTimeZoneId: event.displayTimeZoneId,
      activityTypeId: event.activityTypeId,
      activityTypeLabel: event.activityTypeLabel,
      activityTypeColorValue: event.activityTypeColorValue,
      isBackupAppointment: event.isBackupAppointment,
      backupForEventId: event.backupForEventId,
    );
  }
}
