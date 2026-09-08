// VS-15 M6.2 — Maps settings destination + route + provider wiring.
//
// Covers: Settings home MAPS section row, route open, exact control set
// (no Map Tiles / generic Icons), defaults, persist-first switches (failure
// retains prior visible state), Map Type selection persistence, and
// Settings ↔ Maps surface synchronization through the one durable provider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/router/app_router.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/platform/app_environment.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_provider.dart';
import 'package:rmplanner/features/settings/presentation/maps_settings_screen.dart';

import '../../support/test_dependencies.dart';
import '../maps/maps_preferences_test_support.dart';

void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool includeFakeRepository = false,
  }) async {
    tester.view.physicalSize = const Size(431, 912);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = openMemoryDatabase();
    addTearDown(database.close);
    final privacy = TestPrivacyDependencies(database: database);
    final startup = buildTestRepository(
      database: database,
      privacyGate: privacy.gate,
    );
    await startup.completeOnboarding();
    await tester.pumpWidget(
      privacy.buildApp(
        environment: const AppEnvironment(
          name: AppEnvironmentName.production,
          label: 'PRODUCTION',
        ),
        diagnostics: SanitizedDiagnostics(),
        startupRepository: startup,
        extraOverrides: includeFakeRepository
            ? mapsPreferencesOverrides()
            : const <Override>[],
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('home-hamburger')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('drawer-account-settings')),
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('global-app-drawer-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-account-settings')));
    await tester.pumpAndSettle();
  }

  testWidgets('52. Settings home contains the MAPS section and Maps row', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSettings(tester);
    expect(find.byKey(const Key('settings-section-maps')), findsOneWidget);
    expect(find.byKey(const Key('settings-maps')), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.byKey(const Key('settings-maps')),
    );
    expect((tile.title! as Text).data, 'Maps');
    expect(tile.subtitle, isNull);
  });

  testWidgets('53. Maps route opens the Maps settings screen', (tester) async {
    final container = await pumpApp(tester);
    await openSettings(tester);
    container.read(appRouterProvider).go('/more/settings/maps');
    await tester.pumpAndSettle();
    expect(find.byType(MapsSettingsScreen), findsOneWidget);
  });

  testWidgets('54/55/56/57. Maps screen contains exactly the six controls with '
      'defaults, and no Map Tiles / generic Icons settings', (tester) async {
    final container = await pumpApp(tester);
    await openSettings(tester);
    container.read(appRouterProvider).go('/more/settings/maps');
    await tester.pumpAndSettle();

    expect(find.text('MAPS'), findsOneWidget);
    expect(find.text('MAP CONTENT'), findsOneWidget);
    expect(find.byKey(const Key('maps-settings-map-type')), findsOneWidget);
    expect(find.text('Map Type'), findsOneWidget);
    expect(find.text('Satellite'), findsOneWidget); // owner default
    expect(find.byKey(const Key('maps-settings-group-nearby')), findsOneWidget);
    expect(find.byKey(const Key('maps-settings-contacts')), findsOneWidget);
    expect(find.byKey(const Key('maps-settings-events')), findsOneWidget);
    expect(find.byKey(const Key('maps-settings-saved-places')), findsOneWidget);
    expect(find.byKey(const Key('maps-settings-boundaries')), findsOneWidget);
    expect(find.text('Map Tiles'), findsNothing);
    expect(find.text('Generic Icons'), findsNothing);

    // All five switches default ON.
    for (final key in <String>[
      'maps-settings-group-nearby',
      'maps-settings-contacts',
      'maps-settings-events',
      'maps-settings-saved-places',
      'maps-settings-boundaries',
    ]) {
      expect(tester.widget<SwitchListTile>(find.byKey(Key(key))).value, isTrue);
    }
  });

  testWidgets('58. switch success updates the persisted preference', (
    tester,
  ) async {
    final container = await pumpApp(tester, includeFakeRepository: true);
    await openSettings(tester);
    container.read(appRouterProvider).go('/more/settings/maps');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maps-settings-contacts')));
    await tester.pumpAndSettle();
    expect(container.read(mapsPreferencesProvider).showContacts, isFalse);
  });

  testWidgets('59. switch failure retains the previous visible state', (
    tester,
  ) async {
    final container = await pumpApp(tester, includeFakeRepository: true);
    await openSettings(tester);
    container.read(appRouterProvider).go('/more/settings/maps');
    await tester.pumpAndSettle();
    final fake =
        (container.read(mapsPreferencesRepositoryProvider)
              as FakeMapsPreferencesRepository)
          ..failWrites = true;
    await tester.tap(find.byKey(const Key('maps-settings-contacts')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('maps-settings-contacts')),
          )
          .value,
      isTrue,
    );
    expect(container.read(mapsPreferencesProvider).showContacts, isTrue);
    expect(fake.writeCount, 1);
  });

  testWidgets('60. Map Type selection persists through the canonical path', (
    tester,
  ) async {
    final container = await pumpApp(tester, includeFakeRepository: true);
    await openSettings(tester);
    container.read(appRouterProvider).go('/more/settings/maps');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maps-settings-map-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maps-settings-map-type-terrain')));
    await tester.pumpAndSettle();
    expect(container.read(mapsPreferencesProvider).mapType.name, 'terrain');
    // The screen subtitle updates.
    expect(find.text('Terrain'), findsOneWidget);
  });

  testWidgets(
    '61. Settings and the Maps surface stay synchronized via one durable '
    'provider',
    (tester) async {
      final container = await pumpApp(tester, includeFakeRepository: true);
      // Simulate a quick-sheet change on the maps surface side: same
      // provider, so the Settings screen reflects it immediately.
      await container
          .read(mapsPreferencesProvider.notifier)
          .setShowEvents(false);
      await openSettings(tester);
      container.read(appRouterProvider).go('/more/settings/maps');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('maps-settings-events')),
            )
            .value,
        isFalse,
      );
    },
  );
}
