import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/planner/data/calendar_event_time_zones.dart';
import 'package:rmplanner/features/planner/data/drift_calendar_event_repository.dart';
import 'package:rmplanner/features/planner/data/drift_planner_repository.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS-05 Android smoke: link Task and Event offline', (
    tester,
  ) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startupRepository = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    final profile = await startupRepository.completeOnboarding();
    const date = PlannerDate(year: 2026, month: 7, day: 27);
    const taskId = '20000000-0000-4000-8000-000000000001';
    const eventId = '30000000-0000-4000-8000-000000000001';
    await DriftPlannerRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
    ).saveTask(
      profileId: profile.id,
      draft: const PlannerTaskDraft(
        id: taskId,
        title: 'Prepare visit',
        dueDate: date,
        requiresReport: false,
      ),
    );
    await DriftCalendarEventRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 7, 27, 12)),
      timeZones: IanaCalendarEventTimeZones(displayTimeZoneId: 'Asia/Manila'),
    ).saveEvent(
      profileId: profile.id,
      draft: const CalendarEventDraft(
        id: eventId,
        title: 'Visit appointment',
        timing: CalendarEventTiming.allDay,
        startDate: date,
        requiresReport: false,
      ),
    );

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startupRepository,
        plannerDateSource: const FixedPlannerDateSource(date),
        plannerIdentifierSource: SequenceIdentifierSource(<String>[
          '40000000-0000-4000-8000-000000000001',
          '50000000-0000-4000-8000-000000000001',
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner'));
    await tester.pumpAndSettle();
    unawaited(
      GoRouter.of(
        tester.element(find.byKey(const Key('planner-day-scroll'))),
      ).push('/tasks/$taskId'),
    );
    await tester.pumpAndSettle();
    final manageLinks = find.byKey(const Key('manage-task-event-links'));
    await tester.dragUntilVisible(
      manageLinks,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(manageLinks);
    await tester.pumpAndSettle();
    final eventCandidate = find.byKey(const Key('link-event-$eventId'));
    await tester.dragUntilVisible(
      eventCandidate,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(eventCandidate);
    await tester.pumpAndSettle();

    expect(find.text('Visit appointment'), findsWidgets);
    expect(find.textContaining('Source: Task'), findsOneWidget);
    expect(find.textContaining('contributes nothing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
