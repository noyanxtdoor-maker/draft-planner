import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/data/drift_saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart' as domain;
import '../../../support/test_dependencies.dart';

void main() {
  test(
    'offline restart preserves all nine categories and custom emoji with local projection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'vs15-pass2-offline-',
      );
      final file = File('${directory.path}/test.sqlite');
      AppDatabase? database;
      try {
        await HttpOverrides.runZoned(
          () async {
            database = AppDatabase.forTesting(NativeDatabase(file));
            final profile = await buildTestRepository(
              database: database!,
            ).completeOnboarding();
            final clock = FixedClock(DateTime.utc(2026, 9, 2));
            var repository = DriftSavedPlaceRepository(
              database: database!,
              clock: clock,
              identifiers: SequenceIdentifierSource([
                for (var index = 0; index < 10; index++) 'offline-$index',
              ]),
            );
            for (final category in domain.SavedPlaceStandardCategory.values) {
              await repository.create(
                profileId: profile.id,
                draft: domain.SavedPlaceDraft(
                  label: category.label,
                  coordinate: const MapCoordinate(
                    latitude: 14.6,
                    longitude: 121,
                  ),
                  standardCategory: category,
                  markerColorHex: '#25A8D3',
                ),
              );
            }
            await repository.create(
              profileId: profile.id,
              draft: const domain.SavedPlaceDraft(
                label: 'Family',
                coordinate: MapCoordinate(latitude: 16.5, longitude: 120.7),
                markerMode: domain.SavedPlaceMarkerMode.custom,
                customEmoji: '👨‍👩‍👧‍👦',
              ),
            );
            await database!.close();
            database = null;
            database = AppDatabase.forTesting(NativeDatabase(file));
            repository = DriftSavedPlaceRepository(
              database: database!,
              clock: clock,
              identifiers: SequenceIdentifierSource(['unused']),
            );
            final restored = await repository.list(profile.id);
            expect(restored, hasLength(10));
            expect(await repository.list('another-profile'), isEmpty);
            expect(
              restored
                  .where(
                    (place) =>
                        place.markerMode ==
                        domain.SavedPlaceMarkerMode.standard,
                  )
                  .map((place) => place.standardCategory)
                  .toSet(),
              domain.SavedPlaceStandardCategory.values.toSet(),
            );
            expect(
              restored
                  .singleWhere((place) => place.label == 'Family')
                  .customEmoji,
              '👨‍👩‍👧‍👦',
            );
            expect(
              restored.where(
                (place) => place.label.toLowerCase().contains('food'),
              ),
              hasLength(1),
            );
            final coordinates = DriftMapCoordinateRepository(
              database: database!,
              clock: clock,
            );
            final markers = await coordinates.readMarkers(profile.id);
            expect(markers, hasLength(10));
            expect(
              markers.every(
                (marker) => marker.owner == MapCoordinateOwner.savedPlace,
              ),
              isTrue,
            );
            for (final place in restored.where(
              (place) =>
                  place.markerMode == domain.SavedPlaceMarkerMode.standard,
            )) {
              final marker = markers.singleWhere(
                (marker) => marker.recordId == place.id,
              );
              expect(marker.placeStandardCategory, place.standardCategory);
              expect(marker.colorValue, 0xFF25A8D3);
            }
            await coordinates.setCoordinate(
              profileId: profile.id,
              owner: MapCoordinateOwner.savedPlace,
              recordId: restored.first.id,
              coordinate: const MapCoordinate(latitude: 10, longitude: 122),
            );
            expect(
              (await repository.readById(
                profileId: profile.id,
                id: restored.first.id,
              ))!.coordinate,
              const MapCoordinate(latitude: 10, longitude: 122),
            );
            expect(
              (await database!.select(database!.localProfiles).get()).single.id,
              profile.id,
            );
            await database!.close();
            database = null;
          },
          createHttpClient: (_) =>
              throw StateError('Network forbidden in offline local-data gate'),
        );
      } finally {
        await database?.close();
        // This uniquely-created test directory contains no owner database.
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'exact emoji grapheme validation preserves composed emoji and rejects plain text',
    () {
      for (final valid in [
        '😀',
        '👨‍👩‍👧‍👦',
        '👍🏽',
        '🇵🇭',
        '1️⃣',
        '❤️',
        '☕',
      ]) {
        expect(domain.isSingleEmojiGrapheme(valid), isTrue, reason: valid);
      }
      for (final invalid in ['', 'A', 'abc', '😀😁', '⌘', '🏻', '🇵', '😀‍']) {
        expect(domain.isSingleEmojiGrapheme(invalid), isFalse, reason: invalid);
      }
    },
  );
}
