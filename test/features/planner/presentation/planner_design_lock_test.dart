import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_timeline_layout.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_date_strip.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_top_bar_icons.dart';

import '../../../support/test_dependencies.dart';

const _selected = PlannerDate(year: 2026, month: 7, day: 27);
const _firstStripDate = PlannerDate(year: 2026, month: 7, day: 20);
const _lastStripDate = PlannerDate(year: 2026, month: 8, day: 10);

void main() {
  testWidgets('DESIGN LOCK 1 — Planner title is present', (tester) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-date-label-row')), findsOneWidget);
    expect(find.text('Jul 27'), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 2 — Planner dropdown arrow is present', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-date-chevron')), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 3 — hamburger is present', (tester) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-hamburger')), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 4 — calendar control is in the top bar', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    final appBar = find.byType(AppBar);
    expect(
      find.descendant(
        of: appBar,
        matching: find.byKey(const Key('planner-calendar-button')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('planner-calendar-button'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('planner-week-strip'))).dy,
      ),
    );
  });

  testWidgets('DESIGN LOCK 5 — filter control is present', (tester) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-filter-button')), findsOneWidget);
  });

  test('DESIGN LOCK 5A - filter uses the approved asymmetric silhouette', () {
    final path = PlannerFunnelIconPainter.pathFor(const Size.square(28));
    final bounds = path.getBounds();
    expect(bounds.left, closeTo(3.0, 0.1));
    expect(bounds.right, closeTo(25.0, 0.1));
    expect(bounds.top, closeTo(4.5, 0.1));
    expect(bounds.bottom, closeTo(22.9, 0.1));
    expect(path.computeMetrics().single.isClosed, isTrue);
  });

  testWidgets('DESIGN LOCK 5B - top bar and date strip use approved surfaces', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    expect(appBar.backgroundColor, Colors.black);
    final strip = tester.widget<DecoratedBox>(
      find.byKey(const Key('planner-date-strip-surface')),
    );
    final decoration = strip.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.surface);
    expect(decoration.border?.bottom.width, 1);
  });

  testWidgets('DESIGN LOCK 6 — selection control is present', (tester) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-selection-button')), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 7 — overflow control is present', (tester) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-overflow-button')), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 8 — restored toolbar actions keep semantics', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    expect(find.bySemanticsLabel('Go to today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('planner-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-filter-menu')), findsOneWidget);
    await tester.tapAt(const Offset(12, 12));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('planner-overflow-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('planner-overflow-menu')), findsOneWidget);
  });

  testWidgets(
    'DESIGN LOCK 8A — top-bar icons use the approved shapes and feedback',
    (tester) async {
      await _pumpPlanner(tester);

      expect(find.byType(PlannerFilterIcon), findsOneWidget);
      expect(find.byType(PlannerSelectionIcon), findsOneWidget);

      IconButton topBarButton(Finder scope) {
        return tester.widget<IconButton>(
          find.descendant(of: scope, matching: find.byType(IconButton)),
        );
      }

      for (final key in <String>[
        'planner-hamburger',
        'planner-filter-button',
        'planner-selection-button',
        'planner-overflow-button',
      ]) {
        final button = topBarButton(find.byKey(Key(key)));
        expect(
          button.style?.overlayColor?.resolve(<WidgetState>{
            WidgetState.pressed,
          }),
          Colors.white.withValues(alpha: 0.14),
          reason: '$key must use white transient press feedback',
        );
        expect(
          button.style?.shape?.resolve(<WidgetState>{}),
          isA<CircleBorder>(),
          reason: '$key must use circular, not rectangular, feedback',
        );
      }

      final calendarInk = tester.widget<InkWell>(
        find.byKey(const Key('planner-today-button')),
      );
      expect(calendarInk.customBorder, isA<CircleBorder>());
      expect(calendarInk.highlightColor, Colors.white.withValues(alpha: 0.12));
      expect(calendarInk.splashColor, Colors.white.withValues(alpha: 0.16));
    },
  );

  testWidgets('DESIGN LOCK 9 — date strip remains compact', (tester) async {
    await _pumpPlanner(tester);
    final strip = tester.getSize(find.byKey(const Key('planner-week-strip')));
    expect(strip.height, lessThanOrEqualTo(72));
    final list = tester.getSize(
      find.byKey(const Key('planner-date-strip-scroll')),
    );
    expect(
      list.width / PlannerDateStrip.itemExtent,
      inInclusiveRange(5.5, 8.5),
    );
  });

  testWidgets('DESIGN LOCK 10 — strip has no duplicate calendar icon', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('planner-week-strip')),
        matching: find.byKey(const Key('planner-calendar-button')),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('planner-calendar-button')), findsOneWidget);
  });

  testWidgets(
    'DESIGN LOCK 11 — selected and unselected cells match dimensions',
    (tester) async {
      final harness = await _pumpStrip(tester);
      final selectedSize = tester.getSize(
        find.byKey(Key('planner-day-${harness.selectedDate.iso8601}')),
      );
      final unselectedSize = tester.getSize(
        find.byKey(
          Key('planner-day-${harness.selectedDate.addDays(1).iso8601}'),
        ),
      );
      expect(selectedSize, unselectedSize);
    },
  );

  testWidgets('DESIGN LOCK 12 — one shared liquid indicator exists', (
    tester,
  ) async {
    await _pumpStrip(tester);
    expect(
      find.byKey(const Key('planner-selected-date-indicator')),
      findsNothing,
    );
    expect(find.byKey(const Key('planner-selected-date')), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 13 — live progress moves the indicator', (
    tester,
  ) async {
    final harness = await _pumpStrip(tester);
    final strip = find.byKey(const Key('planner-date-strip-live-transform'));
    final before = tester.widget<Transform>(strip).transform.getTranslation().x;
    harness.progress.value = -0.5;
    await tester.pump();
    final after = tester.widget<Transform>(strip).transform.getTranslation().x;
    expect(after, lessThan(before));
  });

  testWidgets('DESIGN LOCK 14 — cancelled swipe restores the indicator', (
    tester,
  ) async {
    final harness = await _pumpStrip(tester);
    final strip = find.byKey(const Key('planner-date-strip-live-transform'));
    final before = tester.widget<Transform>(strip).transform.getTranslation().x;
    harness.progress.value = -0.6;
    await tester.pump();
    harness.progress.value = 0;
    await tester.pump();
    final after = tester.widget<Transform>(strip).transform.getTranslation().x;
    expect(after, closeTo(before, 0.01));
    expect(harness.selectedDate, _selected);
    expect(harness.selectionCount, 0);
  });

  testWidgets('DESIGN LOCK 15 — successful swipe settles once', (tester) async {
    final harness = await _pumpStrip(tester);
    harness.progress.value = -1;
    await tester.pump();
    harness.controller.prepareForPagerCommit(1);
    harness.commitFromPager(1);
    harness.progress.value = 0;
    await tester.pumpAndSettle();
    expect(harness.selectedDate, _selected.addDays(1));
    expect(harness.pagerCommitCount, 1);
    expect(harness.selectionCount, 0);
    expect(
      find.byKey(Key('planner-day-${harness.selectedDate.iso8601}')),
      findsOneWidget,
    );
  });

  testWidgets('DESIGN LOCK 16 — date tap animates the indicator', (
    tester,
  ) async {
    final harness = await _pumpStrip(tester);
    await tester.tap(
      find.byKey(Key('planner-day-${_selected.addDays(1).iso8601}')),
    );
    await tester.pumpAndSettle();
    expect(harness.selectedDate, _selected.addDays(1));
    expect(find.byKey(const Key('planner-selected-date')), findsOneWidget);
  });

  testWidgets('DESIGN LOCK 17 — direct strip drag only browses', (
    tester,
  ) async {
    final harness = await _pumpStrip(tester);
    await tester.drag(
      find.byKey(const Key('planner-date-strip-scroll')),
      const Offset(-180, 0),
    );
    await tester.pump();
    expect(harness.progress.value, 0);
    expect(harness.pagerCommitCount, 0);
    expect(harness.selectionCount, 0);
    expect(harness.selectedDate, _selected);
  });

  testWidgets('DESIGN LOCK 18 — quarter-hour guide lines are absent', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    expect(
      find.byWidgetPredicate(
        (widget) => widget.key.toString().contains('quarter-hour-line'),
      ),
      findsNothing,
    );
  });

  testWidgets('DESIGN LOCK 19 — full-hour lines remain', (tester) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('planner-full-hour-line-6')), findsOneWidget);
    expect(
      find.byKey(const Key('planner-pager-full-hour-line-6')),
      findsNWidgets(2),
    );
  });

  test('DESIGN LOCK 20 — 9:45–10:00 ends exactly at 10:00', () {
    const hourHeight = 60.0;
    final geometry = PlannerTimelineGeometry.event(
      startMinute: 9 * 60 + 45,
      endMinute: 10 * 60,
      visibleStartMinute: 6 * 60,
      visibleEndMinute: 22 * 60,
      hourHeight: hourHeight,
    );
    expect(geometry.logicalHeight, hourHeight / 4);
    // Combined-delta exact-duration geometry: the rendered height equals the
    // true 15-minute slice with no minimum-height inflation.
    expect(geometry.height, closeTo(hourHeight / 4, 1e-9));
    expect(geometry.top + geometry.logicalHeight, 4 * hourHeight);
  });

  test(
    'DESIGN LOCK 21 — Event cards use compact radius, accent, and content policy',
    () {
      expect(
        PlannerEventBlockLayoutPolicy.eventBorderRadius,
        lessThanOrEqualTo(3),
      );
      expect(
        PlannerEventBlockLayoutPolicy.eventAccentWidth,
        lessThanOrEqualTo(3),
      );
      expect(
        PlannerEventBlockLayoutPolicy.backupEventAccentWidth,
        equals(PlannerEventBlockLayoutPolicy.eventAccentWidth),
      );
      for (final height in <double>[20, 40, 60, 120]) {
        final content = PlannerEventBlockContent.forHeight(
          height,
          interactive: true,
        );
        expect(content.titleMaxLines, greaterThanOrEqualTo(1));
        expect(content.showTimeInline || content.showTime, isTrue);
      }
    },
  );

  testWidgets('DESIGN LOCK 22 — bottom navigation and FAB remain unchanged', (
    tester,
  ) async {
    await _pumpPlanner(tester);
    expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Planner'), findsOneWidget);
    expect(find.byKey(const Key('planner-create-button')), findsOneWidget);
  });

  testWidgets('WALKTHROUGH 1 — date strip is edge-to-edge without a card', (
    tester,
  ) async {
    await _pumpStrip(tester);
    final strip = find.byKey(const Key('planner-week-strip'));
    final scaffold = find.byType(Scaffold);
    expect(
      tester.getTopLeft(strip).dx,
      closeTo(tester.getTopLeft(scaffold).dx, 0.1),
    );
    expect(
      tester.getSize(strip).width,
      closeTo(tester.getSize(scaffold).width, 0.1),
    );
    expect(tester.widget(strip), isA<SizedBox>());
    expect(
      find.descendant(of: strip, matching: find.byType(Container)),
      findsNothing,
    );
  });

  testWidgets(
    'WALKTHROUGH 2 — calendar rest state has only transient feedback',
    (tester) async {
      await _pumpPlanner(tester);
      final surface = tester.widget<Material>(
        find.byKey(const Key('planner-calendar-button-surface')),
      );
      expect(surface.color, Colors.transparent);
      final button = tester.widget<InkWell>(
        find.byKey(const Key('planner-today-button')),
      );
      expect(button.customBorder, isA<CircleBorder>());
      expect(button.highlightColor, Colors.white.withValues(alpha: 0.12));
      expect(button.splashColor, Colors.white.withValues(alpha: 0.16));
      expect(find.bySemanticsLabel('Go to today'), findsOneWidget);
    },
  );
}

