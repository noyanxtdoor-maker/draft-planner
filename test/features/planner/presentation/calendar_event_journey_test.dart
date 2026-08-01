import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../../../support/test_dependencies.dart';

void main() {
  const selected = PlannerDate(year: 2026, month: 7, day: 27);

  testWidgets(
    'AC-E-001..006,012,017,020,021: create and inspect an offline Event',
    (tester) async {
      tester.view.physicalSize = const Size(862, 1824);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      final profile = await startupRepository.completeOnboarding();

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: startupRepository,
          plannerDateSource: const FixedPlannerDateSource(selected),
          plannerIdentifierSource: SequenceIdentifierSource(<String>[
            '22222222-2222-4222-8222-222222222222',
            '11111111-1111-4111-8111-111111111111',
          ]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planner'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('planner-create-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-calendar-event-action')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Select Event Type'), findsOneWidget);
      expect(find.text('New Calendar Event'), findsNothing);
      await tester.tap(find.byKey(const Key('event-type-option-general')));
      await tester.pumpAndSettle();
      expect(find.text('New Calendar Event'), findsNothing);
      expect(find.text('General'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'form opened');
      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Offline Calendar Event',
      );
      final allDaySwitch = find.byKey(const Key('event-all-day-switch'));
      for (var attempt = 0; attempt < 8; attempt++) {
        if (allDaySwitch.evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(
          find.byKey(const Key('calendar-event-form-scroll')),
          const Offset(0, -220),
        );
        await tester.pumpAndSettle();
      }
      expect(allDaySwitch, findsOneWidget);
      await tester.tap(allDaySwitch);
      expect(tester.takeException(), isNull, reason: 'all-day selected');
      final formScrollable = find.byElementPredicate((element) {
        if (element.widget is! Scrollable || element is! StatefulElement) {
          return false;
        }
        final state = element.state;
        return state is ScrollableState &&
            state.position.viewportDimension > 100 &&
            element.findAncestorWidgetOfExactType<ListView>()?.key ==
                const Key('calendar-event-form-scroll');
      });
      final addLocation = find.byKey(const Key('add-location-button'));
      final formState = tester.state<ScrollableState>(formScrollable.at(0));
      Future<void> reveal(Finder target) async {
        for (var attempt = 0; attempt < 12; attempt++) {
          if (target.evaluate().isNotEmpty) {
            return;
          }
          formState.position.jumpTo(
            (formState.position.pixels + 260)
                .clamp(0, formState.position.maxScrollExtent)
                .toDouble(),
          );
          await tester.pumpAndSettle();
        }
        expect(target, findsOneWidget);
      }

      final backupOffset = formState.position.maxScrollExtent - 350;
      formState.position.jumpTo(backupOffset < 0 ? 0 : backupOffset);
      await tester.pumpAndSettle();
      await tester.tap(addLocation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'location revealed');
      await tester.enterText(
        find.byKey(const Key('event-location-field')),
        'Typed location only',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'location entered');
      final reportOffset = formState.position.maxScrollExtent - 350;
      formState.position.jumpTo(reportOffset < 0 ? 0 : reportOffset);
      await tester.pumpAndSettle();
      final backupSwitch = find.byKey(
        const Key('event-backup-appointment-switch'),
      );
      formState.position.jumpTo(0);
      await tester.pumpAndSettle();
      await reveal(backupSwitch);
      await tester.ensureVisible(backupSwitch);
      await tester.pumpAndSettle();
      await tester.tap(backupSwitch);
      formState.position.jumpTo(formState.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final reportSwitch = find.byKey(
        const Key('event-requires-report-switch'),
      );
      await reveal(reportSwitch);
      await tester.ensureVisible(reportSwitch);
      await tester.pumpAndSettle();
      await tester.tap(reportSwitch);
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // VS-08 patch removed the all-day lane from Day view; all-day records
      // remain preserved in storage and surface through Schedule, Search, and
      // Event details. Verify persistence directly through the database so
      // the "Save persists one Event" and "All-day records remain preserved"
      // locked behaviors are still asserted.
      final savedAllDay =
          await (database.select(database.calendarEvents)
                ..where((row) => row.title.equals('Offline Calendar Event')))
              .getSingle();
      expect(savedAllDay.title, 'Offline Calendar Event');
      expect(savedAllDay.timing, 'allDay');
      expect(savedAllDay.locationText, 'Typed location only');
      expect(savedAllDay.requiresReport, isTrue);
      expect(savedAllDay.isBackupAppointment, isTrue);
      expect(savedAllDay.profileId, profile.id);
      // No all-day fixture renders on the Day timeline any more.
      expect(find.text('Offline Calendar Event'), findsNothing);
      expect(find.byKey(const Key('all-day-section')), findsNothing);
      // The 'General' activity-type chip is still surfaced through the new
      // selected-type indicator on the create form, so make sure no stale
      // Day-view fixture text remains.
      expect(tester.takeException(), isNull);
    },
  );
}
