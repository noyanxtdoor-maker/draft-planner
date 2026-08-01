import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

import '../../../support/test_dependencies.dart';

void main() {
  testWidgets(
    'AC-W-001..011,018,019,021,022: privacy journey is usable and non-destructive',
    (tester) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final privacy = TestPrivacyDependencies(database: database);
      final startupRepository = buildTestRepository(
        database: database,
        privacyGate: privacy.gate,
      );
      await startupRepository.completeOnboarding();
      final diagnostics = SanitizedDiagnostics()
        ..record(
          'startup_resolved',
          context: const <String, Object?>{'database_state': 'ready'},
        );

      await tester.pumpWidget(
        privacy.buildApp(
          environment: const AppEnvironment(
            name: AppEnvironmentName.production,
            label: 'PRODUCTION',
          ),
          diagnostics: diagnostics,
          startupRepository: startupRepository,
        ),
      );
      await tester.pumpAndSettle();

      // Open the global app drawer via the Home hamburger. Stage
      // B3-R1 Slice D removed the Home top-bar shield action so
      // the privacy surface is reached through the global drawer
      // (matching the production navigation path).
      await tester.tap(find.byKey(const Key('home-hamburger')));
      await tester.pumpAndSettle();
      // The drawer's inner ListView lazily builds its children,
      // so the Privacy and Data entry is unmounted when scrolled
      // out of the visible region. Use scrollUntilVisible (which
      // keeps scrolling until the tile is on screen) with a
      // generous scroll step so the whole list reveals the
      // "Account and App" group in one pass.
      await tester.scrollUntilVisible(
        find.byKey(const Key('drawer-account-privacy')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('global-app-drawer-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-account-privacy')));
      await tester.pumpAndSettle();
      expect(find.text('Privacy controls'), findsOneWidget);
      expect(
        find.textContaining('every optional permission denied'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('privacy-lock-switch')));
      await tester.pumpAndSettle();
      expect((await privacy.repository.readSettings()).lockEnabled, isTrue);
      final container = ProviderScope.containerOf(
        tester.element(find.text('Privacy controls')),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(
        container.read(privacyControllerProvider).status,
        PrivacyLockStatus.locked,
      );
      expect(
        container.read(startupControllerProvider),
        isA<StartupProtected>(),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Next Transfer is locked'), findsOneWidget);

      await tester.tap(find.byKey(const Key('unlock-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);
      expect(await privacy.gate.isUnlockRequired(), isFalse);

      // Open the global app drawer via the Home hamburger. Stage
      // B3-R1 Slice D removed the Home top-bar shield action so
      // the privacy surface is reached through the global drawer
      // (matching the production navigation path).
      await tester.tap(find.byKey(const Key('home-hamburger')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('drawer-account-privacy')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('global-app-drawer-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-account-privacy')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Permissions'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Permissions'));
      await tester.pumpAndSettle();
      expect(find.text('Not requested'), findsNWidgets(4));
      expect(
        find.textContaining('No permission is requested from this page'),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('open-system-settings-button')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('open-system-settings-button')));
      await tester.pumpAndSettle();
      expect(privacy.permissionGateway.settingsOpened, isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Diagnostic export preview'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Diagnostic export preview'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nothing is exported automatically'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('prepare-diagnostic-preview-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('sanitized events ready for review'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('no file or message'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('no file or message'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('deletion-impact-tile')),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('deletion-impact-tile')));
      await tester.pumpAndSettle();
      expect(find.text('Deletion impacts'), findsOneWidget);
      expect(find.text('Local app data'), findsOneWidget);
      expect(find.text('Optional synced data'), findsOneWidget);
      expect(find.text('Backups'), findsOneWidget);
      expect(find.text('Source files'), findsOneWidget);

      expect(await database.select(database.localProfiles).get(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('AC-W-008: Privacy Center remains usable at 200% text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

    // Open the global app drawer via the Home hamburger. Stage
    // B3-R1 Slice D removed the Home top-bar shield action so
    // the privacy surface is reached through the global drawer
    // (matching the production navigation path).
    await tester.tap(find.byKey(const Key('home-hamburger')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('drawer-account-privacy')),
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('global-app-drawer-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-account-privacy')));
    await tester.pumpAndSettle();

    expect(find.text('Privacy controls'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
