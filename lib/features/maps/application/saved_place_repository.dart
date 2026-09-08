import 'package:rmplanner/features/maps/domain/saved_place.dart';

abstract interface class SavedPlaceRepository {
  Stream<List<SavedPlace>> watch(String profileId);

  Future<List<SavedPlace>> list(String profileId);

  Future<SavedPlace?> readById({required String profileId, required String id});

  Future<SavedPlace> create({
    required String profileId,
    required SavedPlaceDraft draft,
  });

  Future<SavedPlace> update({
    required String profileId,
    required String id,
    required SavedPlaceDraft draft,
  });

  Future<void> delete({required String profileId, required String id});
}
