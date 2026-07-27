import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Q5 process fixture: persist a Local Profile before force-stop', (
    tester,
  ) async {
    final database = AppDatabase.defaults();
    final repository = buildTestRepository(database: database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(
            const AppEnvironment(
              name: AppEnvironmentName.production,
              label: 'PRODUCTION',
            ),
          ),
          diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
          startupRepositoryProvider.overrideWithValue(repository),
        ],
        child: const NextTransferApp(),
      ),
    );
    await tester.pumpAndSettle();

    if (find.text('Continue offline').evaluate().isNotEmpty) {
      await tester.tap(find.text('Continue offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create local profile'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Home'), findsOneWidget);
    // Intentionally do not close the database. The workflow force-stops this
    // process, then a separate test proves the committed transaction survives.
  });
}
