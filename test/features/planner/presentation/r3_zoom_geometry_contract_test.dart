// R3 REGRESSION (owner override 2026-08-16, FINAL): zoom-out one-hour
// overview cards + collision-safe display-lane packing.
//
// Owner lock: at zoom-out, 15/30/45-minute Events MUST remain readable as
// ONE-HOUR VISUAL blocks; the previous collision-gated fix (neighbor-
// dependent height: isolated short Event = large card, same-hour neighbor =
// tiny strip) is REJECTED. The non-negotiable combination is BOTH
//   A. READABILITY  - every 15/30/45m Event gets the one-hour visual band
//      in overview mode, regardless of neighbors;
//   B. NO DESTRUCTIVE OVERLAP - expanded cards are packed into additional
//      horizontal DISPLAY columns so no Event body/title obscures another;
//      actual time text stays truthful; logical lanes/drag/tap semantics
//      keep the canonical intervals.
//
// These tests pin the geometry layer deterministically for the exact dense
// patterns from the owner evidence (dense morning same-hour sequence, long
// left-lane block + right-lane short Events, contiguous 15/30/45/60
// sequences) plus content-priority (identity before recurrence/status).
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_display_geometry.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// Minimal timed-event fixture for the pure geometry solvers.
({String id, int startMinute, int endMinute, bool backup}) _e(
  String id,
  int startMinute,
  int endMinute, {
  bool backup = false,
}) =>
    (id: id, startMinute: startMinute, endMinute: endMinute, backup: backup);

/// Run the arrangement through the REAL production resolver used by both the
/// centered timeline and the pager previews.
List<PlannerDisplayPlacement> _resolve(
  List<({String id, int startMinute, int endMinute, bool backup})> raw, {
  double hourHeight = 44,
}) {
  final placements = PlannerDisplayGeometry.resolve(
    events: [
      for (final e in raw)
        PlannerCalendarItem(
          id: e.id,
          title: 'Fixture ${e.id}',
          date: const PlannerDate(year: 2026, month: 7, day: 27),
          timing: PlannerEventTiming.timed,
          state: PlannerEventState.scheduled,
          requiresReport: false,
          hasOutcomeReport: false,
          startLocal: DateTime(
            2026,
            7,
            27,
            e.startMinute ~/ 60,
            e.startMinute % 60,
          ),
          endLocal: DateTime(
            2026,
            7,
            27,
            e.endMinute ~/ 60,
            e.endMinute % 60,
          ),
          startUtc: null,
          endUtc: null,
          locationText: null,
          isRecurring: false,
          replacementId: null,
          linkedTaskIds: const <String>[],
          eventId: null,
          originalDate: null,
          timeZoneId: null,
          displayTimeZoneId: null,
          activityTypeId: null,
          activityTypeLabel: null,
          activityTypeColorValue: null,
          isBackupAppointment: e.backup,
          backupForEventId: null,
        ),
    ],
    hourHeight: hourHeight,
    viewportHeight: 700,
    configuredHours: 16,
  );
  return placements;
}

/// The horizontal slice occupied by a placement, as a normalized fraction of
/// the content width, matching the renderer math (span-based placements use
/// spanStart/spanCount; split placements use widthFactor/offsetFactor; plain
/// placements use column/columnCount).
({double left, double right}) _slice(PlannerDisplayPlacement p) {
  final span = p.spanStart;
  if (span != null && p.spanCount != null) {
    return (
      left: span / p.columnCount,
      right: (span + p.spanCount!) / p.columnCount,
    );
  }
  final factor = p.widthFactor;
  if (factor != null) {
    return (left: p.offsetFactor!, right: p.offsetFactor! + factor);
  }
  final width = 1 / p.columnCount;
  return (left: p.column * width, right: (p.column + 1) * width);
}

