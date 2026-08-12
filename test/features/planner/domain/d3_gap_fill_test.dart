import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_display_geometry.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// Planner Polish Delta 3 — PMG-style free-space gap filling.
///
/// Every case runs against BOTH the canonical arrangement (normal/zoomed-in
/// exact path) and the overview `resolve()` path (maximum zoom-out display
/// geometry), because the physical device renders the overview path.
void main() {
  const date = PlannerDate(year: 2026, month: 8, day: 7);
  const viewportHeight = 700.0;
  const configuredHours = 24;

  PlannerCalendarItem event(
    String id,
    int startMinute,
    int endMinute, {
    bool backup = false,
  }) {
    final start = DateTime(
      2026,
      8,
      7,
      0,
      0,
    ).add(Duration(minutes: startMinute));
    final end = DateTime(2026, 8, 7, 0, 0).add(Duration(minutes: endMinute));
    return PlannerCalendarItem(
      id: id,
      title: id,
      date: date,
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: start,
      endLocal: end,
      isBackupAppointment: backup,
    );
  }

  List<PlannerTimelinePlacement> arrange(List<PlannerCalendarItem> events) {
    return PlannerTimelineLayout.arrange(events);
  }

  List<PlannerDisplayPlacement> resolve(List<PlannerCalendarItem> events) {
    return PlannerDisplayGeometry.resolve(
      events: events,
      hourHeight: PlannerZoomPolicy.minimumHourHeightFor(
        viewportHeight: viewportHeight,
        configuredHours: configuredHours,
      ),
      viewportHeight: viewportHeight,
      configuredHours: configuredHours,
    );
  }

  /// Overlapping X rectangles must never contain two vertically overlapping
  /// Events (the Delta 3 rectangle rule keeps every card one clean block and
  /// no expansion may draw under/over a real blocker).
  void expectNoCollisions(List<PlannerDisplayPlacement> placements) {
    for (var i = 0; i < placements.length; i += 1) {
      for (var j = i + 1; j < placements.length; j += 1) {
        final a = placements[i];
        final b = placements[j];
        final vertical = a.top < b.bottom && b.top < a.bottom;
        if (!vertical) {
          continue;
        }
        final aLeft = _leftOf(a);
        final aRight = aLeft + _widthOf(a);
        final bLeft = _leftOf(b);
        final bRight = bLeft + _widthOf(b);
        expect(
          aRight <= bLeft + 0.5 || bRight <= aLeft + 0.5,
          isTrue,
          reason:
              '${a.event.id} and ${b.event.id} overlap vertically but their '
              'expanded rectangles overlap horizontally',
        );
      }
    }
  }

  group('canonical arrange() — PMG gap fill', () {
    test('TEST 1 — isolated Event uses the full available width', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('lunch', 12 * 60, 13 * 60),
        event('morning', 7 * 60, 8 * 60),
      ]);
      final lunch = placements.singleWhere((p) => p.event.id == 'lunch');
      expect(lunch.columnCount, 1);
      expect(lunch.spanCount ?? 1, 1);
    });

    test('TEST 2 — two truly overlapping Events split only as required', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('a', 7 * 60, 8 * 60),
        event('b', 7 * 60 + 30, 8 * 60 + 30),
      ]);
      final a = placements.singleWhere((p) => p.event.id == 'a');
      final b = placements.singleWhere((p) => p.event.id == 'b');
      expect(a.columnCount, 2);
      expect(a.spanCount, 1);
      expect(b.spanCount, 1);
      expect(a.spanStart, isNot(b.spanStart));
    });

    test('TEST 3 — three truly overlapping Events use three lanes only', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('a', 7 * 60, 8 * 60),
        event('b', 7 * 60 + 30, 8 * 60 + 30),
        event('c', 7 * 60 + 45, 8 * 60 + 45),
      ]);
      final a = placements.singleWhere((p) => p.event.id == 'a');
      expect(a.columnCount, 3);
      for (final p in placements) {
        expect(p.spanCount, 1);
      }
    });

    test('TEST 4 — transitive overlap: C never narrows A', () {
      // A(7:00-8:00), B(7:30-9:00), C(8:30-9:30): A and C never overlap.
      final withC = arrange(<PlannerCalendarItem>[
        event('a', 7 * 60, 8 * 60),
        event('b', 7 * 60 + 30, 9 * 60),
        event('c', 8 * 60 + 30, 9 * 60 + 30),
      ]);
      final withoutC = arrange(<PlannerCalendarItem>[
        event('a', 7 * 60, 8 * 60),
        event('b', 7 * 60 + 30, 9 * 60),
      ]);
      final aWithC = withC.singleWhere((p) => p.event.id == 'a');
      final aWithoutC = withoutC.singleWhere((p) => p.event.id == 'a');
      expect(
        aWithC.spanCount,
        aWithoutC.spanCount,
        reason:
            "C must not force A to stay narrow (A's only real blocker is B)",
      );
      // A real blocker ABOVE is respected and a later Event reclaims the
      // freed rows (TEST 8/9): W (6:00-7:00) overlaps nothing but the
      // dominant, so it expands across the whole free left region instead of
      // inheriting a stale narrow column from the X/Y/Z cluster above it.
      final reclaim = arrange(<PlannerCalendarItem>[
        event('dominant', 0, 1320),
        event('x', 255, 315),
        event('y', 280, 340),
        event('z', 300, 360),
        event('w', 360, 420),
      ]);
      final w = reclaim.singleWhere((p) => p.event.id == 'w');
      expect(w.spanCount, 3, reason: 'TEST 8/9 — W fills the free lanes');
      // An Event starting after the whole cluster ended is its own group and
      // renders full width — no stale cluster width is inherited.
      final isolated = arrange(<PlannerCalendarItem>[
        event('a', 7 * 60, 8 * 60),
        event('b', 7 * 60 + 30, 9 * 60),
        event('d', 9 * 60, 10 * 60),
      ]);
      final d = isolated.singleWhere((p) => p.event.id == 'd');
      expect(d.columnCount, 1);
    });

    test(
      'R5-03 — Normal Regular precedes Normal Dominant without empty lanes',
      () {
        final placements = arrange(<PlannerCalendarItem>[
          event('dominant', 0, 1320),
          event('work', 255, 315),
          event('service', 330, 390),
          event('job', 435, 495),
        ]);
        final dominant = placements.singleWhere(
          (p) => p.event.id == 'dominant',
        );
        final job = placements.singleWhere((p) => p.event.id == 'job');
        expect(dominant.column, 1);
        expect(dominant.spanCount, 1);
        // Job's interval touches no other regular Event. Its sole direct
        // blocker is the Normal Dominant Event to its right.
        expect(job.spanCount, job.columnCount - 1);
        expect(job.spanStart, 0);
      },
    );

    test('R5-03 — class ordering stays stable after a downward drag', () {
      final before = arrange(<PlannerCalendarItem>[
        event('dominant', 0, 1320),
        event('job', 435, 495),
      ]);
      final beforeDominant = before.singleWhere(
        (p) => p.event.id == 'dominant',
      );
      expect(beforeDominant.column, 1);

      // Drag the dominant down to 4 AM - 10 PM; it still overlaps Job.
      final after = arrange(<PlannerCalendarItem>[
        event('dominant', 240, 1320),
        event('job', 435, 495),
      ]);
      final afterDominant = after.singleWhere((p) => p.event.id == 'dominant');
      expect(
        afterDominant.column,
        1,
        reason: 'Normal Dominant must remain right of Normal Regular',
      );
      // Deterministic: identical input reproduces identical lanes/spans.
      final replay = arrange(<PlannerCalendarItem>[
        event('dominant', 240, 1320),
        event('job', 435, 495),
      ]);
      for (final p in replay) {
        final twin = after.singleWhere((q) => q.event.id == p.event.id);
        expect(p.column, twin.column);
        expect(p.spanStart, twin.spanStart);
        expect(p.spanCount, twin.spanCount);
      }
    });

    test('R5-03 — ND + BD use class columns without a fixed split', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('primary', 180, 360),
        event('backup', 0, 540, backup: true),
      ]);
      final primary = placements.singleWhere((p) => p.event.id == 'primary');
      final backup = placements.singleWhere((p) => p.event.id == 'backup');
      expect(primary.column, 0);
      expect(backup.column, 1);
      expect(primary.widthFactor, isNull);
      expect(backup.widthFactor, isNull);
      expect(backup.offsetFactor, isNull);
      expect(primary.spanCount, 1);
    });
    test('R5-03 — overlapping same-class dominant Events use deterministic '
        'subcolumns after Normal Regular', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('dominant1', 0, 1320),
        event('dominant2', 120, 600),
        event('job', 435, 495),
      ]);
      final d1 = placements.singleWhere((p) => p.event.id == 'dominant1');
      final d2 = placements.singleWhere((p) => p.event.id == 'dominant2');
      final job = placements.singleWhere((p) => p.event.id == 'job');

      expect(
        d1.column,
        1,
        reason: 'the first Normal Dominant follows Normal Regular',
      );
      expect(
        d2.column,
        2,
        reason: 'the second Normal Dominant uses the next subcolumn',
      );
      expect(job.column, 0);
      expect(d1.spanCount, 1);
      expect(d2.spanCount, 1);
    });

    test('Delta 4.2B / R2-07 — multiple Backups keep the special-RIGHT '
        'region', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('dominant', 0, 20 * 60),
        event('ordinary', 9 * 60, 10 * 60),
        event('backup1', 8 * 60, 12 * 60, backup: true),
        event('backup2', 8 * 60 + 30, 11 * 60 + 30, backup: true),
      ]);
      final dominant = placements.singleWhere(
        (item) => item.event.id == 'dominant',
      );
      final ordinary = placements.singleWhere(
        (item) => item.event.id == 'ordinary',
      );
      final backups = placements
          .where((item) => item.event.isBackupAppointment)
          .toList(growable: false);

      // R5-03: NR < ND < BR < BD for real overlaps.
      expect(ordinary.column, 0);
      expect(dominant.column, 1);
      expect(backups, hasLength(2));
      for (final backup in backups) {
        expect(backup.column, greaterThan(ordinary.column));
        expect(backup.column, greaterThan(dominant.column));
      }
      expect(backups[0].column, isNot(backups[1].column));
    });
  });

  group('repeat icon visibility (Delta 3 card affordance)', () {
    test('a one-hour block at max zoom-out shows the repeat icon', () {
      // At maximum zoom-out a one-hour block is ~17 px tall; the previous
      // 18 px threshold hid recurrence from exactly this view.
      expect(
        PlannerEventBlockContent.forHeight(
          17,
          interactive: true,
        ).showRecurrence,
        isTrue,
      );
      // Micro blocks (title hidden) keep the icon hidden so it cannot bleed
      // outside the hard-clipped card.
      expect(
        PlannerEventBlockContent.forHeight(
          11,
          interactive: true,
        ).showRecurrence,
        isFalse,
      );
      expect(PlannerEventBlockLayoutPolicy.recurrenceIconSize, 14);
      expect(
        PlannerEventBlockLayoutPolicy.recurrenceIconSizeFor(Density.veryShort),
        12,
      );
    });
  });

  group('calendarRecurrenceRuleLabel (Delta 3 repeat row)', () {
    test('frequency labels with optional end suffixes', () {
      expect(
        calendarRecurrenceRuleLabel(
          const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.daily,
          ),
        ),
        'Daily',
      );
      expect(
        calendarRecurrenceRuleLabel(
          const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.weekly,
            endMode: CalendarRecurrenceEndMode.onDate,
            endDate: PlannerDate(year: 2026, month: 8, day: 31),
          ),
        ),
        'Weekly • Until Aug 31, 2026',
      );
      expect(
        calendarRecurrenceRuleLabel(
          const CalendarRecurrenceRule(
            frequency: CalendarRecurrenceFrequency.monthly,
            endMode: CalendarRecurrenceEndMode.afterCount,
            occurrenceCount: 5,
          ),
        ),
        'Monthly • 5 occurrences',
      );
      expect(
        calendarRecurrenceRuleLabel(const CalendarRecurrenceRule()),
        'Does not repeat',
      );
    });
  });

  group('overview resolve() — PMG gap fill at maximum zoom-out', () {
    test('TEST 1 — isolated Events stay full width at zoom-out', () {
      final placements = resolve(<PlannerCalendarItem>[
        event('lunch', 12 * 60, 13 * 60),
        event('job', 435, 495),
      ]);
      final lunch = placements.singleWhere((p) => p.event.id == 'lunch');
      expect(lunch.columnCount, 1);
      expectNoCollisions(placements);
    });

    test('R5-03 — overview preserves NR before ND and local gap fill', () {
      final placements = resolve(<PlannerCalendarItem>[
        event('dominant', 0, 1320),
        event('job', 435, 495),
      ]);
      final dominant = placements.singleWhere((p) => p.event.id == 'dominant');
      final job = placements.singleWhere((p) => p.event.id == 'job');
      expect(dominant.column, 1);
      expect(job.spanCount, job.columnCount - 1);
      expect(job.spanStart, 0);
      expectNoCollisions(placements);
    });

    test('TEST 4/8/9 — transitive and above/below blockers at zoom-out', () {
      final placements = resolve(<PlannerCalendarItem>[
        event('a', 420, 480),
        event('b', 450, 540),
        event('c', 510, 570),
        event('d', 585, 645),
      ]);
      final a = placements.singleWhere((p) => p.event.id == 'a');
      final d = placements.singleWhere((p) => p.event.id == 'd');
      // A is narrowed only by its real display blocker B, never by C.
      expect(a.spanCount, 1);
      // D starts after the whole cluster ended: full width, no stale width.
      expect(d.columnCount, 1);
      expectNoCollisions(placements);
    });

    test('TEST 10 — restart determinism at overview zoom', () {
      final events = <PlannerCalendarItem>[
        event('dominant', 0, 1320),
        event('job', 435, 495),
        event('service', 330, 390),
        event('work', 255, 315),
      ];
      final first = resolve(events);
      final second = resolve(events);
      for (final p in first) {
        final twin = second.singleWhere((q) => q.event.id == p.event.id);
        expect(p.column, twin.column);
        expect(p.spanStart, twin.spanStart);
        expect(p.spanCount, twin.spanCount);
      }
      expectNoCollisions(second);
    });
  });

  group('Delta 4.2R3 R3-08 — local temporal lane allocation', () {
    test('CASE A — dominant + normal + backup truly overlap: left / center / '
        'right three-lane split', () {
      final canonical = arrange(<PlannerCalendarItem>[
        event('dominant', 0, 1440),
        event('normal', 300, 600),
        event('backup', 400, 800, backup: true),
      ]);
      final canonicalDominant = canonical.singleWhere(
        (p) => p.event.id == 'dominant',
      );
      final canonicalNormal = canonical.singleWhere(
        (p) => p.event.id == 'normal',
      );
      final canonicalBackup = canonical.singleWhere(
        (p) => p.event.id == 'backup',
      );
      expect(canonicalDominant.column, 0);
      expect(canonicalNormal.column, 1);
      expect(canonicalBackup.column, 2);

      final overview = resolve(<PlannerCalendarItem>[
        event('dominant', 0, 1440),
        event('normal', 300, 600),
        event('backup', 400, 800, backup: true),
      ]);
      final overviewDominant = overview.singleWhere(
        (p) => p.event.id == 'dominant',
      );
      final overviewNormal = overview.singleWhere(
        (p) => p.event.id == 'normal',
      );
      final overviewBackup = overview.singleWhere(
        (p) => p.event.id == 'backup',
      );
      expect(overviewDominant.column, 0);
      expect(overviewNormal.column, 1);
      expect(overviewBackup.column, 2);
    });

    test('CASE B — dominant + normal only: normal fills the remaining width '
        'with NO empty backup region', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('dominant', 0, 1320),
        event('normal', 300, 600),
      ]);
      final normal = placements.singleWhere((p) => p.event.id == 'normal');
      expect(normal.spanCount, normal.columnCount - 1);
      expect(normal.spanStart, 1);
      expect(placements.every((p) => !p.event.isBackupAppointment), isTrue);
    });

    test('CASE C — normal + backup only: normal left, backup right, no empty '
        'dominant region', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('normal', 300, 600),
        event('backup', 400, 800, backup: true),
      ]);
      final normal = placements.singleWhere((p) => p.event.id == 'normal');
      final backup = placements.singleWhere((p) => p.event.id == 'backup');
      expect(normal.column, isNot(backup.column));
      expect(backup.column, greaterThan(normal.column));
    });

    test('CASE D — special Event ends BEFORE the normal: the normal uses the '
        'full available width (no stale narrow column)', () {
      final canonical = arrange(<PlannerCalendarItem>[
        event('dominant', 0, 255), // 12:00 AM - 4:15 PM
        event('normal', 270, 330), // 4:30 PM - 5:30 PM (no overlap)
      ]);
      final canonicalNormal = canonical.singleWhere(
        (p) => p.event.id == 'normal',
      );
      expect(
        canonicalNormal.columnCount,
        1,
        reason: 'non-overlapping normal must own the full available width',
      );
      expect(canonicalNormal.spanCount ?? 1, 1);

      final overview = resolve(<PlannerCalendarItem>[
        event('dominant', 0, 255),
        event('normal', 270, 330),
      ]);
      final overviewNormal = overview.singleWhere(
        (p) => p.event.id == 'normal',
      );
      expect(overviewNormal.columnCount, 1);
      expect(overviewNormal.spanCount ?? 1, 1);
    });

    test('CASE E — isolated normal fills the full available width', () {
      final canonical = arrange(<PlannerCalendarItem>[
        event('normal', 300, 600),
      ]);
      expect(canonical.single.columnCount, 1);
      final overview = resolve(<PlannerCalendarItem>[
        event('normal', 300, 600),
      ]);
      expect(overview.single.columnCount, 1);
    });

    test('R5-03 TRANSITIVE — a same-class bridge does not permanently '
        'reserve a third lane', () {
      // A overlaps B, B overlaps C, and the half-open A/C intervals do not
      // overlap. All three are Normal Regular, so C reuses A's freed lane.
      final placements = arrange(<PlannerCalendarItem>[
        event('a', 0, 60),
        event('b', 30, 90),
        event('c', 60, 120),
      ]);
      final a = placements.singleWhere((p) => p.event.id == 'a');
      final b = placements.singleWhere((p) => p.event.id == 'b');
      final c = placements.singleWhere((p) => p.event.id == 'c');
      expect(
        c.columnCount,
        2,
        reason: 'the transitive chain needs two concurrent lanes, not three',
      );
      expect(a.column, 0);
      expect(b.column, 1);
      expect(c.column, 0);
    });

    test('R4-06 — a transitive bridge cannot place persisted Backup left', () {
      // Primary and Backup do not overlap each other. The bridge overlaps
      // both, which is the exact shape that allowed a reused base column to
      // acquire mixed semantic ownership before the R4 precedence layout.
      final placements = arrange(<PlannerCalendarItem>[
        event('primary', 420, 480),
        event('bridge', 450, 570),
        event('backup', 540, 600, backup: true),
      ]);
      final bridge = placements.singleWhere((p) => p.event.id == 'bridge');
      final backup = placements.singleWhere((p) => p.event.id == 'backup');

      expect(
        backup.column,
        greaterThan(bridge.column),
        reason: 'the persisted Backup must be right of its real blocker',
      );
      expect(backup.spanStart, greaterThanOrEqualTo(bridge.column + 1));
    });

    test('R4-06 — an isolated Backup after a cluster owns full width', () {
      final placements = arrange(<PlannerCalendarItem>[
        event('dominant', 420, 480),
        event('bridge', 450, 540),
        event('backup', 510, 570, backup: true),
        event('isolatedBackup', 570, 630, backup: true),
      ]);
      final isolated = placements.singleWhere(
        (p) => p.event.id == 'isolatedBackup',
      );

      expect(isolated.spanStart ?? isolated.column, 0);
      expect(
        isolated.spanCount ?? 1,
        isolated.columnCount,
        reason: 'no actual overlap may leave an empty special region',
      );
    });
  });
}

double _leftOf(PlannerDisplayPlacement p) {
  final spanWidth = p.spanCount != null;
  if (spanWidth) {
    // Normalized relative to a unit grid of columnCount lanes with a 2px gap:
    // (spanStart * (1/columnCount + gap)) on a 1000px basis for ordering.
    return p.spanStart! * (1000 / p.columnCount + 2);
  }
  return p.column * (1000 / p.columnCount + 2);
}

double _widthOf(PlannerDisplayPlacement p) {
  if (p.spanCount != null) {
    return p.spanCount! * (1000 / p.columnCount);
  }
  if (p.widthFactor != null) {
    return p.widthFactor! * 1000;
  }
  return 1000 / p.columnCount;
}
