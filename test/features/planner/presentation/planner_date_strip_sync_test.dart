import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_date_strip.dart';

const _firstDate = PlannerDate(year: 2026, month: 7, day: 1);
const _selectedDate = PlannerDate(year: 2026, month: 7, day: 27);
const _lastDate = PlannerDate(year: 2026, month: 9, day: 30);

void main() {
  Future<_DateStripHarnessState> pumpStrip(WidgetTester tester) async {
    final key = GlobalKey<_DateStripHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _DateStripHarness(
            key: key,
            firstDate: _firstDate,
            lastDate: _lastDate,
          ),
        ),
      ),
    );
    await tester.pump();
    return key.currentState!;
  }

  double readStripOffset(WidgetTester tester) {
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('planner-date-strip-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    return scrollable.position.pixels;
  }

  Future<void> pumpStripAnimation(WidgetTester tester) async {
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void expectSelected(WidgetTester tester, PlannerDate date) {
    expect(find.byKey(Key('planner-day-${date.iso8601}')), findsOneWidget);
    final semantics = tester.getSemantics(
      find.byKey(const Key('planner-selected-date')),
    );
    expect(semantics.label, contains(date.iso8601));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  }

  testWidgets('TEST 1 — strip drag browses without selecting', (tester) async {
    final harness = await pumpStrip(tester);
    final beforeOffset = readStripOffset(tester);

    await tester.drag(
      find.byKey(const Key('planner-date-strip-scroll')),
      const Offset(-160, 0),
    );
    await tester.pump();

    expect(readStripOffset(tester), isNot(closeTo(beforeOffset, 0.5)));
    expect(harness.selectedDate, _selectedDate);
    expect(harness.selectionCount, 0);
  });

  testWidgets('TEST 2 — tapping a visible date selects it once', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    const tappedDate = PlannerDate(year: 2026, month: 7, day: 28);

    await tester.tap(find.byKey(Key('planner-day-${tappedDate.iso8601}')));
    await tester.pump();

    expect(harness.selectedDate, tappedDate);
    expect(harness.selectionCount, 1);
    expectSelected(tester, tappedDate);
  });

  testWidgets('TEST 3 — left date commit moves selection by one day', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    final target = _selectedDate.addDays(1);
    harness.selectFromPager(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(harness.selectedDate, target);
    expectSelected(tester, target);
  });

  testWidgets('TEST 4 — right date commit moves selection by one day', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    final target = _selectedDate.addDays(-1);
    harness.selectFromPager(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));

    expect(harness.selectedDate, target);
    expectSelected(tester, target);
  });

  testWidgets('TEST 5 — cancelled strip swipe does not select a date', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('planner-date-strip-scroll'))),
    );
    await gesture.moveBy(const Offset(-42, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(harness.selectedDate, _selectedDate);
    expect(harness.selectionCount, 0);
  });

  testWidgets('TEST 6 — fast strip flick remains browsing-only', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    await tester.fling(
      find.byKey(const Key('planner-date-strip-scroll')),
      const Offset(-220, 0),
      1800,
    );
    await tester.pump();

    expect(harness.selectedDate, _selectedDate);
    expect(harness.selectionCount, 0);
  });

  testWidgets('TEST 7 — Today navigation keeps today visible', (tester) async {
    final harness = await pumpStrip(tester);
    const today = PlannerDate(year: 2026, month: 8, day: 15);
    harness.selectFromToday(today);
    await tester.pump();
    await pumpStripAnimation(tester);

    expectSelected(tester, today);
  });

  testWidgets('TEST 8 — picker confirmation selects the confirmed date', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    const picked = PlannerDate(year: 2026, month: 9, day: 29);
    harness.selectFromPicker(picked);
    await tester.pump();
    await pumpStripAnimation(tester);

    expectSelected(tester, picked);
  });

  testWidgets('TEST 9 — picker cancellation makes no change', (tester) async {
    final harness = await pumpStrip(tester);
    harness.cancelPicker();
    await tester.pump();

    expect(harness.selectedDate, _selectedDate);
    expect(harness.selectionCount, 0);
    expectSelected(tester, _selectedDate);
  });

  testWidgets('TEST 10 — repeated date changes do not drift selection', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    final dates = <PlannerDate>[
      _selectedDate.addDays(1),
      _selectedDate.addDays(2),
      _selectedDate.addDays(1),
      _selectedDate,
    ];
    for (final date in dates) {
      harness.selectFromPager(date);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
    }

    expect(harness.selectedDate, _selectedDate);
    expectSelected(tester, _selectedDate);
  });

  testWidgets('TEST 11 — strip selection does not own vertical offset', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    const verticalOffset = 137.0;
    harness.verticalOffset = verticalOffset;
    harness.selectFromPager(_selectedDate.addDays(1));
    await tester.pump();

    expect(harness.verticalOffset, verticalOffset);
  });

  testWidgets('TEST 12 — strip selection does not own zoom', (tester) async {
    final harness = await pumpStrip(tester);
    const hourHeight = 90.0;
    harness.hourHeight = hourHeight;
    harness.selectFromToday(_selectedDate.addDays(1));
    await tester.pump();

    expect(harness.hourHeight, hourHeight);
  });

  testWidgets('TEST 13 — direct strip gesture never pages the timeline', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    await tester.drag(
      find.byKey(const Key('planner-date-strip-scroll')),
      const Offset(-240, 0),
    );
    await tester.pump();

    expect(harness.selectionCount, 0);
    expect(harness.pagerCommitCount, 0);
    expect(harness.selectedDate, _selectedDate);
  });

  testWidgets('TEST 14 — pager date update does not directly drag the strip', (
    tester,
  ) async {
    final harness = await pumpStrip(tester);
    final beforeOffset = readStripOffset(tester);
    harness.selectFromPager(_selectedDate.addDays(1));
    await tester.pump();

    expect(harness.pagerCommitCount, 1);
    expect(harness.selectionCount, 0);
    expect(harness.selectedDate, _selectedDate.addDays(1));
    expect(readStripOffset(tester), closeTo(beforeOffset, 0.5));
  });
}

final class _DateStripHarness extends StatefulWidget {
  const _DateStripHarness({
    super.key,
    required this.firstDate,
    required this.lastDate,
  });

  final PlannerDate firstDate;
  final PlannerDate lastDate;

  @override
  State<_DateStripHarness> createState() => _DateStripHarnessState();
}

final class _DateStripHarnessState extends State<_DateStripHarness> {
  PlannerDate selectedDate = _selectedDate;
  int selectionCount = 0;
  int pagerCommitCount = 0;
  double verticalOffset = 0;
  double hourHeight = 60;

  void _select(PlannerDate date) {
    setState(() {
      selectedDate = date;
      selectionCount += 1;
    });
  }

  void selectFromPager(PlannerDate date) {
    setState(() {
      selectedDate = date;
      pagerCommitCount += 1;
    });
  }

  void selectFromToday(PlannerDate date) {
    setState(() => selectedDate = date);
  }

  void selectFromPicker(PlannerDate date) {
    setState(() => selectedDate = date);
  }

  void cancelPicker() {}

  @override
  Widget build(BuildContext context) {
    return PlannerDateStrip(
      selectedDate: selectedDate,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      onSelected: _select,
    );
  }
}
