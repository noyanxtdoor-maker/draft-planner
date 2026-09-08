import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/privacy/application/privacy_repository.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';

enum CurrentLocationStatus {
  located,
  denied,
  permanentlyDenied,
  serviceDisabled,
  unavailable,
}

final class CurrentLocationResult {
  const CurrentLocationResult._({required this.status, this.coordinate});

  const CurrentLocationResult.located(MapCoordinate coordinate)
    : this._(status: CurrentLocationStatus.located, coordinate: coordinate);

  const CurrentLocationResult.denied()
    : this._(status: CurrentLocationStatus.denied);

  const CurrentLocationResult.permanentlyDenied()
    : this._(status: CurrentLocationStatus.permanentlyDenied);

  const CurrentLocationResult.serviceDisabled()
    : this._(status: CurrentLocationStatus.serviceDisabled);

  const CurrentLocationResult.unavailable()
    : this._(status: CurrentLocationStatus.unavailable);

  final CurrentLocationStatus status;
  final MapCoordinate? coordinate;
}

abstract interface class CurrentLocationService {
  Future<CurrentLocationResult> locate();
}

/// Optional no-prompt capability. Keeping it separate preserves existing
/// CurrentLocationService test doubles and explicit-Locate consumers.
abstract interface class PassiveCurrentLocationService {
  Future<CurrentLocationResult> locateIfAlreadyGranted();
}

/// Process-local last successful foreground position. It is navigation/UI
/// state only and never persists or starts background tracking.
abstract interface class CachedCurrentLocationService {
  MapCoordinate? get cachedCoordinate;
}

/// Foreground-only location adapter used exclusively after an explicit
/// Locate action. It never starts a stream, background service, or geofence.
final class GeolocatorCurrentLocationService
    implements
        CurrentLocationService,
        PassiveCurrentLocationService,
        CachedCurrentLocationService {
  GeolocatorCurrentLocationService({required this.privacyRepository});

  final PrivacyRepository privacyRepository;
  MapCoordinate? _cachedCoordinate;

  @override
  MapCoordinate? get cachedCoordinate => _cachedCoordinate;

  @override
  Future<CurrentLocationResult> locate() => _locate(requestPermission: true);

  @override
  Future<CurrentLocationResult> locateIfAlreadyGranted() async {
    final cached = _cachedCoordinate;
    if (cached != null) return CurrentLocationResult.located(cached);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const CurrentLocationResult.serviceDisabled();
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        return const CurrentLocationResult.permanentlyDenied();
      }
      if (permission == LocationPermission.denied) {
        return const CurrentLocationResult.denied();
      }
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return _located(lastKnown);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return _located(position);
    } on LocationServiceDisabledException {
      return const CurrentLocationResult.serviceDisabled();
    } on PermissionDeniedException {
      return const CurrentLocationResult.denied();
    } on TimeoutException {
      return const CurrentLocationResult.unavailable();
    } on Object {
      return const CurrentLocationResult.unavailable();
    }
  }

  Future<CurrentLocationResult> _locate({
    required bool requestPermission,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const CurrentLocationResult.serviceDisabled();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestPermission) {
          return const CurrentLocationResult.denied();
        }
        await privacyRepository.recordPermissionRequested(
          OptionalPermission.foregroundLocation,
        );
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const CurrentLocationResult.permanentlyDenied();
      }
      if (permission == LocationPermission.denied) {
        return const CurrentLocationResult.denied();
      }

      await privacyRepository.recordPermissionGranted(
        OptionalPermission.foregroundLocation,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return _located(position);
    } on LocationServiceDisabledException {
      return const CurrentLocationResult.serviceDisabled();
    } on PermissionDeniedException {
      return const CurrentLocationResult.denied();
    } on TimeoutException {
      return const CurrentLocationResult.unavailable();
    } on Object {
      return const CurrentLocationResult.unavailable();
    }
  }

  CurrentLocationResult _located(Position position) {
    final coordinate = MapCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    _cachedCoordinate = coordinate;
    return CurrentLocationResult.located(coordinate);
  }
}