Future<void> _pumpPlanner(WidgetTester tester) async {
  tester.view.physicalSize = const Size(411, 731);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final database = openMemoryDatabase();
  addTearDown(database.close);
  final privacy = TestPrivacyDependencies(database: database);
  final startup = buildTestRepository(
    database: database,
    privacyGate: privacy.gate,
  );
  await startup.completeOnboarding();
  await tester.pumpWidget(
    privacy.buildApp(
      environment: const AppEnvironment(
        name: AppEnvironmentName.production,
        label: 'PRODUCTION',
      ),
      diagnostics: SanitizedDiagnostics(),
      startupRepository: startup,
      plannerDateSource: const FixedPlannerDateSource(_selected),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Planner'));
  await tester.pumpAndSettle();
}

Future<_StripHarnessState> _pumpStrip(WidgetTester tester) async {
  tester.view.physicalSize = const Size(411, 731);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey<_StripHarnessState>();
  final progress = ValueNotifier<double>(0);
  final controller = PlannerDateStripController();
  addTearDown(progress.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _StripHarness(
          key: key,
          progress: progress,
          controller: controller,
        ),
      ),
    ),
  );
  await tester.pump();
  return key.currentState!;
}

final class _StripHarness extends StatefulWidget {
  const _StripHarness({
    super.key,
    required this.progress,
    required this.controller,
  });

  final ValueNotifier<double> progress;
  final PlannerDateStripController controller;

  @override
  State<_StripHarness> createState() => _StripHarnessState();
}

final class _StripHarnessState extends State<_StripHarness> {
  PlannerDate selectedDate = _selected;
  int selectionCount = 0;
  int pagerCommitCount = 0;

  ValueNotifier<double> get progress => widget.progress;
  PlannerDateStripController get controller => widget.controller;

  void _select(PlannerDate date) {
    setState(() {
      selectedDate = date;
      selectionCount += 1;
    });
  }

  void commitFromPager(int delta) {
    setState(() {
      selectedDate = selectedDate.addDays(delta);
      pagerCommitCount += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlannerDateStrip(
      selectedDate: selectedDate,
      firstDate: _firstStripDate,
      lastDate: _lastStripDate,
      pagerProgress: progress,
      controller: controller,
      onSelected: _select,
    );
  }
}
