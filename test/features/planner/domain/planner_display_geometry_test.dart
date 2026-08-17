import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_display_geometry.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';

void main() {
  const date = PlannerDate(year: 2026, month: 7, day: 29);
  const viewportHeight = 700.0;
  const configuredHours = 24;

  PlannerCalendarItem event(String id, int startMinute, int endMinute) {
    final midnight = DateTime(2026, 7, 29);
    return PlannerCalendarItem(
      id: id,
      title: id,
      date: date,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: midnight.add(Duration(minutes: startMinute)),
      endLocal: midnight.add(Duration(minutes: endMinute)),
    );
  }

  double minimumHourHeight() => PlannerZoomPolicy.minimumHourHeightFor(
    viewportHeight: viewportHeight,
    configuredHours: configuredHours,
  );

  List<PlannerDisplayPlacement> resolve(
    List<PlannerCalendarItem> events, {
    required double hourHeight,
    Map<String, int>? previewStartMinutes,
    Map<String, int>? previewEndMinutes,
  }) {
    return PlannerDisplayGeometry.resolve(
      events: events,
      hourHeight: hourHeight,
      viewportHeight: viewportHeight,
      configuredHours: configuredHours,
      previewStartMinutes: previewStartMinutes,
      previewEndMinutes: previewEndMinutes,
    );
  }

  test('Delta 4.2A: every zoom paints exact minute top and height', () {
    final events = <PlannerCalendarItem>[
      event('half', 5 * 60 + 30, 6 * 60),
      event('quarter', 11 * 60 + 45, 12 * 60),
      event('threeQuarter', 13 * 60, 13 * 60 + 45),
      event('hour', 15 * 60, 16 * 60),
    ];
    // Delta 4.2R2 R2-06 + Delta 4.2R3 R3-04: the exact-grid contract holds at
    // every zoom where the Event's canonical rendered height stays at/above
    // the readability pixel threshold (EXACT MODE). With the R3-04 corrected
    // threshold (28px, derived from the block typography) the 15-minute Event
    // floors at normal zoom too (15px < 28), while 30/45/60-minute Events
    // stay EXACT at normal and expanded zoom.
    final zooms = <double>[
      PlannerZoomPolicy.normalHourHeight,
      PlannerZoomPolicy.expandedHourHeight,
    ];

    for (final hourHeight in zooms) {
      final placements = resolve(events, hourHeight: hourHeight);
      final ppm = PlannerTimelineGeometry.pixelsPerMinute(hourHeight);
      // 30/45/60-minute Events stay EXACT at these zooms (30px+ at normal,
      // 44px+ at expanded).
      for (final placement in placements.where(
        (item) => item.event.id != 'quarter',
      )) {
        final start = placement.event.startLocal!;
        final end = placement.event.endLocal!;
        final startMinute = start.hour * 60 + start.minute;
        final endMinute = plannerEndMinuteOfDay(start, end);
        expect(
          placement.top,
          closeTo(startMinute * ppm, 0.001),
          reason: '${placement.event.id} top at $hourHeight pixels per hour',
        );
        expect(
          placement.height,
          closeTo((endMinute - startMinute) * ppm, 0.001),
          reason: '${placement.event.id} height at $hourHeight pixels per hour',
        );
        expect(
          placement.bottom,
          closeTo(endMinute * ppm, 0.001),
          reason: '${placement.event.id} bottom at $hourHeight pixels per hour',
        );
      }
      // The 15-minute Event renders 15px at normal zoom and 22px at expanded
      // zoom, both below the 28px readability threshold (Delta 4.2R3 R3-04),
      // so it engages OVERVIEW MODE and owns its whole hour row (11:00-12:00)
      // while its stored duration stays exactly 15 minutes.
      final quarter = placements.singleWhere(
        (item) => item.event.id == 'quarter',
      );
      expect(quarter.top, closeTo(11 * 60 * ppm, 0.001));
      expect(quarter.height, closeTo(60 * ppm, 0.001));
      expect(quarter.bottom, closeTo(12 * 60 * ppm, 0.001));
      final quarterStart = quarter.event.startLocal!;
      final quarterEnd = quarter.event.endLocal!;
      expect(quarterEnd.difference(quarterStart), const Duration(minutes: 15));
    }

    // R3 owner override (2026-08-16, FINAL): at the compact preset (44px/h)
    // — the overview band — EVERY 15/30/45-minute Event switches to OVERVIEW
    // MODE and occupies its whole hour row (15m=11px, 30m=22px below the
    // 28px threshold; 45m=33px is readable but the owner requires it to read
    // as a one-hour overview card at zoom-out). The 60-minute Event keeps
    // EXACT geometry (44px >= 28px). Stored durations stay exact.
    final compact = resolve(
      events,
      hourHeight: PlannerZoomPolicy.compactHourHeight,
    );
    final compactPpm = PlannerTimelineGeometry.pixelsPerMinute(
      PlannerZoomPolicy.compactHourHeight,
    );
    final quarter = compact.singleWhere((item) => item.event.id == 'quarter');
    expect(quarter.top, closeTo(11 * 60 * compactPpm, 0.001));
    expect(quarter.height, closeTo(60 * compactPpm, 0.001));
    expect(quarter.bottom, closeTo(12 * 60 * compactPpm, 0.001));
    final quarterStart = quarter.event.startLocal!;
    final quarterEnd = quarter.event.endLocal!;
    expect(quarterEnd.difference(quarterStart), const Duration(minutes: 15));
    final half = compact.singleWhere((item) => item.event.id == 'half');
    expect(half.top, closeTo(5 * 60 * compactPpm, 0.001));
    expect(half.height, closeTo(60 * compactPpm, 0.001));
    final halfStart = half.event.startLocal!;
    final halfEnd = half.event.endLocal!;
    expect(halfEnd.difference(halfStart), const Duration(minutes: 30));
    final threeQuarter = compact.singleWhere(
      (item) => item.event.id == 'threeQuarter',
    );
    expect(threeQuarter.top, closeTo(13 * 60 * compactPpm, 0.001));
    expect(threeQuarter.height, closeTo(60 * compactPpm, 0.001));
    expect(threeQuarter.bottom, closeTo(14 * 60 * compactPpm, 0.001));
    final threeQuarterStart = threeQuarter.event.startLocal!;
    final threeQuarterEnd = threeQuarter.event.endLocal!;
    expect(
      threeQuarterEnd.difference(threeQuarterStart),
      const Duration(minutes: 45),
    );
    final hour = compact.singleWhere((item) => item.event.id == 'hour');
    final hourStart = hour.event.startLocal!;
    final hourEnd = hour.event.endLocal!;
    final hourStartMinute = hourStart.hour * 60 + hourStart.minute;
    final hourEndMinute = plannerEndMinuteOfDay(hourStart, hourEnd);
    expect(hour.top, closeTo(hourStartMinute * compactPpm, 0.001));
    expect(hour.height, closeTo((hourEndMinute - hourStartMinute) * compactPpm, 0.001));
  });

  test('Delta 4.2R R10: short Events use a display-only hour-row floor at '
      'maximum zoom-out', () {
    final events = <PlannerCalendarItem>[
      event('short15', 9 * 60, 9 * 60 + 15),
      event('long60', 10 * 60, 11 * 60),
    ];
    // Delta 4.2R2 R2-06: the floor is ADAPTIVE, not "maximum zoom only".
    // At the compact preset a 15-minute Event renders 11px (below the 15px
    // readability threshold), so it already occupies its whole hour row; a
    // 60-minute Event stays exact. This removes the intermediate-zoom dead
    // zone the owner observed.
    final compact = resolve(
      events,
      hourHeight: PlannerZoomPolicy.compactHourHeight,
    );
    final compactShort = compact.singleWhere((p) => p.event.id == 'short15');
    expect(compactShort.top, closeTo(9 * 60 / 60 * 44, 0.001));
    expect(compactShort.height, closeTo(60 / 60 * 44, 0.001));
    final compactLong = compact.singleWhere((p) => p.event.id == 'long60');
    expect(compactLong.height, closeTo(60 / 60 * 44, 0.001));

    final floorZoom = minimumHourHeight();
    final ppm = PlannerTimelineGeometry.pixelsPerMinute(floorZoom);
    final floored = resolve(events, hourHeight: floorZoom);
    final short = floored.singleWhere((p) => p.event.id == 'short15');
    final long = floored.singleWhere((p) => p.event.id == 'long60');
    // short15 occupies its whole 9:00-10:00 hour row (readable, no next-hour
    // spill); long60 (60 minutes, not short) stays exact.
    expect(short.top, closeTo(9 * 60 * ppm, 0.001));
    expect(short.height, closeTo(60 * ppm, 0.001));
    expect(short.bottom, closeTo(10 * 60 * ppm, 0.001));
    expect(long.top, closeTo(10 * 60 * ppm, 0.001));
    expect(long.height, closeTo(60 * ppm, 0.001));
    // Logical duration is untouched: the placement's domain item still
    // carries the exact 15-minute interval.
    final start = short.event.startLocal!;
    final end = short.event.endLocal!;
    expect(end.difference(start), const Duration(minutes: 15));
    // The floored row ends exactly where the next Event starts: the shared
    // boundary must be squared (Delta 4.2R R12 contiguous rule).
    expect(short.squareBottom, isTrue);
    expect(long.squareTop, isTrue);
  });

  test('R4-06: adjacent short Events do not reserve readability lanes', () {
    final placements = resolve(<PlannerCalendarItem>[
      event('a', 5 * 60 + 30, 6 * 60),
      event('b', 6 * 60, 6 * 60 + 30),
      event('c', 6 * 60 + 30, 6 * 60 + 45),
    ], hourHeight: minimumHourHeight());

    final a = placements.singleWhere((item) => item.event.id == 'a');
    final b = placements.singleWhere((item) => item.event.id == 'b');
    final c = placements.singleWhere((item) => item.event.id == 'c');
    // The approved readability floor remains visual: a -> 5:00-6:00 row,
    // b/c -> 6:00-7:00 row. Their exact logical half-open intervals do not
    // overlap, so none of those display footprints may reserve a lane.
    expect(a.bottom, closeTo(b.top, 0.001));
    expect(a.columnCount, 1);
    expect(b.columnCount, 1);
    expect(c.columnCount, 1);
    expect(b.column, c.column);
  });

  test('R5-03: canonical lane identity is invariant across zoom', () {
    final events = <PlannerCalendarItem>[
      event('dominant', 8 * 60, 12 * 60),
      event('early', 8 * 60 + 30, 9 * 60 + 15),
      event('late', 10 * 60, 10 * 60 + 30),
    ];
    final normal = resolve(
      events,
      hourHeight: PlannerZoomPolicy.normalHourHeight,
    );
    final compact = resolve(events, hourHeight: minimumHourHeight());

    for (final expected in normal) {
      final actual = compact.singleWhere(
        (item) => item.event.id == expected.event.id,
      );
      expect(actual.column, expected.column);
      expect(actual.columnCount, expected.columnCount);
      expect(actual.spanStart, expected.spanStart);
      expect(actual.spanCount, expected.spanCount);
      expect(actual.widthFactor, expected.widthFactor);
      expect(actual.offsetFactor, expected.offsetFactor);
    }
    final dominant = compact.singleWhere((item) => item.event.id == 'dominant');
    // R5-03: the Normal Regular Events precede the Normal Dominant Event.
    expect(dominant.column, 1);
  });

  test('Delta 4.2A: final-hour Event ends exactly at midnight', () {
    final hourHeight = minimumHourHeight();
    final placement = resolve(<PlannerCalendarItem>[
      event('finalHour', 23 * 60, 24 * 60),
    ], hourHeight: hourHeight).single;
    final ppm = PlannerTimelineGeometry.pixelsPerMinute(hourHeight);

    expect(placement.top, closeTo(23 * 60 * ppm, 0.001));
    expect(placement.height, closeTo(60 * ppm, 0.001));
    expect(placement.bottom, closeTo(24 * 60 * ppm, 0.001));
  });

  test('Delta 4.2A: live preview endpoints use the same exact grid', () {
    // Delta 4.2R3 R3-04: non-floor zoom is NORMAL (60px/h) where a 30-minute
    // preview renders 30px >= the 28px readability threshold, so the preview
    // endpoints paint exactly on the canonical minute grid. (At the compact
    // preset the same 30-minute preview renders only 22px and now correctly
    // engages OVERVIEW MODE under the corrected threshold.)
    final hourHeight = PlannerZoomPolicy.normalHourHeight;
    final placement = resolve(
      <PlannerCalendarItem>[event('moving', 8 * 60, 9 * 60)],
      hourHeight: hourHeight,
      previewStartMinutes: const <String, int>{'moving': 8 * 60 + 15},
      previewEndMinutes: const <String, int>{'moving': 8 * 60 + 45},
    ).single;
    final ppm = PlannerTimelineGeometry.pixelsPerMinute(hourHeight);

    expect(placement.top, closeTo((8 * 60 + 15) * ppm, 0.001));
    expect(placement.height, closeTo(30 * ppm, 0.001));
    expect(placement.bottom, closeTo((8 * 60 + 45) * ppm, 0.001));

    // Delta 4.2R R10: at maximum zoom-out the same live preview (30 minutes)
    // uses the hour-row floor; the preview endpoints remain layout-only.
    final floorZoom = minimumHourHeight();
    final floorPpm = PlannerTimelineGeometry.pixelsPerMinute(floorZoom);
    final floored = resolve(
      <PlannerCalendarItem>[event('moving', 8 * 60, 9 * 60)],
      hourHeight: floorZoom,
      previewStartMinutes: const <String, int>{'moving': 8 * 60 + 15},
      previewEndMinutes: const <String, int>{'moving': 8 * 60 + 45},
    ).single;
    expect(floored.top, closeTo(8 * 60 * floorPpm, 0.001));
    expect(floored.height, closeTo(60 * floorPpm, 0.001));
    expect(floored.bottom, closeTo(9 * 60 * floorPpm, 0.001));
  });

  test('Delta 4.2B: live preview recomputes logical overlap immediately', () {
    final events = <PlannerCalendarItem>[
      event('fixed', 8 * 60, 9 * 60),
      event('moving', 10 * 60, 11 * 60),
    ];
    final separated = resolve(
      events,
      hourHeight: PlannerZoomPolicy.normalHourHeight,
    );
    expect(
      separated.singleWhere((item) => item.event.id == 'fixed').columnCount,
      1,
    );
    expect(
      separated.singleWhere((item) => item.event.id == 'moving').columnCount,
      1,
    );

    final overlapping = resolve(
      events,
      hourHeight: PlannerZoomPolicy.normalHourHeight,
      previewStartMinutes: const <String, int>{'moving': 8 * 60 + 30},
      previewEndMinutes: const <String, int>{'moving': 9 * 60 + 30},
    );
    final fixed = overlapping.singleWhere((item) => item.event.id == 'fixed');
    final moving = overlapping.singleWhere((item) => item.event.id == 'moving');
    expect(fixed.columnCount, 2);
    expect(moving.columnCount, 2);
    expect(fixed.column, isNot(moving.column));
    expect(moving.event.startLocal!.hour, 10);
    expect(
      moving.top,
      closeTo(
        (8 * 60 + 30) *
            PlannerTimelineGeometry.pixelsPerMinute(
              PlannerZoomPolicy.normalHourHeight,
            ),
        0.001,
      ),
      reason: 'layout preview must not replace the persisted domain item',
    );
  });

  test('Delta 4.2A: dense logical groups remain valid at maximum zoom-out', () {
    final placements = resolve(<PlannerCalendarItem>[
      event('long', 9 * 60, 11 * 60),
      event('inside1', 9 * 60 + 30, 9 * 60 + 45),
      event('inside2', 9 * 60 + 45, 10 * 60),
      event('late', 10 * 60 + 30, 11 * 60 + 30),
    ], hourHeight: minimumHourHeight());

    expect(placements, hasLength(4));
    for (final placement in placements) {
      expect(placement.column, inInclusiveRange(0, placement.columnCount - 1));
      expect(placement.height, greaterThan(0));
    }
  });

  test('R4-06/R3: same-hour short Event footprints are packed into display '
      'columns - never cover, never reserve a logical lane', () {
    // R3 owner override (2026-08-16, FINAL): at zoom-out EVERY short Event
    // is a one-hour visual card; two same-hour short Events (9:00-9:15 and
    // 9:30-9:45 both expand to the 09:00-10:00 band) are packed into two
    // DISPLAY columns so neither covers the other. The logical lane count
    // stays 1 (the floor never reserves a real lane) and both Events keep
    // their exact canonical times.
    final placements = resolve(<PlannerCalendarItem>[
      event('firstShort', 9 * 60, 9 * 60 + 15),
      event('secondShort', 9 * 60 + 30, 9 * 60 + 45),
    ], hourHeight: minimumHourHeight());
    final first = placements.singleWhere((p) => p.event.id == 'firstShort');
    final second = placements.singleWhere((p) => p.event.id == 'secondShort');
    for (final placement in placements) {
      expect(
        placement.columnCount,
        1,
        reason: 'the visual floor must not reserve a logical lane',
      );
    }
    // Both Events own the whole hour visually.
    final ppm = PlannerTimelineGeometry.pixelsPerMinute(minimumHourHeight());
    expect(first.height, closeTo(60 * ppm, 0.001));
    expect(second.height, closeTo(60 * ppm, 0.001));
    // Distinct display slices (packed side by side, never covering).
    expect(first.widthFactor, closeTo(0.5, 0.001));
    expect(second.widthFactor, closeTo(0.5, 0.001));
    expect(first.offsetFactor, closeTo(0, 0.001));
    expect(second.offsetFactor, closeTo(0.5, 0.001));
    // Same canonical lane; canonical times stay exact.
    expect(first.column, second.column);
    expect(
      second.event.startLocal!.difference(first.event.startLocal!),
      const Duration(minutes: 30),
    );
  });
}
