import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum NextTransferMapType { road, satellite, terrain, hybrid }

/// Volatile app-session state. The root ProviderScope outlives tab routes;
/// a fresh app/Dart session starts with Road and canonical startup camera.
final class MapsSessionState {
  const MapsSessionState({
    this.mapType = NextTransferMapType.road,
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
  MapsSessionState build() => const MapsSessionState();

  void selectMapType(NextTransferMapType type) {
    if (state.mapType == type) return;
    state = MapsSessionState(mapType: type, camera: state.camera);
  }

  void recordCamera(CameraPosition position) {
    if (state.camera == position) return;
    state = MapsSessionState(mapType: state.mapType, camera: position);
  }
}
