// Preview-center Event geometry parity regression test
// (Preview / Center Event Geometry Parity Correction pack).
//
// The read-only pager preview must paint the EXACT same rectangle as the
// centered timeline for the same canonical placement, viewport width, and
// time gutter (R9 parity contract). The test drives the REAL production
// preview helper (`PlannerPagerEventHorizontalGeometry.resolve` in
// planner_interactive_day_pager.dart) against the centered timeline's
// `_horizontalGeometry` formula (replicated here as the reference; the
// production method is private and must not be exposed just for tests).
//
// This test FAILS on the accepted S2B baseline (9d2d120) because the
// preview historically added +5dp to every Event left and subtracted 8dp
// from the content width; it passes only after the correction.
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_display_geometry.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_interactive_day_pager.dart';

const double _timeColumnWidth = 56.0; // PlannerCurrentTimeHorizontalGeometry
const double _laneGap = 2.0; // PlannerEventBlockLayoutPolicy.eventLaneGap

const _date = PlannerDate(year: 2026, month: 8, day: 12);

PlannerCalendarItem _event(
  String id,
  int startMinute,
  int endMinute, {
  bool backup = false,
}) {
  return PlannerCalendarItem(
    id: id,
    title: id,
    date: _date,
    timing: PlannerEventTiming.timed,
    state: PlannerEventState.scheduled,
    requiresReport: false,
    hasOutcomeReport: false,
    startLocal: DateTime(2026, 8, 12, startMinute ~/ 60, startMinute % 60),
    endLocal: DateTime(2026, 8, 12, endMinute ~/ 60, endMinute % 60),
    isBackupAppointment: backup,
  );
}

/// The centered timeline's horizontal geometry (planner_screen.dart
/// `_horizontalGeometry`), replicated as the parity reference. The pack
/// explicitly forbids modifying planner_screen.dart to expose it.
({double left, double width}) _centerHorizontal(
  PlannerDisplayPlacement placement,
  double totalWidth,
) {
  final availableWidth = totalWidth - _timeColumnWidth;
  final splitWidth = placement.widthFactor != null;
  final spanWidth = placement.spanCount != null;
  final widthBasis = splitWidth && !spanWidth
      ? availableWidth - _laneGap
      : availableWidth - _laneGap * (placement.columnCount - 1);
  final baseColumnWidth = widthBasis / placement.columnCount;
  final width = spanWidth
      ? baseColumnWidth * placement.spanCount! +
            _laneGap * (placement.spanCount! - 1)
      : splitWidth
      ? widthBasis * placement.widthFactor!
      : baseColumnWidth;
  final left = spanWidth
      ? _timeColumnWidth + placement.spanStart! * (baseColumnWidth + _laneGap)
      : splitWidth
      ? _timeColumnWidth +
            (widthBasis * placement.offsetFactor!) +
            (placement.column > 0 ? _laneGap : 0)
      : _timeColumnWidth + placement.column * (width + _laneGap);
  return (left: left, width: width);
}

List<PlannerDisplayPlacement> _resolve(List<PlannerCalendarItem> events) {
  return PlannerDisplayGeometry.resolve(
    events: events,
    hourHeight: 60,
    viewportHeight: 700,
    configuredHours: 24,
  );
}

void _expectParity(List<PlannerDisplayPlacement> placements, double width) {
  for (final placement in placements) {
    final preview = PlannerPagerEventHorizontalGeometry.resolve(
      placement: placement,
      width: width,
      timeColumnWidth: _timeColumnWidth,
      laneGap: _laneGap,
    );
    final center = _centerHorizontal(placement, width);
    expect(
      preview.left,
      closeTo(center.left, 1e-6),
      reason:
          '${placement.event.id} @ W=$width: preview left ${preview.left} '
          '!= center left ${center.left}',
    );
    expect(
      preview.width,
      closeTo(center.width, 1e-6),
      reason:
          '${placement.event.id} @ W=$width: preview width ${preview.width} '
          '!= center width ${center.width}',
    );
  }
}

