import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_interactive_day_pager.dart';

const _frameStart = PlannerDate(year: 2026, month: 7, day: 27);
const _frameWidth = 320.0;
const _frameHeight = 480.0;

void main() {
  testWidgets(
    'production page keys stay date-consistent while both commit directions await data',
    (tester) async {
      final key = GlobalKey<_FrameHarnessState>();
      await tester.pumpWidget(MaterialApp(home: _FrameHarness(key: key)));
      await tester.pump();

      for (final direction in <double>[-1, 1]) {
        final harness = key.currentState!;
        final oldDate = harness.selectedDate;
        final delta = direction < 0 ? 1 : -1;
        final targetDate = oldDate.addDays(delta);
        final viewport = find.byKey(const Key('planner-day-pager-viewport'));
        final gesture = await tester.startGesture(tester.getCenter(viewport));
        await gesture.moveBy(Offset(direction * 240, 0));
        await tester.pump(const Duration(milliseconds: 16));
        await gesture.up();

        await _pumpUntil(tester, () => key.currentState!.commitRequested);
        expect(
          key.currentState!.selectedDate,
          oldDate,
          reason: 'selectedDate must remain unchanged while data is pending',
        );
        expect(
          find.byKey(Key('planner-day-page-${targetDate.iso8601}')),
          findsOneWidget,
          reason: 'the destination page must carry its production date key',
        );

        final oldContent = find.byKey(
          Key('planner-authoritative-page-${oldDate.iso8601}'),
        );
        final oldLeft = tester.getTopLeft(oldContent).dx;
        if (direction < 0) {
          expect(
            oldLeft,
            lessThan(0),
            reason:
                'left commit must leave old authoritative content offscreen',
          );
        } else {
          expect(
            oldLeft,
            greaterThanOrEqualTo(_frameWidth),
            reason:
                'right commit must leave old authoritative content offscreen',
          );
        }

        key.currentState!.completePending();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(key.currentState!.selectedDate, targetDate);
        expect(
          key.currentState!.commitCount,
          direction < 0 ? 1 : 2,
          reason: 'each direction must issue exactly one additional commit',
        );
        expect(
          find.byKey(Key('planner-authoritative-page-${targetDate.iso8601}')),
          findsOneWidget,
          reason: 'new authoritative content must be visible after one commit',
        );
        expect(
          tester
              .getTopLeft(
                find.byKey(
                  Key('planner-authoritative-page-${targetDate.iso8601}'),
                ),
              )
              .dx,
          closeTo(0, 1),
        );
        expect(
          find.byKey(Key('planner-authoritative-page-${oldDate.iso8601}')),
          findsNothing,
          reason: 'old authoritative content must not flash after recenter',
        );
      }
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 40; frame++) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  fail('pager commit did not reach the pending-data boundary');
}

final class _FrameHarness extends StatefulWidget {
  const _FrameHarness({super.key});

  @override
  State<_FrameHarness> createState() => _FrameHarnessState();
}

final class _FrameHarnessState extends State<_FrameHarness> {
  final PlannerInteractiveDayPagerController pagerController =
      PlannerInteractiveDayPagerController();
  final ValueNotifier<DateTime> currentTime = ValueNotifier<DateTime>(
    DateTime(2026, 7, 27, 12),
  );

  PlannerDate selectedDate = _frameStart;
  Completer<void>? _pendingCommit;
  bool commitRequested = false;
  int commitCount = 0;

  @override
  void dispose() {
    pagerController.dispose();
    currentTime.dispose();
    super.dispose();
  }

  void completePending() {
    final pending = _pendingCommit;
    _pendingCommit = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  Future<void> _onDayChanged(int delta) {
    commitRequested = true;
    final pending = Completer<void>();
    _pendingCommit = pending;
    return pending.future.then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        selectedDate = selectedDate.addDays(delta);
        commitCount += 1;
        commitRequested = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final previousDate = selectedDate.addDays(-1);
    final nextDate = selectedDate.addDays(1);
    return SizedBox(
      width: _frameWidth,
      height: _frameHeight,
      child: PlannerInteractiveDayPager(
        key: const Key('planner-day-pager-viewport'),
        controller: pagerController,
        selectedDate: selectedDate,
        previousDate: previousDate,
        nextDate: nextDate,
        previousDay: null,
        currentDay: null,
        nextDay: null,
        today: _frameStart,
        settings: const PlannerSettings.defaults(),
        hourHeight: 60,
        timelineHeight: _frameHeight,
        viewportWidth: _frameWidth,
        onSwipePointerDown: () {},
        onSwipePointerUp: () {},
        onSwipeCancel: () {},
        onPinchPointerCount: () => 0,
        onPinchClearCancel: () {},
        onDayChanged: _onDayChanged,
        currentPage: ColoredBox(
          color: Colors.transparent,
          child: SizedBox.expand(
            key: Key('planner-authoritative-page-${selectedDate.iso8601}'),
          ),
        ),
        currentTimeListenable: currentTime,
      ),
    );
  }
}
