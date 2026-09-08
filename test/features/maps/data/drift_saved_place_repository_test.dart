import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';

import '../../../support/test_dependencies.dart';

void main() {
  test(
    'Saved Place CRUD is profile-scoped and deterministically ordered',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final repository = DriftSavedPlaceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 2, 1)),
        identifiers: SequenceIdentifierSource(<String>['place-b', 'place-a']),
      );

      final beta = await repository.create(
        profileId: profile.id,
        draft: const SavedPlaceDraft(
          label: 'Beta',
          coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
        ),
      );
      final alpha = await repository.create(
        profileId: profile.id,
        draft: const SavedPlaceDraft(
          label: ' Alpha ',
          coordinate: MapCoordinate(latitude: 10.3, longitude: 123.8),
        ),
      );

      expect(
        (await repository.list(profile.id)).map((item) => item.id),
        <String>['place-a', 'place-b'],
      );
      expect(
        (await repository.readById(profileId: profile.id, id: alpha.id))?.label,
        'Alpha',
      );
      expect(await repository.list('other-profile'), isEmpty);

      final projected = await DriftMapCoordinateRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 2, 1)),
      ).readMarkers(profile.id);
      expect(
        projected
            .where((marker) => marker.owner == MapCoordinateOwner.savedPlace)
            .map((marker) => marker.ownerKey),
        <String>['place:place-a', 'place:place-b'],
      );

      final updated = await repository.update(
        profileId: profile.id,
        id: beta.id,
        draft: const SavedPlaceDraft(
          label: 'Gamma',
          coordinate: MapCoordinate(latitude: -12, longitude: 45),
        ),
      );
      expect(updated.label, 'Gamma');
      expect(updated.coordinate.latitude, -12);

      await repository.delete(profileId: profile.id, id: alpha.id);
      expect(
        (await repository.list(profile.id)).map((item) => item.id),
        <String>['place-b'],
      );
    },
  );

  test('Saved Place rejects blank labels and missing rows', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final repository = DriftSavedPlaceRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 9, 2, 1)),
      identifiers: SequenceIdentifierSource(<String>['place-1']),
    );

    await expectLater(
      repository.create(
        profileId: profile.id,
        draft: const SavedPlaceDraft(
          label: '   ',
          coordinate: MapCoordinate(latitude: 0, longitude: 0),
        ),
      ),
      throwsA(isA<SavedPlaceValidationException>()),
    );
    await expectLater(
      repository.update(
        profileId: profile.id,
        id: 'missing',
        draft: const SavedPlaceDraft(
          label: 'Missing',
          coordinate: MapCoordinate(latitude: 0, longitude: 0),
        ),
      ),
      throwsA(isA<SavedPlaceValidationException>()),
    );
  });

  test('Saved Place customization round-trips category/color/emoji', () async {
    final database = openMemoryDatabase();
    addTearDown(database.close);
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final repository = DriftSavedPlaceRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 9, 2, 1)),
      identifiers: SequenceIdentifierSource(<String>['place-x', 'place-y']),
    );

    final standard = await repository.create(
      profileId: profile.id,
      draft: const SavedPlaceDraft(
        label: 'Repair Shop',
        coordinate: MapCoordinate(latitude: 14.6, longitude: 121),
        markerMode: SavedPlaceMarkerMode.standard,
        standardCategory: SavedPlaceStandardCategory.repair,
        markerColorHex: '#D32F2F',
      ),
    );
    expect(standard.markerMode, SavedPlaceMarkerMode.standard);
    expect(standard.standardCategory, SavedPlaceStandardCategory.repair);
    expect(standard.markerColorHex, '#D32F2F');

    final custom = await repository.create(
      profileId: profile.id,
      draft: const SavedPlaceDraft(
        label: 'Favorite Cafe',
        coordinate: MapCoordinate(latitude: 10.3, longitude: 123.8),
        markerMode: SavedPlaceMarkerMode.custom,
        customEmoji: '☕',
        markerColorHex: '#2E7D32',
      ),
    );
    expect(custom.markerMode, SavedPlaceMarkerMode.custom);
    expect(custom.customEmoji, '☕');
    expect(custom.markerColorHex, '#2E7D32');

    final mapped = await repository.readById(
      profileId: profile.id,
      id: standard.id,
    );
    expect(mapped?.markerColorHex, '#D32F2F');

    final markers = await DriftMapCoordinateRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 9, 2, 1)),
    ).readMarkers(profile.id);
    final standardMarker = markers.singleWhere(
      (marker) => marker.recordId == standard.id,
    );
    expect(
      standardMarker.placeStandardCategory,
      SavedPlaceStandardCategory.repair,
    );
    expect(standardMarker.colorValue, 0xFFD32F2F);
    final customMarker = markers.singleWhere(
      (marker) => marker.recordId == custom.id,
    );
    expect(customMarker.placeEmoji, '☕');
    expect(customMarker.colorValue, 0xFF2E7D32);
  });

  test(
    'custom without emoji and invalid hex are normalized/rejected',
    () async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final profile = await buildTestRepository(
        database: database,
      ).completeOnboarding();
      final repository = DriftSavedPlaceRepository(
        database: database,
        clock: FixedClock(DateTime.utc(2026, 9, 2, 1)),
        identifiers: SequenceIdentifierSource(<String>['place-1']),
      );

      await expectLater(
        repository.create(
          profileId: profile.id,
          draft: const SavedPlaceDraft(
            label: 'No Emoji',
            coordinate: MapCoordinate(latitude: 0, longitude: 0),
            markerMode: SavedPlaceMarkerMode.custom,
          ),
        ),
        throwsA(isA<SavedPlaceValidationException>()),
      );

      final normalized = const SavedPlaceDraft(
        label: 'Color',
        coordinate: MapCoordinate(latitude: 1, longitude: 1),
        markerColorHex: 'rx175A8F',
      ).normalized();
      expect(normalized.markerColorHex, '#175A8F');
    },
  );
}
