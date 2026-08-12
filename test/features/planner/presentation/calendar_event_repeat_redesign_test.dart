import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/presentation/calendar_event_custom_repeat_screen.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const start = PlannerDate(year: 2026, month: 8, day: 9);

  testWidgets(
    'Delta 4.2F: custom Week supports Sunday plus Tuesday and All tri-state',
    (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: _CustomRepeatLauncher()));

      await tester.tap(find.byKey(const Key('open-custom-repeat')));
      await tester.pumpAndSettle();

      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Repeats Every'), findsOneWidget);
      expect(find.text('Days'), findsOneWidget);
      Checkbox all() => tester.widget<Checkbox>(
        find.byKey(const Key('custom-repeat-all-weekdays')),
      );
      CheckboxListTile weekday(int value) => tester.widget<CheckboxListTile>(
        find.byKey(Key('custom-repeat-weekday-$value')),
      );
      expect(all().value, isNull, reason: 'one selected day is indeterminate');
      expect(weekday(DateTime.sunday).value, isTrue);
      expect(weekday(DateTime.tuesday).value, isFalse);

      await tester.tap(find.byKey(const Key('custom-repeat-weekday-2')));
      await tester.pump();
      expect(weekday(DateTime.tuesday).value, isTrue);
      expect(all().value, isNull);

      await tester.tap(find.byKey(const Key('custom-repeat-all-weekdays')));
      await tester.pump();
      expect(all().value, isTrue);
      for (var value = DateTime.monday; value <= DateTime.sunday; value++) {
        expect(weekday(value).value, isTrue);
      }

      await tester.tap(find.byKey(const Key('custom-repeat-all-weekdays')));
      await tester.pump();
      expect(all().value, isFalse);
      for (var value = DateTime.monday; value <= DateTime.sunday; value++) {
        expect(weekday(value).value, isFalse);
      }

      await tester.tap(find.byKey(const Key('custom-repeat-weekday-2')));
      await tester.tap(find.byKey(const Key('custom-repeat-weekday-7')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('custom-repeat-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom-result-frequency')), findsOneWidget);
      expect(find.text('weekly'), findsOneWidget);
      expect(find.text('2,7'), findsOneWidget);
    },
  );

  testWidgets(
    'Delta 4.2F: custom Day hides weekdays and Month keeps both meanings',
    (tester) async {
      tester.view.physicalSize = const Size(393, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: _CustomRepeatLauncher()));
      await tester.tap(find.byKey(const Key('open-custom-repeat')));
      await tester.pumpAndSettle();

      Future<void> selectUnit(String label) async {
        await tester.tap(find.byKey(const Key('custom-repeat-unit')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await selectUnit('Day');
      expect(find.text('Days'), findsNothing);
      expect(find.byKey(const Key('custom-repeat-weekday-7')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('custom-repeat-interval')),
        '3',
      );
      await tester.pump();

      await selectUnit('Month');
      expect(find.text('Monthly on day 9'), findsOneWidget);
      expect(find.text('Monthly on second Sunday'), findsOneWidget);
      await tester.tap(find.byKey(const Key('custom-repeat-month-nth')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('custom-repeat-back')));
      await tester.pumpAndSettle();

      expect(find.text('monthly'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('nthWeekday'), findsOneWidget);
    },
  );

  testWidgets(
    'Delta 4.2F: main Repeat list is exact and assigns concrete PMG ends',
    (tester) async {
      tester.view.physicalSize = const Size(393, 874);
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
      Future<void> pumpUi() async {
        await tester.pump();
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startup,
          plannerDateSource: const FixedPlannerDateSource(start),
        ),
      );
      await pumpUi();
      await tester.tap(find.text('Planner'));
      await pumpUi();
      await tester.tap(find.byKey(const Key('planner-create-button')));
      await pumpUi();
      await tester.tap(find.byKey(const Key('create-calendar-event-action')));
      await pumpUi();
      final other = find.byKey(const Key('event-type-option-other'));
      await tester.ensureVisible(other);
      await tester.tap(other);
      await pumpUi();

      final repeat = find.byKey(const Key('event-recurrence-frequency'));
      final formScroll = find.byKey(const Key('calendar-event-form-scroll'));
      expect(formScroll, findsOneWidget);
      Future<void> revealFormTarget(Finder target) async {
        for (var attempt = 0; attempt <= 16; attempt++) {
          if (target.evaluate().isNotEmpty) {
            await tester.ensureVisible(target.first);
            await pumpUi();
            return;
          }
          final currentScrollable = find.descendant(
            of: find.byKey(const Key('calendar-event-form-scroll')),
            matching: find.byType(Scrollable),
          );
          final formState = tester.state<ScrollableState>(
            currentScrollable.first,
          );
          final offset =
              formState.position.maxScrollExtent * (attempt / 16).clamp(0, 1);
          formState.position.jumpTo(offset);
          await pumpUi();
        }
        expect(target, findsOneWidget);
      }

      await revealFormTarget(repeat);
      await tester.tap(repeat);
      await pumpUi();
      for (final label in const <String>[
        'Does not repeat',
        'Every day',
        'Every week',
        'Every month',
        'Every year',
        'Custom...',
      ]) {
        expect(find.text(label), findsWidgets);
      }

      // The menu is already open from the exact-list assertion.
      await tester.tap(find.text('Every day').last);
      await pumpUi();
      final endRepeat = find.byKey(const Key('event-recurrence-end-date'));
      await revealFormTarget(endRepeat);
      expect(endRepeat, findsWidgets);
      expect(find.text('Friday, October 9, 2026'), findsOneWidget);
      await tester.tap(endRepeat.last);
      await pumpUi();
      expect(
        find.byKey(const Key('planner-date-picker-panel')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('planner-date-picker-cancel')));
      await pumpUi();

      await revealFormTarget(repeat);
      await tester.tap(repeat);
      await pumpUi();
      await tester.tap(find.text('Every week').last);
      await pumpUi();
      expect(find.text('Monday, November 9, 2026'), findsOneWidget);

      await revealFormTarget(repeat);
      await tester.tap(repeat);
      await pumpUi();
      await tester.tap(find.text('Every month').last);
      await pumpUi();
      expect(find.text('Tuesday, February 9, 2027'), findsOneWidget);

      await revealFormTarget(repeat);
      await tester.tap(repeat);
      await pumpUi();
      await tester.tap(find.text('Every year').last);
      await pumpUi();
      expect(find.text('Wednesday, August 9, 2028'), findsOneWidget);

      await revealFormTarget(repeat);
      await tester.tap(repeat);
      await pumpUi();
      await tester.tap(find.text('Custom...').last);
      await pumpUi();
      expect(find.byKey(const Key('custom-repeat-screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('custom-repeat-weekday-2')));
      await pumpUi();
      await tester.tap(find.byKey(const Key('custom-repeat-back')));
      await pumpUi();
      await revealFormTarget(endRepeat);
      expect(find.text('Monday, November 9, 2026'), findsOneWidget);
      expect(await database.select(database.calendarEvents).get(), isEmpty);
      await tester.tap(find.byKey(const Key('save-event-button')));
      await pumpUi();
      final row = await database.select(database.calendarEvents).getSingle();
      expect(row.recurrenceFrequency, 'weekly');
      expect(row.recurrenceEndMode, 'onDate');
      expect(row.recurrenceEndDate, '2026-11-09');
      expect(
        calendarRecurrencePatternFromJson(
          row.recurrencePatternJson,
        )?.weeklyWeekdays,
        <int>{DateTime.tuesday, DateTime.sunday},
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

final class _CustomRepeatLauncher extends StatefulWidget {
  const _CustomRepeatLauncher();

  @override
  State<_CustomRepeatLauncher> createState() => _CustomRepeatLauncherState();
}

final class _CustomRepeatLauncherState extends State<_CustomRepeatLauncher> {
  CalendarCustomRepeatResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          FilledButton(
            key: const Key('open-custom-repeat'),
            onPressed: () async {
              final result = await Navigator.of(context)
                  .push<CalendarCustomRepeatResult>(
                    MaterialPageRoute<CalendarCustomRepeatResult>(
                      builder: (_) => const CalendarEventCustomRepeatScreen(
                        startDate: PlannerDate(year: 2026, month: 8, day: 9),
                      ),
                    ),
                  );
              if (mounted) {
                setState(() => _result = result);
              }
            },
            child: const Text('Open'),
          ),
          if (_result != null) ...<Widget>[
            Text(
              _result!.frequency.name,
              key: const Key('custom-result-frequency'),
            ),
            Text(_result!.pattern.interval.toString()),
            Text((_result!.pattern.weeklyWeekdays.toList()..sort()).join(',')),
            Text(_result!.pattern.monthlyMode.name),
          ],
        ],
      ),
    );
  }
}
