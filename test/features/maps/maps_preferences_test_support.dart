// VS-15 M6.2 test support: in-memory MapsPreferencesRepository fake with
// optional write-failure injection, plus the standard override list.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:rmplanner/features/maps/application/maps_preferences_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_repository.dart';

final class FakeMapsPreferencesRepository implements MapsPreferencesRepository {
  FakeMapsPreferencesRepository([this.stored]);

  MapsPreferencesModel? stored;
  bool failWrites = false;
  int writeCount = 0;

  @override
  Future<MapsPreferencesModel> readPreferences() async =>
      stored ?? const MapsPreferencesModel();

  @override
  Future<void> savePreferences(MapsPreferencesModel preferences) async {
    writeCount += 1;
    if (failWrites) {
      throw StateError('Injected MapsPreferences write failure');
    }
    stored = preferences;
  }
}

List<Override> mapsPreferencesOverrides({
  MapsPreferencesRepository? repository,
  MapsPreferencesModel? seed,
}) {
  final fake = repository ?? FakeMapsPreferencesRepository(seed);
  return <Override>[
    mapsPreferencesRepositoryProvider.overrideWithValue(fake),
    initialMapsPreferencesProvider.overrideWithValue(seed),
  ];
}
