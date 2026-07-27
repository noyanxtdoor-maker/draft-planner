import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS-01 Android smoke: offline onboarding and relaunch', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create local profile'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);

    final homeContext = tester.element(find.text('Home'));
    GoRouter.of(homeContext).go('/stale-startup-link');
    await tester.pumpAndSettle();
    expect(find.text('Link unavailable'), findsOneWidget);
    expect(find.text('No local record was changed.'), findsOneWidget);
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    final relaunchedRepository = buildTestRepository(database: database);
    final relaunchedPrivacy = TestPrivacyDependencies(database: database);
    await tester.pumpWidget(
      relaunchedPrivacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: relaunchedRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ready offline'), findsOneWidget);
  });
}
