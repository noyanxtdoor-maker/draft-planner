import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';

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
    //
    // R3 (owner override 2026-08-16, FINAL): the hour-row readability floor
    // is UNCONDITIONAL for short Events in overview — a neighbor must never
    // shrink a 15/30/45-minute Event into a strip (the rejected collision
    // gate produced exactly that neighbor-dependent height). Collision
    // safety is instead solved by OVERVIEW DISPLAY-LANE PACKING below:
    // same-canonical-lane Events whose enlarged display bands overlap are
    // packed into additional horizontal display columns, so expanded cards
    // never cover one another and isolated cards keep full width.
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
    // R3 display-lane packing: resolve per-event widthFactor/offsetFactor for
    // same-lane display-band collisions (see class doc). The result is a map
    // of event id -> (subColumn, subCount) for packed events only.
    final packed = _resolveDisplayLanePacking(
      canonical: canonical,
      displayById: displayById,
    );
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
          widthFactor: packed.containsKey(placement.event.id)
              ? packed[placement.event.id]!.widthFactor
              : placement.widthFactor,
          offsetFactor: packed.containsKey(placement.event.id)
              ? packed[placement.event.id]!.offsetFactor
              : placement.offsetFactor,
          // Packed Events drop the canonical free-space span so the renderers
          // use the display-lane widthFactor/offsetFactor slice (the span
          // path takes precedence in both renderers and would otherwise paint
          // every packed card over the same full-lane rectangle).
          spanStart: packed.containsKey(placement.event.id)
              ? null
              : placement.spanStart,
          spanCount: packed.containsKey(placement.event.id)
              ? null
              : placement.spanCount,
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

  /// R3 overview display-lane packing (owner override 2026-08-16, FINAL).
  ///
  /// Returns event id -> (offsetFactor, widthFactor) for every Event whose
  /// ENLARGED display band collides with another Event in the SAME canonical
  /// lane. Colliding Events are packed into horizontal DISPLAY sub-columns
  /// (greedy interval partitioning sorted by display start, logical start as
  /// tiebreak) so expanded one-hour cards never cover one another, while
  /// isolated short Events keep full width. Fractions are expressed relative
  /// to the full content width using the canonical lane frame (the widest
  /// canonical columnCount in the component, so packed cards never paint over
  /// a logically-overlapping neighbor in another lane):
  ///
  ///   offsetFactor = (column * k + i) / (columnCount * k)
  ///   widthFactor  = 1 / (columnCount * k)
  ///
  /// This matches the widthFactor/offsetFactor path shared by the centered
  /// timeline renderer and the pager preview renderer, so centered/preview
  /// parity is preserved. The packing is presentation-only: canonical lanes,
  /// drag/resize math, tap ownership, recurrence, and persistence keep the
  /// logical intervals (placement.event stays the original domain item).
  static Map<String, ({double offsetFactor, double widthFactor})>
      _resolveDisplayLanePacking({
    required List<PlannerTimelinePlacement> canonical,
    required Map<String, PlannerCalendarItem> displayById,
  }) {
    final displayStartOf = <String, int>{};
    final displayEndOf = <String, int>{};
    for (final event in displayById.values) {
      final start = event.startLocal!.hour * 60 + event.startLocal!.minute;
      final end = plannerEndMinuteOfDay(event.startLocal!, event.endLocal!);
      displayStartOf[event.id] = start;
      displayEndOf[event.id] = end;
    }
    final byColumn = <int, List<PlannerTimelinePlacement>>{};
    for (final placement in canonical) {
      byColumn
          .putIfAbsent(placement.column, () => <PlannerTimelinePlacement>[])
          .add(placement);
    }
    final packed = <String, ({double offsetFactor, double widthFactor})>{};
    for (final placements in byColumn.values) {
      placements.sort((a, b) {
        final aStart = displayStartOf[a.event.id]!;
        final bStart = displayStartOf[b.event.id]!;
        if (aStart != bStart) {
          return aStart.compareTo(bStart);
        }
        final aLogical =
            a.event.startLocal!.hour * 60 + a.event.startLocal!.minute;
        final bLogical =
            b.event.startLocal!.hour * 60 + b.event.startLocal!.minute;
        return aLogical.compareTo(bLogical);
      });
      // Connected components of display overlap. Entries are sorted by
      // display start, so an entry joins the current component iff it starts
      // before the component's current maximum display end (transitive).
      var component = <PlannerTimelinePlacement>[];
      var componentMaxEnd = 0;
      void flush() {
        if (component.length >= 2) {
          _packComponent(
            component,
            displayStartOf: displayStartOf,
            displayEndOf: displayEndOf,
            packed: packed,
          );
        }
        component = <PlannerTimelinePlacement>[];
        componentMaxEnd = 0;
      }

      for (final placement in placements) {
        final start = displayStartOf[placement.event.id]!;
        final end = displayEndOf[placement.event.id]!;
        if (component.isEmpty) {
          component = <PlannerTimelinePlacement>[placement];
          componentMaxEnd = end;
        } else if (start < componentMaxEnd) {
          component.add(placement);
          componentMaxEnd = math.max(componentMaxEnd, end);
        } else {
          flush();
          component = <PlannerTimelinePlacement>[placement];
          componentMaxEnd = end;
        }
      }
      flush();
    }
    return packed;
  }

  static void _packComponent(
    List<PlannerTimelinePlacement> component, {
    required Map<String, int> displayStartOf,
    required Map<String, int> displayEndOf,
    required Map<String, ({double offsetFactor, double widthFactor})> packed,
  }) {
    // Greedy interval-column partition: each Event takes the first display
    // column whose last display end does not overlap it; otherwise a new
    // column opens.
    final lastEndByColumn = <int>[];
    final columnOf = <String, int>{};
    for (final placement in component) {
      final start = displayStartOf[placement.event.id]!;
      final end = displayEndOf[placement.event.id]!;
      var assigned = -1;
      for (var c = 0; c < lastEndByColumn.length; c++) {
        if (lastEndByColumn[c] <= start) {
          assigned = c;
          break;
        }
      }
      if (assigned == -1) {
        assigned = lastEndByColumn.length;
        lastEndByColumn.add(0);
      }
      lastEndByColumn[assigned] = end;
      columnOf[placement.event.id] = assigned;
    }
    final subCount = lastEndByColumn.length;
    final canonicalColumn = component.first.column;
    // Use the WIDEST canonical columnCount in the component: packed cards in
    // a multi-lane region must never paint over a logically-overlapping
    // neighbor in another lane, so the packing stays inside the narrowest
    // lane frame.
    var canonicalCount = 1;
    for (final placement in component) {
      canonicalCount = math.max(canonicalCount, placement.columnCount);
    }
    for (final placement in component) {
      final subColumn = columnOf[placement.event.id]!;
      final offsetFactor = (canonicalColumn * subCount + subColumn) /
          (canonicalCount * subCount);
      final widthFactor = 1 / (canonicalCount * subCount);
      packed[placement.event.id] = (
        offsetFactor: offsetFactor,
        widthFactor: widthFactor,
      );
    }
  }

  static PlannerCalendarItem _withDisplayInterval(
    PlannerCalendarItem event, {
    required int startMinute,
    required int endMinute,
    required double hourHeight,
  }) {
    var displayStart = startMinute;
    var displayEnd = endMinute;
    // R3 (owner override 2026-08-16, FINAL): OVERVIEW MODE — the short Event
    // occupies its whole hour row (start-of-hour .. start-of-hour + 60) — is
    // engaged for every 15/30/45-minute Event whenever its canonical rendered
    // height drops below the readability pixel threshold (no intermediate-
    // zoom dead zone), OR whenever the current zoom is at/under the compact
    // overview band (the owner's max-zoom-out rule: at zoom-out, 15/30/45m
    // Events are ALWAYS one-hour visual cards — including a 45-minute Event
    // whose 33 px canonical height at 44 px/hr is still readable, but which
    // the owner requires to read as a one-hour overview card). There is NO
    // collision gate: a neighbor never shrinks a short Event into a strip;
    // same-band collisions are resolved by display-lane packing in [resolve].
    // EXACT MODE keeps the canonical interval whenever enough pixels exist
    // (normal/intermediate zoom). The stored/logical interval is never
    // changed: this clone is a strict display/lane input only.
    final canonicalHeight =
        (endMinute - startMinute) *
        PlannerTimelineGeometry.pixelsPerMinute(hourHeight);
    final overviewByHeight =
        canonicalHeight < kPlannerReadableEventHeightThreshold;
    final overviewByZoom = hourHeight <= PlannerZoomPolicy.compactHourHeight;
    if (endMinute - startMinute <= kPlannerMaxZoomReadabilityDurationMinutes &&
        (overviewByHeight || overviewByZoom)) {
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
