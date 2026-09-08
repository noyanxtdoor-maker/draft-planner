// VS-15 M6.2 — durable Map Type tests.
//
// Fresh session seeds Satellite (owner law); explicit choices persist
// first and update session state only after the write succeeds; the camera
// is session-only and preserved exactly across map-type changes; write
// failures retain the last confirmed map type; the pre-runApp seed avoids
// any Road → Satellite first-frame flash.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/map_session_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_repository.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart'
    show NextTransferMapTypePresentation;

import 'maps_preferences_test_support.dart';

const _taiwan = CameraPosition(
  target: LatLng(25.033, 121.5654),
  zoom: 13.25,
  bearing: 47.5,
  tilt: 38,
);

void main() {
  test('15. missing preference / fresh seed: map type is Satellite', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(mapsSessionProvider).mapType,
      NextTransferMapType.satellite,
    );
    expect(
      container.read(mapsPreferencesProvider).mapType,
      NextTransferMapType.satellite,
    );
  });

  for (final (type, expected) in <(NextTransferMapType, MapType)>[
    (NextTransferMapType.satellite, MapType.hybrid),
    (NextTransferMapType.road, MapType.normal),
    (NextTransferMapType.hybrid, MapType.hybrid),
    (NextTransferMapType.terrain, MapType.terrain),
  ]) {
    test('${type.name} still maps to Google ${expected.name}', () {
      expect(type.googleType, expected);
    });
  }

  test('20. changing map type preserves the camera exactly', () async {
    final container = ProviderContainer(overrides: mapsPreferencesOverrides());
    addTearDown(container.dispose);
    container.read(mapsSessionProvider.notifier).recordCamera(_taiwan);
    final ok = await container
        .read(mapsSessionProvider.notifier)
        .selectMapType(NextTransferMapType.terrain);
    expect(ok, isTrue);
    expect(
      container.read(mapsSessionProvider).mapType,
      NextTransferMapType.terrain,
    );
    expect(container.read(mapsSessionProvider).camera, _taiwan);
  });

  test('21. explicit map type persists into a fresh container', () async {
    final fake = FakeMapsPreferencesRepository();
    final first = ProviderContainer(
      overrides: mapsPreferencesOverrides(repository: fake),
    );
    addTearDown(first.dispose);
    final ok = await first
        .read(mapsSessionProvider.notifier)
        .selectMapType(NextTransferMapType.hybrid);
    expect(ok, isTrue);

    final second = ProviderContainer(
      overrides: mapsPreferencesOverrides(seed: await fake.readPreferences()),
    );
    addTearDown(second.dispose);
    expect(
      second.read(mapsPreferencesProvider).mapType,
      NextTransferMapType.hybrid,
    );
    expect(
      second.read(mapsSessionProvider).mapType,
      NextTransferMapType.hybrid,
    );
  });

  test('22. write failure leaves the last confirmed map type', () async {
    final fake = FakeMapsPreferencesRepository()..failWrites = true;
    final container = ProviderContainer(
      overrides: mapsPreferencesOverrides(repository: fake),
    );
    addTearDown(container.dispose);
    final ok = await container
        .read(mapsSessionProvider.notifier)
        .selectMapType(NextTransferMapType.road);
    expect(ok, isFalse);
    expect(
      container.read(mapsSessionProvider).mapType,
      NextTransferMapType.satellite,
    );
    expect(
      container.read(mapsPreferencesProvider).mapType,
      NextTransferMapType.satellite,
    );
    expect(fake.writeCount, 1);
  });

  test('23. seeded initial preference means no Road→Satellite flash', () {
    // The session seeds its map type directly from the pre-runApp durable
    // preference; a Road persisted choice must never first render Satellite.
    final roadContainer = ProviderContainer(
      overrides: mapsPreferencesOverrides(
        seed: const MapsPreferencesModel(mapType: NextTransferMapType.road),
      ),
    );
    addTearDown(roadContainer.dispose);
    expect(
      roadContainer.read(mapsSessionProvider).mapType,
      NextTransferMapType.road,
    );

    final satelliteContainer = ProviderContainer(
      overrides: mapsPreferencesOverrides(
        seed: const MapsPreferencesModel(
          mapType: NextTransferMapType.satellite,
        ),
      ),
    );
    addTearDown(satelliteContainer.dispose);
    expect(
      satelliteContainer.read(mapsSessionProvider).mapType,
      NextTransferMapType.satellite,
    );
  });
}
