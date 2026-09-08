import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Q5 process fixture: resume Home after force-stop', (
    tester,
  ) async {
    final database = AppDatabase.defaults();
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

    expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
    expect(find.text('Ready offline'), findsOneWidget);
  });
}
