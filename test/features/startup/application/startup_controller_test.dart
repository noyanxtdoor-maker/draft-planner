import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test(
    'AC-A-001..017: controller completes an offline journey and relaunches home',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final repository = buildTestRepository(database: database);
      final diagnostics = SanitizedDiagnostics();
      final container = ProviderContainer(
        overrides: [
          startupRepositoryProvider.overrideWithValue(repository),
          diagnosticsProvider.overrideWithValue(diagnostics),
        ],
      );
      addTearDown(container.dispose);

      await container.read(startupControllerProvider.notifier).initialize();
      expect(container.read(startupControllerProvider), isA<StartupWelcome>());

      await container
          .read(startupControllerProvider.notifier)
          .continueLocalOnly();
      expect(
        container.read(startupControllerProvider),
        isA<StartupOnboarding>(),
      );

      await container
          .read(startupControllerProvider.notifier)
          .saveDraft('Offline user');
      await container
          .read(startupControllerProvider.notifier)
          .completeOnboarding();
      final ready = container.read(startupControllerProvider);
      expect(ready, isA<StartupReady>());
      expect((ready as StartupReady).profile.displayName, 'Offline user');

      await container.read(startupControllerProvider.notifier).initialize();
      final relaunched = container.read(startupControllerProvider);
      expect(relaunched, isA<StartupReady>());
      expect((relaunched as StartupReady).profile.id, ready.profile.id);
    },
  );

  test('AC-A-018: privacy gate precedes Home after local resolution', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final unlockedRepository = buildTestRepository(database: database);
    await unlockedRepository.completeOnboarding();
    final protectedRepository = buildTestRepository(
      database: database,
      privacyGate: FixedPrivacyGate(unlockRequired: true),
    );
    final container = ProviderContainer(
      overrides: [
        startupRepositoryProvider.overrideWithValue(protectedRepository),
        diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(startupControllerProvider.notifier).initialize();

    expect(container.read(startupControllerProvider), isA<StartupProtected>());
  });
}