void main() {
  // Widest practical zoom-out on the owner device (~16 h window on a ~700 dp
  // viewport -> ~44 px/hr). At this zoom ALL 15/30/45-minute Events must be
  // one-hour visual cards.
  const maxZoomHourHeight = 44.0;

  group('R3: every 15/30/45m Event is a one-hour VISUAL card at max zoom-out',
      () {
    test('isolated 15m -> one-hour display height, full width', () {
      final placements = _resolve([_e('a', 540, 555)]);
      final p = placements.single;
      expect(p.height, closeTo(maxZoomHourHeight, 0.001));
      expect(p.widthFactor, isNull, reason: 'isolated card keeps full width');
    });

    test('isolated 30m and 45m -> one-hour display height, full width', () {
      for (final (id, start, end) in [
        ('a', 540, 570),
        ('b', 585, 630),
      ]) {
        final p = _resolve([_e(id, start, end)]).single;
        expect(
          p.height,
          closeTo(maxZoomHourHeight, 0.001),
          reason: '$id must be a one-hour card at max zoom-out',
        );
        expect(p.widthFactor, isNull);
      }
    });

    test(
        'contiguous 30m + 30m in the same hour -> BOTH one-hour cards, '
        'packed side by side, never covering', () {
      final placements = _resolve([_e('a', 540, 570), _e('b', 570, 600)]);
      final byId = {for (final p in placements) p.event.id: p};
      for (final id in ['a', 'b']) {
        expect(
          byId[id]!.height,
          closeTo(maxZoomHourHeight, 0.001),
          reason: 'neighbor must not shrink $id to a strip',
        );
      }
      final sa = _slice(byId['a']!);
      final sb = _slice(byId['b']!);
      expect(
        sa.right <= sb.left + 0.001,
        isTrue,
        reason: 'a and b occupy distinct horizontal slices (no cover)',
      );
    });

    test('4x15m inside one real hour -> four distinct packed slices', () {
      final raw = [
        _e('a', 540, 555),
        _e('b', 555, 570),
        _e('c', 570, 585),
        _e('d', 585, 600),
      ];
      final placements = _resolve(raw);
      final byId = {for (final p in placements) p.event.id: p};
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(byId[id]!.height, closeTo(maxZoomHourHeight, 0.001));
      }
      final slices = raw.map((e) => _slice(byId[e.id]!)).toList();
      // All four slices are pairwise non-overlapping and tile [0,1].
      for (var i = 0; i < slices.length; i++) {
        for (var j = i + 1; j < slices.length; j++) {
          expect(
            slices[i].right <= slices[j].left + 0.001 ||
                slices[j].right <= slices[i].left + 0.001,
            isTrue,
            reason: 'slices $i and $j must not overlap',
          );
        }
      }
    });

    test('15m + 30m + 45m sequence in one hour -> three packed slices', () {
      final raw = [
        _e('a', 540, 555), // 09:00-09:15
        _e('b', 555, 585), // 09:15-09:45
        _e('c', 585, 630), // 09:45-10:30 (45m -> floor at max zoom-out)
      ];
      final placements = _resolve(raw);
      final byId = {for (final p in placements) p.event.id: p};
      for (final id in ['a', 'b', 'c']) {
        expect(byId[id]!.height, closeTo(maxZoomHourHeight, 0.001),
            reason: '$id must keep its one-hour card with neighbors present');
      }
      final slices = raw.map((e) => _slice(byId[e.id]!)).toList();
      for (var i = 0; i < slices.length; i++) {
        for (var j = i + 1; j < slices.length; j++) {
          expect(
            slices[i].right <= slices[j].left + 0.001 ||
                slices[j].right <= slices[i].left + 0.001,
            isTrue,
            reason: 'slices $i and $j must not overlap',
          );
        }
      }
    });

    test('30m + 60m adjacent: short floored, 60m exact, packed slices', () {
      final raw = [
        _e('short', 540, 570), // 09:00-09:30 -> band [09,10]
        _e('long', 570, 630), // 09:30-10:30 exact 60m
      ];
      final placements = _resolve(raw);
      final byId = {for (final p in placements) p.event.id: p};
      expect(byId['short']!.height, closeTo(maxZoomHourHeight, 0.001));
      expect(byId['long']!.height, closeTo(maxZoomHourHeight, 0.001));
      final ss = _slice(byId['short']!);
      final ls = _slice(byId['long']!);
      expect(
        ss.right <= ls.left + 0.001 || ls.right <= ss.left + 0.001,
        isTrue,
        reason: 'short one-hour card must not cover the 60m card',
      );
    });

    test('long left-lane block + right-lane short Events: lanes preserved, '
        'right-lane display collisions packed', () {
      // Executive Meeting 09:30-12:00 (left lane) with right-lane events
      // that really overlap it.
      final raw = [
        _e('executive', 570, 720), // 09:30-12:00 (exact, 150m)
        _e('callMom', 600, 630), // 10:00-10:30 -> band [10,11]
        _e('socialize', 630, 690), // 10:30-11:30 (exact 60m)
        _e('upskill', 690, 720), // 11:30-12:00 -> band [11,12]
      ];
      final placements = _resolve(raw);
      final byId = {for (final p in placements) p.event.id: p};
      // Executive keeps its canonical left lane and exact temporal height.
      expect(
        byId['executive']!.height,
        closeTo(150 * maxZoomHourHeight / 60, 0.001),
      );
      final es = _slice(byId['executive']!);
      // The long Event is lane-resolved against the shorts (never sharing a
      // horizontal slice with a short it logically overlaps).
      for (final shortId in ['callMom', 'socialize', 'upskill']) {
        final shortSlice = _slice(byId[shortId]!);
        expect(
          es.right <= shortSlice.left + 0.001 ||
              shortSlice.right <= es.left + 0.001,
          isTrue,
          reason: 'executive must not cover $shortId',
        );
      }
      // Right-lane short Events get their one-hour cards.
      expect(byId['callMom']!.height, closeTo(maxZoomHourHeight, 0.001));
      expect(byId['upskill']!.height, closeTo(maxZoomHourHeight, 0.001));
      // callMom (band [10,11]) display-collides with socialize ([10:30,
      // 11:30]) in the same right lane -> packed into distinct slices.
      final cs = _slice(byId['callMom']!);
      final ss = _slice(byId['socialize']!);
      expect(
        cs.right <= ss.left + 0.001 || ss.right <= cs.left + 0.001,
        isTrue,
        reason: 'callMom and socialize must not cover each other',
      );
      // upskill (band [11,12]) must not cover socialize nor the executive.
      final us = _slice(byId['upskill']!);
      expect(
        us.right <= ss.left + 0.001 || ss.right <= us.left + 0.001,
        isTrue,
        reason: 'upskill and socialize must not cover each other',
      );
      expect(
        us.right <= es.left + 0.001 || es.right <= us.left + 0.001,
        isTrue,
        reason: 'upskill must not cover the executive',
      );
      // No painted rect intrudes vertically into a non-overlapping event in
      // the same slice: callMom's display band is [10,11]; socialize starts
      // 10:30 in a different slice, so no temporal intrusion in its slice.
      expect(
        byId['executive']!.top + byId['executive']!.height,
        closeTo(720 * maxZoomHourHeight / 60, 0.001),
      );
    });
  });

  group('R3: truthful times + non-colliding hours stay full width', () {
    test('packed placement.event keeps the ORIGINAL canonical minutes', () {
      final placements = _resolve([_e('a', 540, 570), _e('b', 570, 600)]);
      final byId = {for (final p in placements) p.event.id: p};
      expect(byId['a']!.event.startLocal!.hour, 9);
      expect(byId['a']!.event.startLocal!.minute, 0);
      expect(byId['a']!.event.endLocal!.hour, 9);
      expect(byId['a']!.event.endLocal!.minute, 30);
      expect(byId['b']!.event.startLocal!.minute, 30);
      expect(byId['b']!.event.endLocal!.hour, 10);
    });

    test('events in different hours keep full width (no packing)', () {
      final placements = _resolve([
        _e('a', 540, 555), // 09:00-09:15 -> band [09,10]
        _e('b', 660, 675), // 11:00-11:15 -> band [11,12]
      ]);
      final byId = {for (final p in placements) p.event.id: p};
      expect(byId['a']!.widthFactor, isNull);
      expect(byId['b']!.widthFactor, isNull);
      expect(byId['a']!.height, closeTo(maxZoomHourHeight, 0.001));
      expect(byId['b']!.height, closeTo(maxZoomHourHeight, 0.001));
    });

    test('same-column display cards never intrude vertically into the next '
        'hour (adjacent bands)', () {
      final placements = _resolve([
        _e('a', 540, 570), // band [09,10]
        _e('b', 690, 720), // band [11,12]
      ]);
      final byId = {for (final p in placements) p.event.id: p};
      expect(byId['a']!.bottom, closeTo(10 * maxZoomHourHeight, 0.001));
      expect(byId['b']!.top, closeTo(11 * maxZoomHourHeight, 0.001));
    });

    test('at NORMAL zoom 30m/45m Events stay EXACT (default look unchanged)',
        () {
      final placements = _resolve(
        [_e('a', 540, 570), _e('b', 585, 630)],
        hourHeight: 60,
      );
      final byId = {for (final p in placements) p.event.id: p};
      expect(byId['a']!.height, closeTo(30, 0.001));
      expect(byId['b']!.height, closeTo(45, 0.001));
      expect(byId['a']!.widthFactor, isNull);
      expect(byId['b']!.widthFactor, isNull);
    });

    test('absolute-minimum zoom still yields readable one-hour cards', () {
      final placements = _resolve(
        [_e('micro', 540, 555), _e('micro2', 555, 570)],
        hourHeight: 20,
      );
      final byId = {for (final p in placements) p.event.id: p};
      expect(byId['micro']!.height, closeTo(20, 0.001));
      expect(byId['micro2']!.height, closeTo(20, 0.001));
      final s1 = _slice(byId['micro']!);
      final s2 = _slice(byId['micro2']!);
      expect(
        s1.right <= s2.left + 0.001 || s2.right <= s1.left + 0.001,
        isTrue,
      );
    });
  });

  group('R3: content priority - identity outranks recurrence/status', () {
    test('recurrence never renders below the title height', () {
      // Below title line height: no title, no recurrence (identity wins).
      final below = PlannerEventBlockContent.forHeight(
        17,
        interactive: false,
      );
      expect(below.showTitle, isFalse);
      expect(below.showRecurrence, isFalse,
          reason: 'recurrence must not outlive the title');
      // At/above title height: title AND recurrence may render.
      final at = PlannerEventBlockContent.forHeight(
        18,
        interactive: false,
      );
      expect(at.showTitle, isTrue);
      expect(at.showRecurrence, isTrue);
    });

    test('floored one-hour card at min zoom shows title + inline time', () {
      final content = PlannerEventBlockContent.forHeight(
        20,
        interactive: false,
      );
      expect(content.showTitle, isTrue);
      expect(content.showTimeInline, isTrue);
      expect(content.showStatusIcons, isFalse);
    });

    test('status row only when the block has room (title/time first)', () {
      final medium = PlannerEventBlockContent.forHeight(
        44,
        interactive: false,
      );
      expect(medium.showTitle, isTrue);
      expect(medium.showTimeInline, isTrue);
      expect(medium.showStatusIcons, isFalse);
    });
  });

  group('R3: geometry sanity - no spurious overlap math', () {
    test('packed slices tile the content width without gaps', () {
      final placements = _resolve([_e('a', 540, 555), _e('b', 555, 570)]);
      final byId = {for (final p in placements) p.event.id: p};
      final sa = _slice(byId['a']!);
      final sb = _slice(byId['b']!);
      expect(sa.left, closeTo(0, 0.001));
      expect(sb.right, closeTo(1, 0.001));
      expect(sa.right, closeTo(sb.left, 0.001));
      expect(byId['a']!.widthFactor, closeTo(0.5, 0.001));
      expect(byId['b']!.widthFactor, closeTo(0.5, 0.001));
      // Deterministic order: earlier logical start gets the left slice.
      expect(byId['a']!.offsetFactor, closeTo(0, 0.001));
      expect(byId['b']!.offsetFactor, closeTo(0.5, 0.001));
    });

    test('4-column packing width factors are exact', () {
      final placements = _resolve([
        _e('a', 540, 555),
        _e('b', 555, 570),
        _e('c', 570, 585),
        _e('d', 585, 600),
      ]);
      final byId = {for (final p in placements) p.event.id: p};
      for (final id in ['a', 'b', 'c', 'd']) {
        expect(byId[id]!.widthFactor, closeTo(0.25, 0.001));
      }
      final expected = <String, double>{
        'a': 0,
        'b': 0.25,
        'c': 0.5,
        'd': 0.75,
      };
      for (final entry in expected.entries) {
        expect(byId[entry.key]!.offsetFactor, closeTo(entry.value, 0.001));
      }
    });
  });

}
