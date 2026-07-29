import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS-04 Android smoke: offline Calendar Event create and detail', (
    tester,
  ) async {
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
        plannerDateSource: const FixedPlannerDateSource(
          PlannerDate(year: 2026, month: 7, day: 27),
        ),
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
    expect(find.text('Select Event Type'), findsOneWidget);
    await tester.tap(find.byKey(const Key('event-type-option-general')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('event-title-field')),
      'Android offline Calendar Event',
    );
    await tester.tap(find.byKey(const Key('event-all-day-switch')));
    await tester.dragUntilVisible(
      find.byKey(const Key('save-event-button')),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-event-button')));
    await tester.pumpAndSettle();

    expect(find.text('Android offline Calendar Event'), findsOneWidget);
    await tester.tap(find.text('Android offline Calendar Event'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('event-detail-title')), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.textContaining('All day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
