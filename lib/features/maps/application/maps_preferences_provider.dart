import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/maps/application/map_session_provider.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_repository.dart';

/// Device-scoped Maps preferences repository, overridden at the app root.
final mapsPreferencesRepositoryProvider = Provider<MapsPreferencesRepository>((
  ref,
) {
  throw StateError(
    'MapsPreferencesRepository must be overridden at the app root',
  );
});

/// Pre-runApp seed of the durable Maps preferences.
///
/// main() reads the persisted preferences BEFORE runApp and overrides this
/// so the first Maps render already uses Satellite (no Road → Satellite
/// startup flash). Tests may override it directly to pin preferences. Null
/// keeps the owner-locked defaults.
final initialMapsPreferencesProvider = Provider<MapsPreferencesModel?>(
  (ref) => null,
);

/// One durable preference truth for every Maps surface.
///
/// Persist-first: setters write through [mapsPreferencesRepositoryProvider]
/// and only update visible state after persistence succeeds. On failure the
/// last confirmed value is retained (the UI never claims a save that did not
/// happen).
final mapsPreferencesProvider =
    NotifierProvider<MapsPreferencesNotifier, MapsPreferencesModel>(
      MapsPreferencesNotifier.new,
    );

final class MapsPreferencesNotifier extends Notifier<MapsPreferencesModel> {
  @override
  MapsPreferencesModel build() {
    final initial = ref.watch(initialMapsPreferencesProvider);
    if (initial != null) {
      return initial;
    }
    return const MapsPreferencesModel();
  }

  /// Re-reads the persisted preferences and applies them to state.
  Future<MapsPreferencesModel> refresh() async {
    MapsPreferencesModel value;
    try {
      value = await ref
          .read(mapsPreferencesRepositoryProvider)
          .readPreferences();
    } on Object {
      value = state;
    }
    state = value;
    return value;
  }

  Future<bool> setMapType(NextTransferMapType type) =>
      _persist(state.copyWith(mapType: type));

  Future<bool> setGroupNearbyMarkers(bool value) =>
      _persist(state.copyWith(groupNearbyMarkers: value));

  Future<bool> setShowContacts(bool value) =>
      _persist(state.copyWith(showContacts: value));

  Future<bool> setShowEvents(bool value) =>
      _persist(state.copyWith(showEvents: value));

  Future<bool> setShowSavedPlaces(bool value) =>
      _persist(state.copyWith(showSavedPlaces: value));

  Future<bool> setShowBoundaries(bool value) =>
      _persist(state.copyWith(showBoundaries: value));

  Future<bool> _persist(MapsPreferencesModel next) async {
    try {
      await ref.read(mapsPreferencesRepositoryProvider).savePreferences(next);
    } on Object {
      return false;
    }
    state = next;
    return true;
  }
}
