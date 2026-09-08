import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/domain/planner_display_geometry.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_content.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_report_status.dart';

/// Production-content regression for the owner-observed Event-only compact
/// overflow. The heights come from the frozen display geometry, rather than
/// a hand-written approximation, so every assertion exercises the exact
/// Luna transition band that is painted by the Day timeline and pager.
void main() {
  const samples = <double>[44, 45, 48, 52, 56, 59, 60, 88];

  testWidgets(
    '15m Event stays overflow-free across every frozen Luna transition height',
    (tester) async {
      for (final hourHeight in samples) {
        final event = _event(id: 'event-15-$hourHeight', duration: 15);
        final height = _displayHeight(event, hourHeight);

        await tester.pumpWidget(
          _card(
            height: height,
            width: 86,
            child: PlannerEventBlockContentView(
              event: event,
              use24HourTime: false,
              displayStartMinute: 9 * 60,
              displayEndMinute: 9 * 60 + 15,
              awaitingReport: true,
              content: PlannerEventBlockContent.forHeight(
                height,
                interactive: true,
              ),
              titleKey: Key('event-title-$hourHeight'),
              statusKey: Key('event-status-$hourHeight'),
              recurrenceKey: Key('event-recurrence-$hourHeight'),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              '15m Event must not render a bottom RenderFlex overflow at '
              'hourHeight=$hourHeight / visibleHeight=$height',
        );
        expect(
          find.byKey(Key('event-title-$hourHeight')),
          findsOneWidget,
          reason: 'the compact Event retains its title through the transition',
        );
        expect(
          find.byKey(Key('event-status-$hourHeight')),
          findsOneWidget,
          reason: 'Event report status remains Event-owned at compact heights',
        );
        expect(
          height,
          lessThanOrEqualTo(hourHeight),
          reason: 'the test must not introduce an artificial visible height',
        );
      }
    },
  );

  testWidgets(
    '15m Event matches the clean Task control at transition heights and narrow collision width',
    (tester) async {
      for (final hourHeight in samples) {
        final event = _event(id: 'event-task-$hourHeight', duration: 15);
        final height = _displayHeight(event, hourHeight);
        final content = PlannerEventBlockContent.forHeight(
          height,
          interactive: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 86,
              height: height,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: PlannerEventBlockContentView(
                      event: event,
                      use24HourTime: false,
                      displayStartMinute: 9 * 60,
                      displayEndMinute: 9 * 60 + 15,
                      awaitingReport: true,
                      content: content,
                    ),
                  ),
                  Expanded(
                    child: PlannerTaskEventFamilyBlockContentView(
                      title: 'Task control',
                      time: '9:00 AM - 9:15 AM',
                      textColor: Colors.white,
                      status: PlannerReportStatusKind.unreported,
                      content: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              'Event and Task must both fit their mixed-collision lanes at '
              'hourHeight=$hourHeight / visibleHeight=$height',
        );
      }
    },
  );

  testWidgets('30m and 60m Event controls remain clean at all samples', (
    tester,
  ) async {
    for (final duration in <int>[30, 60]) {
      for (final hourHeight in samples) {
        final event = _event(
          id: 'event-$duration-$hourHeight',
          duration: duration,
        );
        final height = _displayHeight(event, hourHeight);
        await tester.pumpWidget(
          _card(
            height: height,
            width: 86,
            child: PlannerEventBlockContentView(
              event: event,
              use24HourTime: false,
              displayStartMinute: 9 * 60,
              displayEndMinute: 9 * 60 + duration,
              awaitingReport: true,
              content: PlannerEventBlockContent.forHeight(
                height,
                interactive: true,
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${duration}m Event must stay overflow-free at hourHeight=$hourHeight',
        );
      }
    }
  });
}

Widget _card({
  required double height,
  required double width,
  required Widget child,
}) {
  return MaterialApp(
    home: SizedBox(width: width, height: height, child: child),
  );
}

double _displayHeight(PlannerCalendarItem event, double hourHeight) {
  return PlannerDisplayGeometry.resolve(
    events: <PlannerCalendarItem>[event],
    hourHeight: hourHeight,
    viewportHeight: 600,
    configuredHours: 12,
  ).single.height;
}

PlannerCalendarItem _event({required String id, required int duration}) {
  final start = DateTime(2026, 8, 28, 9);
  return PlannerCalendarItem(
    id: id,
    title: 'Recurring report Event',
    date: const PlannerDate(year: 2026, month: 8, day: 28),
    timing: PlannerEventTiming.timed,
    state: PlannerEventState.scheduled,
    requiresReport: true,
    hasOutcomeReport: false,
    startLocal: start,
    endLocal: start.add(Duration(minutes: duration)),
    isRecurring: true,
    activityTypeColorValue: 0xFF126E9E,
  );
}
