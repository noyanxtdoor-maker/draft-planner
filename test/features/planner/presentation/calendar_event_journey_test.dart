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
      await startupRepository.completeOnboarding();

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
      expect(find.text('New Calendar Event'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('event-title-field')),
        'Offline Calendar Event',
      );
      await tester.tap(find.byKey(const Key('event-all-day-switch')));
      await tester.enterText(
        find.byKey(const Key('event-location-field')),
        'Typed location only',
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('save-event-button')),
        find.byType(ListView),
        const Offset(0, -250),
      );
      await tester.tap(find.byKey(const Key('event-requires-report-switch')));
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-event-button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Offline Calendar Event'), findsOneWidget);
      await tester.tap(find.text('Offline Calendar Event'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.byKey(const Key('event-detail-title')), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.textContaining('All day'), findsOneWidget);
      expect(find.text('Typed location only'), findsOneWidget);
      expect(find.text('Report required'), findsOneWidget);
      expect(find.byKey(const Key('edit-event-button')), findsOneWidget);
      expect(find.byKey(const Key('reschedule-event-button')), findsOneWidget);
      expect(find.byKey(const Key('cancel-event-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
