import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_content.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

const _canvasKey = Key('backup-accent-golden-canvas');
const _accentKey = Key('backup-accent-test-strip');
const _surfaceKey = Key('backup-surface-test-region');
const _date = PlannerDate(year: 2026, month: 8, day: 3);
const _accent = Color(0xFF9B63D0);
const _surface = Color(0xFF4A474F);

void main() {
  testWidgets('backup painter receives only the fixed accent bounds', (
    tester,
  ) async {
    await _pumpCanvas(
      tester,
      _backupBlock(height: 120, child: const SizedBox.expand()),
      height: 140,
    );

    final accentSize = tester.getSize(find.byKey(_accentKey));
    final painterSize = tester.getSize(
      find.descendant(
        of: find.byKey(_accentKey),
        matching: find.byType(CustomPaint),
      ),
    );
    final surfaceSize = tester.getSize(find.byKey(_surfaceKey));

    expect(accentSize.width, PlannerEventBlockLayoutPolicy.eventAccentWidth);
    expect(accentSize.width, inInclusiveRange(4.0, 5.0));
    expect(painterSize, accentSize);
    expect(surfaceSize.width, greaterThan(accentSize.width));
    expect(surfaceSize.height, accentSize.height);
    expect(
      find.descendant(
        of: find.byType(PlannerBackupStripeBackground),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PlannerBackupStripeBackground),
        matching: find.byType(ClipPath),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PlannerBackupStripeBackground),
        matching: find.byType(Stack),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('backup accent geometry stays fixed across duration and zoom', (
    tester,
  ) async {
    const heights = <double>[24, 36, 48, 60, 120, 240, 360];
    for (final height in heights) {
      await _pumpCanvas(
        tester,
        _backupBlock(height: height),
        height: height + 16,
      );
      expect(
        tester.getSize(find.byKey(_accentKey)).width,
        PlannerEventBlockLayoutPolicy.eventAccentWidth,
        reason: 'accent width changed at visual height $height',
      );
      expect(tester.takeException(), isNull);
    }

    expect(
      PlannerEventBlockLayoutPolicy.backupStripeDark,
      const Color(0xFF1B1C1D),
    );
    expect(
      PlannerEventBlockLayoutPolicy.backupStripeWidth,
      inInclusiveRange(2.0, 3.0),
    );
    expect(
      PlannerEventBlockLayoutPolicy.backupStripeSpacing -
          PlannerEventBlockLayoutPolicy.backupStripeWidth -
          1,
      inInclusiveRange(1.0, 2.0),
    );
  });

  testWidgets('backup content, recurrence, and reporting remain readable', (
    tester,
  ) async {
    final event = _event(
      id: 'backup-reporting-recurring',
      title: 'Backup Teaching',
      endMinute: 720,
      recurring: true,
    );
    await _pumpCanvas(
      tester,
      _backupBlock(event: event, height: 120, awaitingReport: true),
      height: 140,
    );

    expect(find.text('Backup Teaching'), findsOneWidget);
    expect(find.text('10:00 AM - 12:00 PM'), findsOneWidget);
    expect(find.byKey(const Key('backup-test-recurrence')), findsOneWidget);
    expect(find.byKey(const Key('backup-test-status')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  _goldenTests();
}

void _goldenTests() {
  testWidgets('golden 01 normal Event', (tester) async {
    await _pumpCanvas(tester, _normalBlock(height: 80), height: 100);
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/01_normal.png'),
    );
  });

  testWidgets('golden 02 Backup Event at 30 minutes', (tester) async {
    await _pumpCanvas(tester, _backupBlock(height: 48), height: 68);
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/02_backup_30m.png'),
    );
  });

  testWidgets('golden 03 Backup Event at 60 minutes', (tester) async {
    await _pumpCanvas(tester, _backupBlock(height: 80), height: 100);
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/03_backup_60m.png'),
    );
  });

  testWidgets('golden 04 Backup Event at 4 hours', (tester) async {
    await _pumpCanvas(tester, _backupBlock(height: 240), height: 260);
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/04_backup_4h.png'),
    );
  });

  testWidgets('golden 05 Backup and normal overlap', (tester) async {
    await _pumpCanvas(
      tester,
      SizedBox(
        width: 320,
        height: 80,
        child: Row(
          children: <Widget>[
            Expanded(child: _normalBlock(height: 80)),
            const SizedBox(width: 4),
            Expanded(child: _backupBlock(height: 80)),
          ],
        ),
      ),
      height: 100,
    );
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/05_overlap.png'),
    );
  });

  testWidgets('golden 06 Backup Event at minimum zoom', (tester) async {
    await _pumpCanvas(tester, _backupBlock(height: 24), height: 44);
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/06_min_zoom.png'),
    );
  });

  testWidgets('golden 07 Backup Event at maximum zoom', (tester) async {
    await _pumpCanvas(tester, _backupBlock(height: 240), height: 260);
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/07_max_zoom.png'),
    );
  });

  testWidgets('golden 08 Backup Event with recurrence icon', (tester) async {
    await _pumpCanvas(
      tester,
      _backupBlock(height: 90, recurring: true),
      height: 110,
    );
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/08_recurrence.png'),
    );
  });

  testWidgets('golden 09 Backup Event with reporting icon', (tester) async {
    await _pumpCanvas(
      tester,
      _backupBlock(height: 90, awaitingReport: true),
      height: 110,
    );
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/09_reporting.png'),
    );
  });

  testWidgets('golden 10 Backup Event uses customized saved colors', (
    tester,
  ) async {
    await _pumpCanvas(
      tester,
      _backupBlock(
        height: 90,
        accent: const Color(0xFFE48CCB),
        surface: const Color(0xFF514A54),
        title: 'Customized Backup',
      ),
      height: 110,
    );
    await expectLater(
      find.byKey(_canvasKey),
      matchesGoldenFile('goldens/backup_event_accent/10_custom_color.png'),
    );
  });
}

