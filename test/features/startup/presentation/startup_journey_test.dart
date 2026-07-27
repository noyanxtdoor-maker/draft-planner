import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'AC-A-001..014,016,017,019,020: accessible offline UI reaches Home',
    (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = buildTestRepository(database: database);
      final privacy = TestPrivacyDependencies(database: database);

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: SanitizedDiagnostics(),
          startupRepository: repository,
        ),
      );
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Continue offline'), findsOneWidget);
      expect(find.textContaining('account are not required'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Continue offline with a private Local Profile'),
        findsOneWidget,
      );
      final laterAccountPrompt = find.textContaining(
        'choose account setup later',
      );
      await tester.dragUntilVisible(
        laterAccountPrompt,
        find.byType(ListView),
        const Offset(0, -160),
      );
      expect(laterAccountPrompt, findsOneWidget);
      await tester.dragUntilVisible(
        find.text('Continue offline'),
        find.byType(ListView),
        const Offset(0, 160),
      );

      await tester.tap(find.text('Continue offline'));
      await tester.pumpAndSettle();
      expect(find.text('Display name (optional)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Offline UI user');
      await tester.pumpAndSettle();
      final permissionNotice = find.text(
        'No Android permission will be requested during onboarding.',
      );
      await tester.dragUntilVisible(
        permissionNotice,
        find.byType(ListView),
        const Offset(0, -180),
      );
      expect(permissionNotice, findsOneWidget);
      await tester.tap(find.text('Create local profile'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Welcome, Offline UI user'), findsOneWidget);
      expect(find.text('Ready offline'), findsOneWidget);
      expect(find.text('Not connected — optional'), findsOneWidget);
      expect(find.text('Weekly targets are not set'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final homeContext = tester.element(find.text('Home'));
      GoRouter.of(homeContext).go('/invalid-startup-link');
      await tester.pumpAndSettle();
      expect(find.text('Link unavailable'), findsOneWidget);
      expect(find.text('No local record was changed.'), findsOneWidget);
      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('AC-A-019: welcome remains usable at 200% text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);

    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: buildTestRepository(database: database),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Continue offline'),
      find.byType(ListView),
      const Offset(0, -180),
    );
    expect(find.text('Continue offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC-A-009,010,018: startup failure exposes safe recovery', (
    tester,
  ) async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: const FailingStartupRepository(),
      ),
    );
    for (var frame = 0; frame < 6; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Local data needs attention'), findsOneWidget);
    expect(
      find.textContaining('did not erase or recreate your local data'),
      findsOneWidget,
    );
    expect(find.text('Retry local startup'), findsOneWidget);
    expect(
      find.textContaining('VS-01 provides no automatic reset'),
      findsOneWidget,
    );
  });
}
