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

  test('Cycle 2B-R: detail geometry is factual at and above 60px/hour', () {
    final events = <PlannerCalendarItem>[
      event('half', 5 * 60 + 30, 6 * 60),
      event('quarter', 11 * 60 + 45, 12 * 60),
      event('threeQuarter', 13 * 60, 13 * 60 + 45),
      event('hour', 15 * 60, 16 * 60),
    ];
    // Detail zoom is factual. The separate transition-band contract below
    // owns 44 < H < 60, without mutating canonical minutes.
    final zooms = <double>[
      120,
      PlannerZoomPolicy.normalHourHeight,
      PlannerZoomPolicy.expandedHourHeight,
    ];

    for (final hourHeight in zooms) {
      final placements = resolve(events, hourHeight: hourHeight);
      final ppm = PlannerTimelineGeometry.pixelsPerMinute(hourHeight);
      for (final placement in placements) {
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
      final quarter = placements.singleWhere(
        (item) => item.event.id == 'quarter',
      );
      expect(quarter.top, closeTo((11 * 60 + 45) * ppm, 0.001));
      expect(quarter.height, closeTo(15 * ppm, 0.001));
      expect(quarter.bottom, closeTo(12 * 60 * ppm, 0.001));
      final quarterStart = quarter.event.startLocal!;
      final quarterEnd = quarter.event.endLocal!;
      expect(quarterEnd.difference(quarterStart), const Duration(minutes: 15));
    }

    // At compact zoom each factual sub-hour item has a 60-minute visual
    // footprint anchored to its factual start. The 60-minute Event remains
    // factual. Stored durations stay exact.
    final compact = resolve(
      events,
      hourHeight: PlannerZoomPolicy.compactHourHeight,
    );
    final compactPpm = PlannerTimelineGeometry.pixelsPerMinute(
      PlannerZoomPolicy.compactHourHeight,
    );
    final quarter = compact.singleWhere((item) => item.event.id == 'quarter');
    expect(quarter.top, closeTo((11 * 60 + 45) * compactPpm, 0.001));
    expect(quarter.height, closeTo(60 * compactPpm, 0.001));
    expect(quarter.bottom, closeTo((12 * 60 + 45) * compactPpm, 0.001));
    final quarterStart = quarter.event.startLocal!;
    final quarterEnd = quarter.event.endLocal!;
    expect(quarterEnd.difference(quarterStart), const Duration(minutes: 15));
    final half = compact.singleWhere((item) => item.event.id == 'half');
    expect(half.top, closeTo((5 * 60 + 30) * compactPpm, 0.001));
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

  test('Cycle 2B-R: saved and draft Task footprints share the exact Event '
      'zoom law without a Task-specific threshold', () {
    final tasks = <PlannerCalendarItem>[
      event('task-footprint:saved-task', 9 * 60 + 45, 10 * 60),
      event('task-draft:unsaved-task', 11 * 60 + 45, 12 * 60),
    ];

    for (final hourHeight in <double>[120, 88, 60]) {
      final placements = resolve(tasks, hourHeight: hourHeight);
      final ppm = PlannerTimelineGeometry.pixelsPerMinute(hourHeight);
      for (final placement in placements) {
        final start = placement.event.startLocal!;
        final startMinute = start.hour * 60 + start.minute;
        expect(placement.top, closeTo(startMinute * ppm, 0.001));
        expect(placement.height, closeTo(15 * ppm, 0.001));
        expect(
          placement.event.endLocal!.difference(start),
          const Duration(minutes: 15),
        );
      }
    }

    final transition = resolve(tasks, hourHeight: 56);
    for (final placement in transition) {
      final start = placement.event.startLocal!;
      expect(placement.top, closeTo((start.hour * 60 + start.minute) * 56 / 60, 0.001));
      expect(placement.height, closeTo(24.5, 0.001));
    }

    final compact = resolve(
      tasks,
      hourHeight: PlannerZoomPolicy.compactHourHeight,
    );
    final ppm = PlannerTimelineGeometry.pixelsPerMinute(
      PlannerZoomPolicy.compactHourHeight,
    );
    for (final placement in compact) {
      final start = placement.event.startLocal!;
      expect(
        placement.top,
        closeTo((start.hour * 60 + start.minute) * ppm, 0.001),
      );
      expect(placement.height, closeTo(60 * ppm, 0.001));
      expect(
        placement.event.endLocal!.difference(start),
        const Duration(minutes: 15),
      );
    }
  });

  test('Cycle 2B-R: the 44-to-60 sub-hour projection is fractional, '
      'monotonic, factual-top anchored, and display-packed', () {
    final events = <PlannerCalendarItem>[
      event('short15', 9 * 60 + 15, 9 * 60 + 30),
      event('short30', 10 * 60, 10 * 60 + 30),
      event('short45', 11 * 60, 11 * 60 + 45),
      event('short50', 12 * 60, 12 * 60 + 50),
      event('hour60', 14 * 60, 15 * 60),
      event('long90', 16 * 60, 17 * 60 + 30),
    ];
    double projectedHeight(double duration, double hourHeight) {
      if (duration >= 60 || hourHeight >= 60) {
        return duration * hourHeight / 60;
      }
      if (hourHeight <= 44) {
        return hourHeight;
      }
      final t = (hourHeight - 44) / 16;
      return (60 + (duration - 60) * t) * hourHeight / 60;
    }

    final samples = <double>[44, 44.1, 44.5, 45, 48, 52, 56, 59, 60, 88];
    for (final idAndDuration in <(String, int)>[
      ('short15', 15),
      ('short30', 30),
      ('short45', 45),
      ('short50', 50),
      ('hour60', 60),
      ('long90', 90),
    ]) {
      double? previousDisplayDuration;
      for (final hourHeight in samples) {
        final placement = resolve(events, hourHeight: hourHeight)
            .singleWhere((item) => item.event.id == idAndDuration.$1);
        final expected = projectedHeight(
          idAndDuration.$2.toDouble(),
          hourHeight,
        );
        expect(placement.height, closeTo(expected, 0.001));
        final factualStart = placement.event.startLocal!;
        expect(
          placement.top,
          closeTo(
            (factualStart.hour * 60 + factualStart.minute) * hourHeight / 60,
            0.001,
          ),
          reason: '${idAndDuration.$1} keeps its factual visual top',
        );
        if (idAndDuration.$2 < 60 && hourHeight > 44 && hourHeight < 60) {
          expect(
            placement.height,
            greaterThan(idAndDuration.$2 * hourHeight / 60),
          );
          expect(placement.height, lessThan(hourHeight));
          final displayDuration = placement.height * 60 / hourHeight;
          if (previousDisplayDuration != null) {
            expect(displayDuration, lessThan(previousDisplayDuration));
          }
          previousDisplayDuration = displayDuration;
        }
      }
    }

    final compact = resolve(events, hourHeight: 44);
    expect(
      compact.singleWhere((item) => item.event.id == 'short50').height,
      closeTo(44, 0.001),
      reason: 'all factual durations below 60 minutes are eligible',
    );
    final at60 = resolve(events, hourHeight: 60);
    expect(
      at60.singleWhere((item) => item.event.id == 'short15').height,
      closeTo(15, 0.001),
    );

    final packed = resolve(<PlannerCalendarItem>[
      event('first', 9 * 60, 9 * 60 + 15),
      event('later', 9 * 60 + 30, 9 * 60 + 45),
    ], hourHeight: 52);
    final first = packed.singleWhere((item) => item.event.id == 'first');
    final later = packed.singleWhere((item) => item.event.id == 'later');
    expect(first.columnCount, 1);
    expect(later.columnCount, 1);
    expect(first.widthFactor, closeTo(0.5, 0.001));
    expect(later.widthFactor, closeTo(0.5, 0.001));
  });

  test('Cycle 2B-R: short Events use a display-only factual-top footprint at '
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
    // The visual end extends from the factual start and lands exactly at the
    // later factual Event's start, so the shared boundary is squared.
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
    // Their factual starts remain anchored while their display intervals may
    // overlap. Packing prevents paint cover without reserving logical lanes.
    expect(a.bottom, greaterThan(b.top));
    expect(a.columnCount, 1);
    expect(b.columnCount, 1);
    expect(c.columnCount, 1);
    expect(b.column, c.column);
    // a and c meet exactly, while b bridges both display bands; two painted
    // slices prevent cover without changing the canonical one-lane identity.
    expect(a.widthFactor, closeTo(1 / 2, 0.001));
    expect(b.widthFactor, closeTo(1 / 2, 0.001));
    expect(c.widthFactor, closeTo(1 / 2, 0.001));
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

    // At compact zoom the preview receives the same factual-top 60-minute
    // display projection; the preview endpoints remain layout-only.
    final floorZoom = minimumHourHeight();
    final floorPpm = PlannerTimelineGeometry.pixelsPerMinute(floorZoom);
    final floored = resolve(
      <PlannerCalendarItem>[event('moving', 8 * 60, 9 * 60)],
      hourHeight: floorZoom,
      previewStartMinutes: const <String, int>{'moving': 8 * 60 + 15},
      previewEndMinutes: const <String, int>{'moving': 8 * 60 + 45},
    ).single;
    expect(floored.top, closeTo((8 * 60 + 15) * floorPpm, 0.001));
    expect(floored.height, closeTo(60 * floorPpm, 0.001));
    expect(floored.bottom, closeTo((9 * 60 + 15) * floorPpm, 0.001));
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