Future<void> _pumpCanvas(
  WidgetTester tester,
  Widget child, {
  required double height,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: RepaintBoundary(
          key: _canvasKey,
          child: SizedBox(
            width: 320,
            height: height,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _normalBlock({required double height}) {
  final event = _event(id: 'normal-$height', title: 'Normal Event');
  return _eventBlock(
    event: event,
    height: height,
    surface: _surface,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _accent,
            width: PlannerEventBlockLayoutPolicy.eventAccentWidth,
          ),
        ),
      ),
      child: _content(event: event, height: height),
    ),
  );
}

Widget _backupBlock({
  double height = 80,
  PlannerCalendarItem? event,
  Widget? child,
  bool recurring = false,
  bool awaitingReport = false,
  Color accent = _accent,
  Color surface = _surface,
  String title = 'Backup Event',
}) {
  final resolvedEvent =
      event ??
      _event(
        id: 'backup-$height-$title',
        title: title,
        endMinute: 600 + height.round(),
        recurring: recurring,
      );
  return _eventBlock(
    event: resolvedEvent,
    height: height,
    surface: surface,
    child: PlannerBackupStripeBackground(
      accent: accent,
      surfaceColor: surface,
      accentKey: _accentKey,
      surfaceKey: _surfaceKey,
      child:
          child ??
          _content(
            event: resolvedEvent,
            height: height,
            accent: accent,
            surface: surface,
            awaitingReport: awaitingReport,
            recurrenceKey: resolvedEvent.isRecurring
                ? const Key('backup-test-recurrence')
                : null,
            statusKey: awaitingReport ? const Key('backup-test-status') : null,
          ),
    ),
  );
}

Widget _eventBlock({
  required PlannerCalendarItem event,
  required double height,
  required Color surface,
  required Widget child,
}) {
  return SizedBox(
    width: 304,
    height: height,
    child: Material(
      color: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          PlannerEventBlockLayoutPolicy.eventBorderRadius,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

Widget _content({
  required PlannerCalendarItem event,
  required double height,
  Color accent = _accent,
  Color surface = _surface,
  bool awaitingReport = false,
  Key? recurrenceKey,
  Key? statusKey,
}) {
  return PlannerEventBlockContentView(
    event: event,
    accentColor: accent,
    surfaceColor: surface,
    use24HourTime: false,
    displayStartMinute: 600,
    displayEndMinute: 600 + height.round(),
    awaitingReport: awaitingReport,
    content: PlannerEventBlockContent.forHeight(height, interactive: false),
    titleKey: const Key('backup-test-title'),
    timeKey: const Key('backup-test-time'),
    recurrenceKey: recurrenceKey,
    statusKey: statusKey,
  );
}

PlannerCalendarItem _event({
  required String id,
  required String title,
  int endMinute = 660,
  bool recurring = false,
}) {
  return PlannerCalendarItem(
    id: id,
    title: title,
    date: _date,
    timing: PlannerEventTiming.timed,
    state: PlannerEventState.scheduled,
    requiresReport: true,
    hasOutcomeReport: false,
    startLocal: DateTime(2026, 8, 3, 10),
    endLocal: DateTime(2026, 8, 3, endMinute ~/ 60, endMinute % 60),
    isRecurring: recurring,
    activityTypeId: 'study-or-plan',
    activityTypeLabel: 'Study or Plan',
    activityTypeColorValue: _accent.toARGB32(),
    isBackupAppointment: true,
  );
}
