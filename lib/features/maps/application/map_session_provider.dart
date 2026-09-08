import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/maps_preferences_provider.dart';

/// The four canonical Next Transfer map types.
///
/// Storage tokens are the durable canonical enum tokens persisted in the
/// device-scoped `MapsPreferences` table (schema v37). The owner-facing
/// Satellite intentionally maps to labeled satellite imagery (Google
/// `MapType.hybrid`); that mapping is frozen.
enum NextTransferMapType {
  road('road'),
  satellite('satellite'),
  terrain('terrain'),
  hybrid('hybrid');

  const NextTransferMapType(this.storageName);

  final String storageName;

  /// Parses a persisted token, failing safely to [NextTransferMapType.satellite]
  /// for missing, null, or unknown values (M6.2 owner law: SATELLITE is the
  /// default).
  static NextTransferMapType fromStorage(String? value) {
    for (final type in values) {
      if (type.storageName == value) {
        return type;
      }
    }
    return NextTransferMapType.satellite;
  }
}

/// Volatile app-session state.
///
/// CAMERA IS SESSION-ONLY and is never persisted. The fresh-session default
/// map type is Satellite (M6.2 owner law), seeded from the durable
/// pre-runApp Maps preferences so the first Maps render never flashes Road.
/// The root ProviderScope outlives tab routes; a fresh app/Dart session
/// starts with the durable map type and the canonical startup camera.
final class MapsSessionState {
  const MapsSessionState({
    this.mapType = NextTransferMapType.satellite,
    this.camera,
  });
  final NextTransferMapType mapType;
  final CameraPosition? camera;
}

final mapsSessionProvider =
    NotifierProvider<MapsSessionController, MapsSessionState>(
      MapsSessionController.new,
    );

final class MapsSessionController extends Notifier<MapsSessionState> {
  @override
  MapsSessionState build() {
    final seed = ref.watch(initialMapsPreferencesProvider);
    return MapsSessionState(
      mapType: seed?.mapType ?? NextTransferMapType.satellite,
      camera: null,
    );
  }

  /// Canonical persist-first map-type change path shared by the Settings
  /// Maps screen AND the existing in-map Map Type chooser.
  ///
  /// Persists through the durable Maps preferences FIRST; the session
  /// state only updates after persistence succeeds, preserving the camera
  /// exactly (no camera reset, no recenter, no zoom reset). Returns false
  /// when persistence fails — the last confirmed map type remains.
  Future<bool> selectMapType(NextTransferMapType type) async {
    final ok = await ref
        .read(mapsPreferencesProvider.notifier)
        .setMapType(type);
    if (!ok) {
      return false;
    }
    if (state.mapType != type) {
      state = MapsSessionState(mapType: type, camera: state.camera);
    }
    return true;
  }

  void recordCamera(CameraPosition position) {
    if (state.camera == position) return;
    state = MapsSessionState(mapType: state.mapType, camera: position);
  }
}
