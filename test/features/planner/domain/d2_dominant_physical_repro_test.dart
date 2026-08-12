import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_display_geometry.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';

/// Physical-device reproduction: the live Aug 7 2026 day rendered with the
/// 22-hour "Study or Plan" Event (00:00-22:00). R5 replaces the overridden
/// dominant-left rule with canonical class order:
/// Normal Regular < Normal Dominant < Backup Regular < Backup Dominant.
void main() {
  PlannerCalendarItem item(
    String id,
    int startMinute,
    int endMinute, {
    bool backup = false,
    String title = '',
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
      title: title,
      date: PlannerDate.parse('2026-08-07'),
      timing: PlannerEventTiming.timed,
      state: PlannerEventState.scheduled,
      requiresReport: false,
      hasOutcomeReport: false,
      startLocal: start,
      endLocal: end,
      isBackupAppointment: backup,
    );
  }

  // Effective occurrence state for 2026-08-07 (latest exception per
  // occurrence wins), pulled from the live device database.
  final events = <PlannerCalendarItem>[
    item('study-22h', 0, 1320, title: 'Study or Plan'), // dominant
    item('job-0030', 30, 90, title: 'Job'),
    item('scripture-0120', 120, 150, title: 'Scripture'),
    item('exercise-0120', 120, 180, title: 'Exercise'),
    item('study-0195', 195, 255, title: 'Study or Plan'),
    item('work-0255', 255, 270, title: 'Work'),
    item('temple-0285', 285, 405, title: 'Temple Visit'),
    item('scripture-0300', 300, 315, title: 'Scripture'),
    item('service-0330', 330, 525, title: 'Service'),
    item('meal-0375', 375, 1230, title: 'Meal'),
    item('scriptureStudy-0450', 450, 480, title: 'Scripture Study'),
    item('scriptureStudy-0540', 540, 570, title: 'Scripture Study'),
    item('contact-0540', 540, 630, title: 'Contact'),
    item('job-0570', 570, 825, title: 'Job'),
    item('scripture-0675', 675, 705, title: 'Scripture'),
    item('study-0705', 705, 780, title: 'Study or Plan'),
    item('contact-0720', 720, 780, title: 'Contact'),
    item('ministering-0795', 795, 810, title: 'Ministering'),
    item('budget-0900', 900, 960, title: 'Budget Review'),
    item('service-0990', 990, 1050, title: 'Service'),
    item('temple-1005', 1005, 1125, title: 'Temple Visit'),
    item('travel-1080', 1080, 1140, title: 'Travel'),
    item('work-1125', 1125, 1200, title: 'Work'),
    item('job-1140', 1140, 1155, title: 'Job'),
    item('other-1140', 1140, 1200, title: 'Other'),
    item('meeting-1200', 1200, 1260, title: 'Meeting'),
  ];

  void expectR5ClassOrder(Map<String, int> byId) {
    for (var leftIndex = 0; leftIndex < events.length; leftIndex += 1) {
      final left = events[leftIndex];
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < events.length;
        rightIndex += 1
      ) {
        final right = events[rightIndex];
        final overlaps =
            left.startLocal!.isBefore(right.endLocal!) &&
            right.startLocal!.isBefore(left.endLocal!);
        if (!overlaps) {
          continue;
        }
        final leftColumn = byId[left.id]!;
        final rightColumn = byId[right.id]!;
        expect(
          leftColumn,
          isNot(rightColumn),
          reason: '${left.id} and ${right.id} truly overlap',
        );
        final leftClass = PlannerTimelineLayout.laneClassOf(left);
        final rightClass = PlannerTimelineLayout.laneClassOf(right);
        if (leftClass.index < rightClass.index) {
          expect(leftColumn, lessThan(rightColumn));
        } else if (rightClass.index < leftClass.index) {
          expect(rightColumn, lessThan(leftColumn));
        }
      }
    }
    expect(
      PlannerTimelineLayout.laneClassOf(
        events.singleWhere((event) => event.id == 'study-22h'),
      ),
      PlannerTimelineLaneClass.normalDominant,
    );
    expect(
      byId['study-22h'],
      greaterThan(0),
      reason: 'overlapping Normal Regular Events must precede the 22h ND card',
    );
  }

  test('R5-03 canonical arrange: physical repro follows class order', () {
    final placements = PlannerTimelineLayout.arrange(events, hourHeight: 60);
    final byId = <String, int>{
      for (final p in placements) p.event.id: p.column,
    };
    expectR5ClassOrder(byId);
  });

  test(
    'R5-03 zoomed-out resolve keeps the same physical-repro class order',
    () {
      // The phone renders the overview at minimum hour height, which routes
      // through PlannerDisplayGeometry.resolve (assistance > 0). Lane identity
      // must remain deterministic and independent of readability geometry.
      final placements = PlannerDisplayGeometry.resolve(
        events: events,
        hourHeight: 17,
        viewportHeight: 724,
        configuredHours: 24,
      );
      final byId = <String, int>{
        for (final p in placements) p.event.id: p.column,
      };
      expectR5ClassOrder(byId);
      final canonical = PlannerTimelineLayout.arrange(events, hourHeight: 60);
      for (final placement in canonical) {
        expect(byId[placement.event.id], placement.column);
      }
      // The dominant must never share a column with a colliding short card.
      final dominant = placements.singleWhere((p) => p.event.id == 'study-22h');
      for (final p in placements) {
        if (p.event.id == 'study-22h') {
          continue;
        }
        if (p.column != dominant.column) {
          continue;
        }
        final overlap =
            p.top < dominant.top + dominant.height &&
            dominant.top < p.top + p.height;
        expect(
          overlap,
          isFalse,
          reason: '${p.event.id} collides with dominant',
        );
      }
    },
  );
}