void main() {
  const widths = <double>[320, 360, 393, 412, 600];

  // Exact owner Aug 12 fixture (forensic audit; Scripture 4:30 = 4:30-5:00).
  final ownerFixture = <PlannerCalendarItem>[
    _event('cada4dea-ministering', 180, 510),
    _event('4423b81a-scripture-0430', 270, 300),
    _event('6af5056a-exercise-0500', 300, 360),
    _event('b4c8c578-scripture-0515', 315, 345),
    _event('20f233d4-exercise-0630', 390, 420),
    _event('b1fcbfc4-ride-0730', 450, 480),
    _event('530cc260-ministering-0745', 465, 495),
    _event('0b31f383-exercise-0815', 495, 705),
    _event('08c45bac-temple-0900', 540, 570),
    _event('df517941-scripture-0915', 555, 690),
    _event('7a9917d2-temple-1115', 675, 705),
    _event('a7a2e128-temple-1330', 810, 840),
    _event('f66163b9-study-1545', 945, 975),
    _event('23425f1f-study-1730', 1050, 1080),
  ];

  test('isolated Event preview == center at every width', () {
    final placements = _resolve([_event('iso', 9 * 60, 10 * 60)]);
    for (final w in widths) {
      _expectParity(placements, w);
    }
  });

  test('2-column layout parity at every width', () {
    final placements = _resolve([
      _event('a', 9 * 60, 10 * 60),
      _event('b', 9 * 60 + 30, 10 * 60 + 30),
    ]);
    for (final w in widths) {
      _expectParity(placements, w);
    }
  });

  test('3-column layout parity at every width', () {
    final placements = _resolve([
      _event('a', 9 * 60, 11 * 60),
      _event('b', 9 * 60 + 30, 10 * 60 + 30),
      _event('c', 10 * 60, 10 * 60 + 30),
    ]);
    expect(placements.map((p) => p.columnCount).toSet(), {3});
    for (final w in widths) {
      _expectParity(placements, w);
    }
  });

  test('multi-lane span parity (owner fixture) at every width', () {
    final placements = _resolve(ownerFixture);
    final scripture = placements.singleWhere(
      (p) => p.event.id == '4423b81a-scripture-0430',
    );
    // Lane output is unchanged from the forensic audit: col 0/3, span 0..1.
    expect(scripture.column, 0);
    expect(scripture.columnCount, 3);
    expect(scripture.spanStart, 0);
    expect(scripture.spanCount, 2);
    for (final w in widths) {
      _expectParity(placements, w);
    }
  });

  test('rightmost-lane placement parity at every width', () {
    final placements = _resolve(ownerFixture);
    final ministering = placements.singleWhere(
      (p) => p.event.id == 'cada4dea-ministering',
    );
    expect(ministering.column, 2);
    expect(ministering.spanStart, 2);
    for (final w in widths) {
      _expectParity(placements, w);
    }
  });

  test('Backup Event placement parity at every width', () {
    final placements = _resolve([
      _event('primary', 9 * 60, 10 * 60),
      _event('backup', 9 * 60 + 30, 10 * 60, backup: true),
    ]);
    for (final w in widths) {
      _expectParity(placements, w);
    }
  });

  test('owner Aug 12 fixture: every Event matches center exactly at W=393', () {
    final placements = _resolve(ownerFixture);
    _expectParity(placements, 393);
  });

  test('owner 4:30 Scripture block renders the exact audit rectangle', () {
    final placements = _resolve(ownerFixture);
    final scripture = placements.singleWhere(
      (p) => p.event.id == '4423b81a-scripture-0430',
    );
    final preview = PlannerPagerEventHorizontalGeometry.resolve(
      placement: scripture,
      width: 393,
      timeColumnWidth: _timeColumnWidth,
      laneGap: _laneGap,
    );
    // Forensic audit measured (pack 06): preview must equal center exactly:
    // left 56.0 / width 224.0 (baseline preview was 61.0 / 218.7).
    expect(preview.left, closeTo(56.0, 1e-6));
    expect(preview.width, closeTo(224.0, 1e-6));
    final center = _centerHorizontal(scripture, 393);
    expect(preview.left, closeTo(center.left, 1e-6));
    expect(preview.width, closeTo(center.width, 1e-6));
  });
}
