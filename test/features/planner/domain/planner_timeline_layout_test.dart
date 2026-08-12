import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';

void main() {
  const date = PlannerDate(year: 2026, month: 7, day: 29);

  PlannerCalendarItem event(String id, int startMinute, int endMinute) {
    return PlannerCalendarItem(
      id: id,
      title: id,
      date: date,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: DateTime(2026, 7, 29, startMinute ~/ 60, startMinute % 60),
      endLocal: DateTime(2026, 7, 29, endMinute ~/ 60, endMinute % 60),
    );
  }

  PlannerCalendarItem backupEvent(String id, int startMinute, int endMinute) {
    return PlannerCalendarItem(
      id: id,
      title: id,
      date: date,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: DateTime(2026, 7, 29, startMinute ~/ 60, startMinute % 60),
      endLocal: DateTime(2026, 7, 29, endMinute ~/ 60, endMinute % 60),
      isBackupAppointment: true,
    );
  }

  test(
    'overlapping events receive readable columns while touching events do not',
    () {
      final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
        event('a', 9 * 60, 10 * 60),
        event('b', 9 * 60 + 30, 10 * 60 + 30),
        event('c', 10 * 60 + 30, 11 * 60),
      ]);

      final a = placements.singleWhere((item) => item.event.id == 'a');
      final b = placements.singleWhere((item) => item.event.id == 'b');
      final c = placements.singleWhere((item) => item.event.id == 'c');
      expect(a.columnCount, 2);
      expect(b.columnCount, 2);
      expect(a.column, isNot(b.column));
      expect(c.columnCount, 1);
    },
  );

  test('exact duration geometry at every zoom keeps true time ratios', () {
    for (final hourHeight in <double>[20, 60, 88, 320]) {
      final cases = <int, double>{
        15: 0.25,
        30: 0.50,
        45: 0.75,
        60: 1.00,
        90: 1.50,
        120: 2.00,
      };
      for (final MapEntry(key: minutes, value: ratio) in cases.entries) {
        final geometry = PlannerTimelineGeometry.event(
          startMinute: 8 * 60,
          endMinute: 8 * 60 + minutes,
          visibleStartMinute: 0,
          visibleEndMinute: 24 * 60,
          hourHeight: hourHeight,
        );
        expect(
          geometry.height,
          closeTo(ratio * hourHeight, 0.001),
          reason:
              '$minutes min at hourHeight $hourHeight must be '
              '${ratio}x the hour',
        );
      }
    }
  });

  test('no minimum-height inflation: short events keep exact height', () {
    // A 15-minute event must NEVER render at a 48 px minimum: at
    // hourHeight 20 it is 5 px, at 60 it is 15 px.
    final lowZoom = PlannerTimelineGeometry.event(
      startMinute: 9 * 60,
      endMinute: 9 * 60 + 15,
      visibleStartMinute: 0,
      visibleEndMinute: 24 * 60,
      hourHeight: 20,
    );
    expect(lowZoom.height, closeTo(5, 0.001));
    final normalZoom = PlannerTimelineGeometry.event(
      startMinute: 9 * 60,
      endMinute: 9 * 60 + 15,
      visibleStartMinute: 0,
      visibleEndMinute: 24 * 60,
      hourHeight: 60,
    );
    expect(normalZoom.height, closeTo(15, 0.001));
  });

  test('overlap lanes are independent of zoom', () {
    final events = <PlannerCalendarItem>[
      event('a', 9 * 60, 10 * 60),
      event('b', 9 * 60 + 30, 10 * 60 + 30),
    ];
    final wide = PlannerTimelineLayout.arrange(events, hourHeight: 20);
    final close = PlannerTimelineLayout.arrange(events, hourHeight: 320);
    for (var index = 0; index < events.length; index++) {
      expect(wide[index].column, close[index].column);
      expect(wide[index].columnCount, close[index].columnCount);
    }
  });

  test('R6-04: pure zoom rebinds the cached lane solution to current Event '
      'objects while a logical interval change invalidates it', () {
    final firstEvents = <PlannerCalendarItem>[
      event('r6-a', 9 * 60, 10 * 60),
      event('r6-b', 9 * 60 + 30, 10 * 60 + 30),
    ];
    final first = PlannerTimelineLayout.arrange(firstEvents, hourHeight: 20);
    final reboundEvents = <PlannerCalendarItem>[
      event('r6-a', 9 * 60, 10 * 60),
      event('r6-b', 9 * 60 + 30, 10 * 60 + 30),
    ];
    final rebound = PlannerTimelineLayout.arrange(
      reboundEvents,
      hourHeight: 320,
    );

    for (final current in reboundEvents) {
      final before = first.singleWhere(
        (placement) => placement.event.id == current.id,
      );
      final after = rebound.singleWhere(
        (placement) => placement.event.id == current.id,
      );
      expect(identical(after.event, current), isTrue);
      expect(after.column, before.column);
      expect(after.columnCount, before.columnCount);
      expect(after.spanStart, before.spanStart);
      expect(after.spanCount, before.spanCount);
    }

    final changed = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('r6-a', 9 * 60, 10 * 60),
      event('r6-b', 10 * 60, 11 * 60),
    ], hourHeight: 320);
    expect(
      changed.every(
        (placement) => placement.column == 0 && placement.columnCount == 1,
      ),
      isTrue,
      reason: 'touching intervals must recompute as independent lanes',
    );
  });

  test('R5-03: Normal Regular precedes Normal Dominant in every zoom', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('long', 9 * 60, 12 * 60),
      event('a', 9 * 60 + 30, 10 * 60),
      event('b', 10 * 60, 10 * 60 + 30),
      event('c', 10 * 60 + 30, 11 * 60),
    ]);

    final long = placements.singleWhere((item) => item.event.id == 'long');
    final a = placements.singleWhere((item) => item.event.id == 'a');
    final b = placements.singleWhere((item) => item.event.id == 'b');
    final c = placements.singleWhere((item) => item.event.id == 'c');
    expect(long.columnCount, 2);
    expect(a.column, 0);
    expect(b.column, 0);
    expect(c.column, 0);
    expect(long.column, 1, reason: 'Normal Dominant follows Normal Regular');
    expect(a.column, isNot(long.column));

    // The same ordering must hold at every zoom level (stable lanes).
    final wide = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('long', 9 * 60, 12 * 60),
      event('a', 9 * 60 + 30, 10 * 60),
      event('b', 10 * 60, 10 * 60 + 30),
      event('c', 10 * 60 + 30, 11 * 60),
    ], hourHeight: 20);
    final close = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('long', 9 * 60, 12 * 60),
      event('a', 9 * 60 + 30, 10 * 60),
      event('b', 10 * 60, 10 * 60 + 30),
      event('c', 10 * 60 + 30, 11 * 60),
    ], hourHeight: 320);
    expect(
      wide.singleWhere((item) => item.event.id == 'long').column,
      close.singleWhere((item) => item.event.id == 'long').column,
    );
    expect(wide.singleWhere((item) => item.event.id == 'long').column, 1);
  });

  test('R5-03: Backup Regular precedes Backup Dominant deterministically', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      backupEvent('backupShort', 9 * 60, 10 * 60),
      backupEvent('backupLong', 8 * 60, 12 * 60),
    ]);

    final long = placements.singleWhere(
      (item) => item.event.id == 'backupLong',
    );
    final short = placements.singleWhere(
      (item) => item.event.id == 'backupShort',
    );
    expect(short.column, 0, reason: 'Backup Regular precedes Backup Dominant');
    expect(
      long.column,
      short.column + 1,
      reason: 'Backup Dominant follows Backup Regular',
    );
    expect(long.columnCount, 2);

    // Deterministic: the same input yields the same lanes at every zoom.
    final wide = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      backupEvent('backupShort', 9 * 60, 10 * 60),
      backupEvent('backupLong', 8 * 60, 12 * 60),
    ], hourHeight: 20);
    expect(
      wide.singleWhere((item) => item.event.id == 'backupShort').column,
      0,
    );
    expect(wide.singleWhere((item) => item.event.id == 'backupLong').column, 1);
  });

  test('R5-03: NR then ND then BD follow the owner lane order', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('dominant', 9 * 60, 12 * 60),
      backupEvent('backup', 9 * 60, 12 * 60),
      event('a', 9 * 60 + 30, 10 * 60),
      event('b', 10 * 60, 10 * 60 + 30),
    ]);

    final dominant = placements.singleWhere(
      (item) => item.event.id == 'dominant',
    );
    final backup = placements.singleWhere((item) => item.event.id == 'backup');
    final a = placements.singleWhere((item) => item.event.id == 'a');
    final b = placements.singleWhere((item) => item.event.id == 'b');
    expect(dominant.columnCount, 3);
    expect(a.column, 0);
    expect(b.column, 0);
    expect(
      dominant.column,
      1,
      reason: 'Normal Dominant follows Normal Regular',
    );
    expect(
      backup.column,
      2,
      reason: 'backup must occupy the right special region',
    );
    expect(backup.column, isNot(dominant.column));
  });

  test('R5-03: 60 minutes is Regular while 61 and 75 are Dominant', () {
    expect(
      PlannerTimelineLayout.laneClassOf(event('nr60', 9 * 60, 10 * 60)),
      PlannerTimelineLaneClass.normalRegular,
    );
    expect(
      PlannerTimelineLayout.laneClassOf(event('nd61', 9 * 60, 10 * 60 + 1)),
      PlannerTimelineLaneClass.normalDominant,
    );
    expect(
      PlannerTimelineLayout.laneClassOf(event('nd75', 9 * 60, 10 * 60 + 15)),
      PlannerTimelineLaneClass.normalDominant,
    );
    expect(
      PlannerTimelineLayout.laneClassOf(backupEvent('br60', 9 * 60, 10 * 60)),
      PlannerTimelineLaneClass.backupRegular,
    );
    expect(
      PlannerTimelineLayout.laneClassOf(
        backupEvent('bd61', 9 * 60, 10 * 60 + 1),
      ),
      PlannerTimelineLaneClass.backupDominant,
    );
    expect(
      PlannerTimelineLayout.laneClassOf(
        backupEvent('bd75', 9 * 60, 10 * 60 + 15),
      ),
      PlannerTimelineLaneClass.backupDominant,
    );
  });

  test('R5-03: every overlapping class pair, triple, and quartet follows '
      'NR < ND < BR < BD', () {
    final byClass = <PlannerTimelineLaneClass, PlannerCalendarItem>{
      PlannerTimelineLaneClass.normalRegular: event('nr', 9 * 60, 10 * 60),
      PlannerTimelineLaneClass.normalDominant: event('nd', 9 * 60, 10 * 60 + 1),
      PlannerTimelineLaneClass.backupRegular: backupEvent(
        'br',
        9 * 60,
        10 * 60,
      ),
      PlannerTimelineLaneClass.backupDominant: backupEvent(
        'bd',
        9 * 60,
        10 * 60 + 1,
      ),
    };
    final nr = PlannerTimelineLaneClass.normalRegular;
    final nd = PlannerTimelineLaneClass.normalDominant;
    final br = PlannerTimelineLaneClass.backupRegular;
    final bd = PlannerTimelineLaneClass.backupDominant;
    final combinations = <List<PlannerTimelineLaneClass>>[
      <PlannerTimelineLaneClass>[nr, nd],
      <PlannerTimelineLaneClass>[nr, br],
      <PlannerTimelineLaneClass>[nr, bd],
      <PlannerTimelineLaneClass>[nd, br],
      <PlannerTimelineLaneClass>[nd, bd],
      <PlannerTimelineLaneClass>[br, bd],
      <PlannerTimelineLaneClass>[nr, nd, br],
      <PlannerTimelineLaneClass>[nr, nd, bd],
      <PlannerTimelineLaneClass>[nr, br, bd],
      <PlannerTimelineLaneClass>[nd, br, bd],
      <PlannerTimelineLaneClass>[nr, nd, br, bd],
    ];

    for (final classes in combinations) {
      final placements = PlannerTimelineLayout.arrange(
        classes.map((laneClass) => byClass[laneClass]!).toList(),
      );
      for (var index = 0; index < classes.length; index++) {
        final laneClass = classes[index];
        final expectedEvent = byClass[laneClass]!;
        final placement = placements.singleWhere(
          (item) => item.event.id == expectedEvent.id,
        );
        expect(
          placement.column,
          index,
          reason: '${classes.join(' / ')} must preserve the R5 class order',
        );
        expect(placement.columnCount, classes.length);
      }
    }
  });

  test('R5-03: same-class tie-break is start, end, then id and ignores input '
      'order', () {
    final ordered = <PlannerCalendarItem>[
      event('a', 9 * 60, 10 * 60),
      event('b', 9 * 60, 10 * 60),
      event('c', 9 * 60, 10 * 60),
    ];
    final forward = PlannerTimelineLayout.arrange(ordered);
    final reversed = PlannerTimelineLayout.arrange(ordered.reversed.toList());

    for (var index = 0; index < ordered.length; index++) {
      final id = ordered[index].id;
      expect(forward.singleWhere((item) => item.event.id == id).column, index);
      expect(reversed.singleWhere((item) => item.event.id == id).column, index);
    }
  });

  test('R5-03: same-class transitive chain reuses the freed local lane', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('a', 0, 60),
      event('b', 30, 90),
      event('c', 60, 120),
    ]);
    final a = placements.singleWhere((item) => item.event.id == 'a');
    final b = placements.singleWhere((item) => item.event.id == 'b');
    final c = placements.singleWhere((item) => item.event.id == 'c');

    expect(a.column, 0);
    expect(b.column, 1);
    expect(c.column, 0, reason: 'A and C are half-open non-overlaps');
    expect(a.columnCount, 2);
    expect(b.columnCount, 2);
    expect(c.columnCount, 2);
  });

  test('Delta 4.2R2 R2-07: a backup never covers the primary anchor in a '
      'mixed cluster and lanes are zoom-stable', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      backupEvent('backup', 9 * 60, 12 * 60),
      event('a', 9 * 60, 10 * 60),
      event('b', 10 * 60, 11 * 60),
    ]);

    final backup = placements.singleWhere((item) => item.event.id == 'backup');
    final a = placements.singleWhere((item) => item.event.id == 'a');
    final b = placements.singleWhere((item) => item.event.id == 'b');
    // The primary anchor (most dominant non-backup, 'a') is LEFTMOST; the
    // backup occupies the right special region. 'b' touches 'a' (ends
    // where 'a' starts) so it shares the anchor lane without overlapping
    // it.
    expect(a.columnCount, 2);
    expect(a.column, 0, reason: 'primary non-backup anchors leftmost');
    expect(backup.column, 1);
    expect(b.column, a.column);

    final wide = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      backupEvent('backup', 9 * 60, 12 * 60),
      event('a', 9 * 60, 10 * 60),
      event('b', 10 * 60, 11 * 60),
    ], hourHeight: 20);
    for (final id in <String>['backup', 'a', 'b']) {
      expect(
        wide.singleWhere((item) => item.event.id == id).column,
        placements.singleWhere((item) => item.event.id == id).column,
      );
    }
  });

  test('touching events do not overlap: single lane at every zoom', () {
    final placements = PlannerTimelineLayout.arrange(<PlannerCalendarItem>[
      event('short', 9 * 60, 9 * 60 + 15),
      event('next', 9 * 60 + 15, 9 * 60 + 30),
    ], hourHeight: 60);

    final short = placements.singleWhere((item) => item.event.id == 'short');
    final next = placements.singleWhere((item) => item.event.id == 'next');
    expect(short.columnCount, 1);
    expect(next.columnCount, 1);
    expect(short.column, next.column);
  });

  test('time snapping is deterministic and clamped to the day', () {
    expect(snapPlannerMinute(9 * 60 + 7, 15), 9 * 60);
    expect(snapPlannerMinute(9 * 60 + 8, 15), 9 * 60 + 15);
    expect(snapPlannerMinute(-20, 15), 0);
    expect(snapPlannerMinute(1500, 15), 1439);
  });

  group('PlannerTimelineGeometry lower-boundary safety', () {
    // Runtime-stability delta: an Event whose clipped start sits inside the
    // final `minimumReadableEventHeight` pixels before the day boundary used
    // to throw `Invalid argument(s): 48.0` from `clamp(48, availableHeight)`.
    // These tests prove the geometry stays finite and inside the canvas.
    test('event ending exactly at the final boundary is valid', () {
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 23 * 60,
        endMinute: 24 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      expect(geometry.clippedStartMinute, 23 * 60);
      expect(geometry.clippedEndMinute, 24 * 60);
      expect(geometry.top, 23 * 60);
      expect(geometry.height, greaterThan(0));
      expect(geometry.bottom, lessThanOrEqualTo(24 * 60));
    });

    test('event starting inside the final readable band does not throw', () {
      // Combined delta: the visible slice is the exact intersection
      // `max(eventStart, dayStart) .. min(eventEnd, dayEnd)` with no
      // quarter-hour forcing and no minimum-height inflation. A 23:50
      // event renders its true 10-minute sliver at 23:50 instead of
      // being moved up to 23:45 or expanded to the old 48 px minimum.
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 23 * 60 + 50,
        endMinute: 24 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      expect(geometry.clippedStartMinute, 23 * 60 + 50);
      expect(geometry.clippedEndMinute, 24 * 60);
      expect(geometry.height, closeTo(10, 0.001));
      expect(geometry.bottom, closeTo(24 * 60, 0.001));
    });

    test('event dragged beyond the final boundary has no visible slice', () {
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 25 * 60,
        endMinute: 26 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      // Entirely past midnight: no intersection, zero-height at the final
      // boundary. Never throws and never renders past the canvas.
      expect(geometry.clippedStartMinute, 24 * 60);
      expect(geometry.clippedEndMinute, 24 * 60);
      expect(geometry.height, 0);
      expect(geometry.bottom, closeTo(24 * 60, 0.001));
    });

    test('hidden-midnight top and bottom slots keep exact geometry', () {
      // 12:00 AM - 1:00 AM top slot: full first hour above the hidden
      // 12 AM boundary; top must be 0 (never negative, never clipped
      // behind the date strip).
      final top = PlannerTimelineGeometry.event(
        startMinute: 0,
        endMinute: 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      expect(top.clippedStartMinute, 0);
      expect(top.top, 0);
      expect(top.height, closeTo(60, 0.001));

      // 11:00 PM - 12:00 AM bottom slot: full final hour below the
      // visible 11 PM line, ending exactly at the hidden 12 AM boundary.
      final bottom = PlannerTimelineGeometry.event(
        startMinute: 23 * 60,
        endMinute: 24 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      expect(bottom.clippedStartMinute, 23 * 60);
      expect(bottom.clippedEndMinute, 24 * 60);
      expect(bottom.height, closeTo(60, 0.001));
      expect(bottom.bottom, closeTo(24 * 60, 0.001));

      // Boundary sliver: a 23:55-24:00 event renders its true 5-minute
      // clipped slice (visible clipping, stored duration unchanged).
      final sliver = PlannerTimelineGeometry.event(
        startMinute: 23 * 60 + 55,
        endMinute: 24 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      expect(sliver.clippedStartMinute, 23 * 60 + 55);
      expect(sliver.height, closeTo(5, 0.001));
    });

    test('very short event near the boundary stays renderable', () {
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 23 * 60 + 55,
        endMinute: 23 * 60 + 57,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: 60,
      );
      expect(geometry.height, greaterThanOrEqualTo(0));
      expect(geometry.bottom, lessThanOrEqualTo(24 * 60));
    });

    test('max zoom-in near the lower boundary remains valid', () {
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 23 * 60 + 45,
        endMinute: 24 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: PlannerZoomPolicy.absoluteMaximumHourHeight,
      );
      final canvasBottom =
          24 *
          60 *
          PlannerTimelineGeometry.pixelsPerMinute(
            PlannerZoomPolicy.absoluteMaximumHourHeight,
          );
      expect(geometry.height, greaterThan(0));
      expect(geometry.bottom, lessThanOrEqualTo(canvasBottom));
    });

    test('max zoom-out near the lower boundary remains valid', () {
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 23 * 60 + 50,
        endMinute: 24 * 60,
        visibleStartMinute: 0,
        visibleEndMinute: 24 * 60,
        hourHeight: PlannerZoomPolicy.absoluteMinimumHourHeight,
      );
      final canvasBottom =
          24 *
          60 *
          PlannerTimelineGeometry.pixelsPerMinute(
            PlannerZoomPolicy.absoluteMinimumHourHeight,
          );
      expect(geometry.height, greaterThanOrEqualTo(0));
      expect(geometry.bottom, lessThanOrEqualTo(canvasBottom));
    });

    test('all boundary geometry values are finite', () {
      for (final hourHeight in <double>[20, 44, 60, 88, 320]) {
        for (final startMinute in <int>[
          0,
          23 * 60,
          23 * 60 + 30,
          24 * 60 - 1,
        ]) {
          final geometry = PlannerTimelineGeometry.event(
            startMinute: startMinute,
            endMinute: startMinute + 60,
            visibleStartMinute: 0,
            visibleEndMinute: 24 * 60,
            hourHeight: hourHeight,
          );
          expect(geometry.top.isFinite, isTrue);
          expect(geometry.logicalHeight.isFinite, isTrue);
          expect(geometry.height.isFinite, isTrue);
          expect(geometry.height, greaterThanOrEqualTo(0));
          expect(
            geometry.bottom,
            lessThanOrEqualTo(
              24 * 60 * PlannerTimelineGeometry.pixelsPerMinute(hourHeight),
            ),
          );
        }
      }
    });
  });

  test(
    'initial scroll follows today, other-day, and visible-start settings',
    () {
      const settings = PlannerSettings.defaults();
      final now = DateTime(2026, 7, 29, 14, 37);

      expect(
        plannerInitialScrollMinute(
          settings: settings,
          selectedDate: date,
          now: now,
          firstRelevantEventMinute: 9 * 60,
        ),
        14 * 60 + 37,
      );
      expect(
        plannerInitialScrollMinute(
          settings: settings,
          selectedDate: date.addDays(1),
          now: now,
          firstRelevantEventMinute: 9 * 60 + 15,
        ),
        9 * 60 + 15,
      );
      expect(
        plannerInitialScrollMinute(
          settings: settings.copyWith(
            initialScrollBehavior: PlannerInitialScrollBehavior.visibleStart,
          ),
          selectedDate: date,
          now: now,
          firstRelevantEventMinute: 9 * 60,
        ),
        settings.visibleStartHour * 60,
      );
    },
  );
}
