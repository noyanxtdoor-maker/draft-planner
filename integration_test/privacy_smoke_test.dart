import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';

import '../test/support/test_dependencies.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('VS-02 Android smoke: enable, background, and unlock', (
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Privacy and Data'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('privacy-lock-switch')));
    await tester.pumpAndSettle();
    expect((await privacy.repository.readSettings()).lockEnabled, isTrue);

    final privacyContainer = privacy.createContainer();
    addTearDown(privacyContainer.dispose);
    final privacyController = privacyContainer.read(
      privacyControllerProvider.notifier,
    );
    await privacyController.initialize();
    final relocked = privacyController.lockForBackground();
    expect(relocked, isTrue);
    expect(await privacy.gate.isUnlockRequired(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startupRepository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Next Transfer is locked'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unlock-button')));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
