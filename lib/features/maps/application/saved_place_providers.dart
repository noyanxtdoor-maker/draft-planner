import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/features/maps/application/saved_place_repository.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final savedPlaceRepositoryProvider = Provider<SavedPlaceRepository>((ref) {
  throw StateError('SavedPlaceRepository must be overridden at the app root');
});

final savedPlaceProfileIdProvider = Provider<String>((ref) {
  final startup = ref.read(startupControllerProvider);
  if (startup is! StartupReady) {
    throw StateError('Saved Places require a ready Local Profile');
  }
  return startup.profile.id;
});

final savedPlacesProvider = StreamProvider<List<SavedPlace>>((ref) {
  return ref
      .watch(savedPlaceRepositoryProvider)
      .watch(ref.read(savedPlaceProfileIdProvider));
});

Future<List<SavedPlace>> searchSavedPlaces(WidgetRef ref, String query) async {
  final needle = query.trim().toLowerCase();
  final places = await ref
      .read(savedPlaceRepositoryProvider)
      .list(ref.read(savedPlaceProfileIdProvider));
  if (needle.isEmpty) return places;
  return places
      .where((place) => place.label.toLowerCase().contains(needle))
      .toList(growable: false);
}

/// Locked M6.1 visual contract for persisted boundary polygons.
const double boundaryFillOpacity = 0.32;
const int boundaryStrokeWidthPx = 2;

/// VS-15 M6.1: projects persisted Saved Place boundaries onto native Google
/// polygons. The projection derives entirely from the SAME [savedPlacesProvider]
/// Drift watch that feeds markers — no duplicate persistence or state. A
/// place's boundary appears/disappears/updates automatically with its row;
/// deleting the place removes its polygon because the row itself is gone.
///
/// Polygons are ground-layer visuals: stable id per place, tap-consuming off,
/// no onTap wiring, low zIndex — they never compete with markers, clusters,
/// or the frozen M3 native precision-tap pipeline.
final savedPlacePolygonsProvider = Provider<Set<Polygon>>((ref) {
  final places = ref.watch(savedPlacesProvider).value ?? const <SavedPlace>[];
  return <Polygon>{
    for (final place in places)
      if (place.boundary case final boundary?)
        Polygon(
          polygonId: PolygonId('saved-place-boundary-${place.id}'),
          points: <LatLng>[
            for (final vertex in boundary.vertices)
              LatLng(vertex.latitude, vertex.longitude),
          ],
          fillColor: Color(
            boundary.markerColorArgb,
          ).withValues(alpha: boundaryFillOpacity),
          strokeColor: Color(boundary.markerColorArgb),
          strokeWidth: boundaryStrokeWidthPx,
          consumeTapEvents: false,
          zIndex: 1,
        ),
  };
});
