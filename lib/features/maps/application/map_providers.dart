import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

/// Defaults to a no-op repository so widget tests and forms that never
/// configure Maps keep working.  Production (`main.dart`) overrides this
/// with the real Drift-backed repository; the Maps screen itself always runs
/// inside the full app where that override exists.
final mapCoordinateRepositoryProvider = Provider<MapCoordinateRepository>((
  ref,
) {
  return const NoopMapCoordinateRepository();
});

/// One-shot, in-memory map focus requested by another Next Transfer surface.
/// It is never persisted and therefore cannot become a second coordinate store.
final mapTransientFocusProvider =
    NotifierProvider<MapTransientFocusController, MapCoordinate?>(
      MapTransientFocusController.new,
    );

final class MapTransientFocusController extends Notifier<MapCoordinate?> {
  @override
  MapCoordinate? build() => null;

  void focus(MapCoordinate coordinate) => state = coordinate;

  void clear() => state = null;
}

/// Repository that stores nothing.  Used only as the un-overridden default;
/// it lets Contact/Event forms open and save normally without a Maps layer.
final class NoopMapCoordinateRepository implements MapCoordinateRepository {
  const NoopMapCoordinateRepository();

  @override
  Stream<int> watchChanges(String profileId) => const Stream<int>.empty();

  @override
  Future<void> setCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
    required MapCoordinate coordinate,
  }) async {}

  @override
  Future<void> clearCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async {}

  @override
  Future<MapCoordinate?> readCoordinate({
    required String profileId,
    required MapCoordinateOwner owner,
    required String recordId,
  }) async => null;

  @override
  Future<List<MapMarker>> readMarkers(String profileId) async =>
      const <MapMarker>[];
}

final mapProfileIdProvider = Provider<String>((ref) {
  final startup = ref.read(startupControllerProvider);
  if (startup is! StartupReady) {
    throw StateError('Maps require a ready Local Profile');
  }
  return startup.profile.id;
});

/// All located markers for the current profile, refreshed on any contact or
/// calendar-event table change (including a new map pin being persisted).
final mapMarkersProvider = StreamProvider<List<MapMarker>>((ref) async* {
  final profileId = ref.read(mapProfileIdProvider);
  final repository = ref.watch(mapCoordinateRepositoryProvider);
  ref.watch(mapChangesProvider(profileId));
  yield await repository.readMarkers(profileId);
});

final mapChangesProvider = StreamProvider.family<int, String>((ref, profileId) {
  return ref.read(mapCoordinateRepositoryProvider).watchChanges(profileId);
});
