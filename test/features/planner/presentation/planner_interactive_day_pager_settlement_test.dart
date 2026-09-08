import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_settings.dart';
import 'package:rmplanner/features/planner/domain/planner_view.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_interactive_day_pager.dart';

const _pagerStartDate = PlannerDate(year: 2026, month: 7, day: 27);
const _pagerWidth = 320.0;

void main() {
  late _PagerHarnessState harness;

  Future<void> pumpPager(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: _PagerHarness()));
    harness = tester.state<_PagerHarnessState>(find.byType(_PagerHarness));
    await tester.pump();
  }

  double readLiveDragOffset(WidgetTester tester) {
    final viewportWidth = tester
        .getSize(find.byKey(const Key('planner-day-pager-viewport')))
        .width;
    final strip = tester.widget<Transform>(
      find.byKey(const Key('planner-day-pager-strip')),
    );
    return strip.transform.getTranslation().x + viewportWidth;
  }

  Future<void> pumpUntilCommit(
    WidgetTester tester, {
    List<double>? preCommitOffsets,
    required int previousCommitCount,
  }) async {
    for (
      var frame = 0;
      frame < 40 && harness.commitCount <= previousCommitCount;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
      if (harness.commitCount <= previousCommitCount) {
        preCommitOffsets?.add(readLiveDragOffset(tester));
      }
    }
    await tester.pump();
  }

  Future<void> driveSwipe(
    WidgetTester tester, {
    required double dx,
    int steps = 8,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('planner-day-pager-viewport'))),
    );
    for (var index = 0; index < steps; index++) {
      await gesture.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
  }

  testWidgets('TEST 1 — slow left commit is directionally monotonic', (
    tester,
  ) async {
    await pumpPager(tester);
    final offsets = <double>[];
    await driveSwipe(tester, dx: -220);
    await pumpUntilCommit(
      tester,
      preCommitOffsets: offsets,
      previousCommitCount: 0,
    );

    expect(harness.commitCount, 1);
    expect(harness.selectedDate, _pagerStartDate.addDays(1));
    expect(readLiveDragOffset(tester).abs(), lessThan(0.5));
    for (var index = 1; index < offsets.length; index++) {
      expect(
        offsets[index],
        lessThanOrEqualTo(offsets[index - 1] + 0.5),
        reason: 'left settlement must never reverse toward the old page',
      );
    }
  });

  testWidgets('TEST 2 — slow right commit is directionally monotonic', (
    tester,
  ) async {
    await pumpPager(tester);
    final offsets = <double>[];
    await driveSwipe(tester, dx: 220);
    await pumpUntilCommit(
      tester,
      preCommitOffsets: offsets,
      previousCommitCount: 0,
    );

    expect(harness.commitCount, 1);
    expect(harness.selectedDate, _pagerStartDate.addDays(-1));
    expect(readLiveDragOffset(tester).abs(), lessThan(0.5));
    for (var index = 1; index < offsets.length; index++) {
      expect(
        offsets[index],
        greaterThanOrEqualTo(offsets[index - 1] - 0.5),
        reason: 'right settlement must never reverse toward the old page',
      );
    }
  });

  testWidgets('TEST 3 — fast left flick commits exactly one day', (
    tester,
  ) async {
    await pumpPager(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('planner-day-pager-viewport'))),
    );
    await gesture.moveBy(const Offset(-50, 0));
    await gesture.up(timeStamp: const Duration(milliseconds: 1));
    await pumpUntilCommit(tester, previousCommitCount: 0);

    expect(harness.commitCount, 1);
    expect(harness.selectedDate, _pagerStartDate.addDays(1));
    expect(readLiveDragOffset(tester).abs(), lessThan(0.5));
    expect(
      find.byKey(Key('pager-current-${harness.selectedDate.iso8601}')),
      findsOneWidget,
    );
  });

  testWidgets('TEST 4 — fast right flick commits exactly one day', (
    tester,
  ) async {
    await pumpPager(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('planner-day-pager-viewport'))),
    );
    await gesture.moveBy(const Offset(50, 0));
    await gesture.up(timeStamp: const Duration(milliseconds: 1));
    await pumpUntilCommit(tester, previousCommitCount: 0);

    expect(harness.commitCount, 1);
    expect(harness.selectedDate, _pagerStartDate.addDays(-1));
    expect(readLiveDragOffset(tester).abs(), lessThan(0.5));
  });

  testWidgets('TEST 5 — repeated alternating swipes do not drift', (
    tester,
  ) async {
    await pumpPager(tester);
    await driveSwipe(tester, dx: -220);
    await pumpUntilCommit(tester, previousCommitCount: 0);
    await driveSwipe(tester, dx: 220);
    await pumpUntilCommit(tester, previousCommitCount: 1);
    await driveSwipe(tester, dx: -220);
    await pumpUntilCommit(tester, previousCommitCount: 2);
    await driveSwipe(tester, dx: 220);
    await pumpUntilCommit(tester, previousCommitCount: 3);

    expect(harness.commitCount, 4);
    expect(harness.selectedDate, _pagerStartDate);
    expect(readLiveDragOffset(tester).abs(), lessThan(0.5));
  });

  testWidgets('TEST 6 — cancelled swipe leaves the centered page intact', (
    tester,
  ) async {
    await pumpPager(tester);
    await driveSwipe(tester, dx: -40, steps: 8);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(harness.commitCount, 0);
    expect(harness.selectedDate, _pagerStartDate);
    expect(readLiveDragOffset(tester).abs(), lessThan(0.5));
  });
}

final class _PagerHarness extends StatefulWidget {
  const _PagerHarness();

  @override
  State<_PagerHarness> createState() => _PagerHarnessState();
}

final class _PagerHarnessState extends State<_PagerHarness> {
  PlannerDate selectedDate = _pagerStartDate;
  int commitCount = 0;
  final ValueNotifier<DateTime> currentTime = ValueNotifier<DateTime>(
    DateTime(2026, 7, 27, 12),
  );

  @override
  void dispose() {
    currentTime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previousDate = selectedDate.addDays(-1);
    final nextDate = selectedDate.addDays(1);
    return SizedBox(
      width: _pagerWidth,
      height: 480,
      child: PlannerInteractiveDayPager(
        key: const Key('planner-day-pager-viewport'),
        selectedDate: selectedDate,
        previousDate: previousDate,
        nextDate: nextDate,
        previousDay: null,
        currentDay: null,
        nextDay: null,
        today: _pagerStartDate,
        settings: const PlannerSettings.defaults(),
        hourHeight: PlannerZoomPolicy.normalHourHeight,
        timelineHeight: 480,
        viewportWidth: _pagerWidth,
        onSwipePointerDown: () {},
        onSwipePointerUp: () {},
        onSwipeCancel: () {},
        onPinchPointerCount: () => 0,
        onPinchClearCancel: () {},
        onDayChanged: (delta) {
          setState(() {
            commitCount += 1;
            selectedDate = selectedDate.addDays(delta);
          });
        },
        currentPage: ColoredBox(
          color: Colors.transparent,
          child: SizedBox.expand(
            key: Key('pager-current-${selectedDate.iso8601}'),
          ),
        ),
        currentTimeListenable: currentTime,
      ),
    );
  }
}
