import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

void main() {
  const visibleStartMinute = 6 * 60;
  const visibleEndMinute = 22 * 60;

  test('TEST 1 — one active hour has four equal quarters', () {
    for (final hourHeight in <double>[
      PlannerZoomPolicy.minimumHourHeight,
      PlannerZoomPolicy.normalHourHeight,
      PlannerZoomPolicy.normalHourHeight * 1.5,
    ]) {
      final y00 = PlannerTimelineGeometry.yForMinute(
        minute: 9 * 60,
        visibleStartMinute: visibleStartMinute,
        hourHeight: hourHeight,
      );
      final y15 = PlannerTimelineGeometry.yForMinute(
        minute: 9 * 60 + 15,
        visibleStartMinute: visibleStartMinute,
        hourHeight: hourHeight,
      );
      final y30 = PlannerTimelineGeometry.yForMinute(
        minute: 9 * 60 + 30,
        visibleStartMinute: visibleStartMinute,
        hourHeight: hourHeight,
      );
      final y45 = PlannerTimelineGeometry.yForMinute(
        minute: 9 * 60 + 45,
        visibleStartMinute: visibleStartMinute,
        hourHeight: hourHeight,
      );
      final yNext = PlannerTimelineGeometry.yForMinute(
        minute: 10 * 60,
        visibleStartMinute: visibleStartMinute,
        hourHeight: hourHeight,
      );
      final quarter = hourHeight / 4;
      expect(y15 - y00, closeTo(quarter, 1e-9));
      expect(y30 - y15, closeTo(quarter, 1e-9));
      expect(y45 - y30, closeTo(quarter, 1e-9));
      expect(yNext - y45, closeTo(quarter, 1e-9));
    }
  });

  test('TEST 2 — a 9:45–10:00 Event fits exactly', () {
    const hourHeight = PlannerZoomPolicy.normalHourHeight;
    final geometry = PlannerTimelineGeometry.event(
      startMinute: 9 * 60 + 45,
      endMinute: 10 * 60,
      visibleStartMinute: visibleStartMinute,
      visibleEndMinute: visibleEndMinute,
      hourHeight: hourHeight,
    );

    expect(geometry.clippedStartMinute, 9 * 60 + 45);
    expect(geometry.clippedEndMinute, 10 * 60);
    expect(
      geometry.top,
      closeTo(
        PlannerTimelineGeometry.yForMinute(
          minute: 9 * 60 + 45,
          visibleStartMinute: visibleStartMinute,
          hourHeight: hourHeight,
        ),
        1e-9,
      ),
    );
    expect(geometry.logicalHeight, closeTo(hourHeight / 4, 1e-9));
    expect(geometry.height, greaterThanOrEqualTo(48));
    expect(
      geometry.top + geometry.logicalHeight,
      closeTo(10 * hourHeight - 6 * hourHeight, 1e-9),
    );
  });

  test('TEST 3 — consecutive quarter-hour Events touch without overlap', () {
    final events = <PlannerTimelineEventGeometry>[
      PlannerTimelineGeometry.event(
        startMinute: 9 * 60 + 30,
        endMinute: 9 * 60 + 45,
        visibleStartMinute: visibleStartMinute,
        visibleEndMinute: visibleEndMinute,
        hourHeight: 60,
      ),
      PlannerTimelineGeometry.event(
        startMinute: 9 * 60 + 45,
        endMinute: 10 * 60,
        visibleStartMinute: visibleStartMinute,
        visibleEndMinute: visibleEndMinute,
        hourHeight: 60,
      ),
      PlannerTimelineGeometry.event(
        startMinute: 10 * 60,
        endMinute: 10 * 60 + 15,
        visibleStartMinute: visibleStartMinute,
        visibleEndMinute: visibleEndMinute,
        hourHeight: 60,
      ),
    ];

    for (var index = 0; index < events.length - 1; index++) {
      expect(
        events[index].top + events[index].logicalHeight,
        closeTo(events[index + 1].top, 1e-9),
      );
      expect(events[index].logicalHeight, closeTo(15, 1e-9));
    }
    expect(events.last.logicalHeight, closeTo(15, 1e-9));
  });

  test('TEST 4 — resize snapping preserves a 15-minute minimum', () {
    const startMinute = 9 * 60 + 45;
    final rawEndMinute = 9 * 60 + 58;
    final snappedEndMinute = snapPlannerMinute(rawEndMinute, 15);
    final endMinute = snappedEndMinute.clamp(startMinute + 15, 22 * 60);

    expect(snappedEndMinute, 10 * 60);
    expect(endMinute, 10 * 60);
    expect(endMinute - startMinute, 15);
    expect(
      PlannerTimelineGeometry.heightForDuration(
        durationMinutes: endMinute - startMinute,
        hourHeight: 60,
      ),
      closeTo(15, 1e-9),
    );
  });

  test('TEST 5 — quarter-hour alignment survives supported zoom heights', () {
    for (final hourHeight in <double>[
      PlannerZoomPolicy.minimumHourHeight,
      PlannerZoomPolicy.normalHourHeight,
      PlannerZoomPolicy.normalHourHeight * 1.5,
    ]) {
      final geometry = PlannerTimelineGeometry.event(
        startMinute: 9 * 60 + 45,
        endMinute: 10 * 60,
        visibleStartMinute: visibleStartMinute,
        visibleEndMinute: visibleEndMinute,
        hourHeight: hourHeight,
      );
      expect(geometry.logicalHeight, closeTo(hourHeight / 4, 1e-9));
      expect(geometry.height, greaterThanOrEqualTo(48));
      expect(
        geometry.top + geometry.logicalHeight,
        closeTo(
          PlannerTimelineGeometry.yForMinute(
            minute: 10 * 60,
            visibleStartMinute: visibleStartMinute,
            hourHeight: hourHeight,
          ),
          1e-9,
        ),
      );
    }
  });

  test('TEST 6 — compact content never asks the block to grow', () {
    final height = PlannerTimelineGeometry.heightForDuration(
      durationMinutes: 15,
      hourHeight: PlannerZoomPolicy.normalHourHeight,
    );
    final content = PlannerEventBlockContent.forHeight(
      height,
      interactive: true,
    );

    expect(content.density, Density.veryShort);
    expect(content.titleMaxLines, 1);
    expect(content.showTimeInline, isTrue);
    expect(content.showTime, isFalse);
    expect(content.showStatusIcons, isFalse);
    expect(content.showResizeHandle, isFalse);
  });

  test('TEST 7 — resize hit target cannot spill beyond the visible block', () {
    final geometry = PlannerTimelineGeometry.event(
      startMinute: 9 * 60 + 45,
      endMinute: 10 * 60,
      visibleStartMinute: visibleStartMinute,
      visibleEndMinute: visibleEndMinute,
      hourHeight: PlannerZoomPolicy.normalHourHeight,
    );
    final hitHeight = PlannerEventBlockLayoutPolicy.resizeHitAreaHeight
        .clamp(0.0, geometry.height)
        .toDouble();

    expect(geometry.logicalHeight, closeTo(15, 1e-9));
    expect(geometry.height, greaterThanOrEqualTo(48));
    expect(hitHeight, lessThanOrEqualTo(geometry.height));
    expect(
      geometry.top + geometry.logicalHeight,
      closeTo(10 * 60 / 60 * 60 - 6 * 60, 1e-9),
    );
  });
}
