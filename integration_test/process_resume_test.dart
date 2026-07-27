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

  testWidgets('Q5 process fixture: resume Home after force-stop', (
    tester,
  ) async {
    final database = AppDatabase.defaults();
    addTearDown(database.close);

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
          startupRepositoryProvider.overrideWithValue(
            buildTestRepository(database: database),
          ),
        ],
        child: const NextTransferApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ready offline'), findsOneWidget);
  });
}
