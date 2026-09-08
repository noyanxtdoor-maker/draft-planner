import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';

final class MapPickerArgs {
  const MapPickerArgs({required this.displayName, this.initialCoordinate});

  final String displayName;
  final MapCoordinate? initialCoordinate;
}

/// Maps V1 coordinate picker.
///
/// The map itself never persists anything. A fixed red pin stays centered while
/// the map moves underneath it; Confirm returns the current camera center and
/// Cancel/Back returns null. The owning workflow remains the only persistence
/// boundary.
final class MapLocationPickerScreen extends ConsumerStatefulWidget {
  const MapLocationPickerScreen({required this.args, super.key});

  final MapPickerArgs args;

  @override
  ConsumerState<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

final class _MapLocationPickerScreenState
    extends ConsumerState<MapLocationPickerScreen> {
  GoogleMapController? _controller;
  late MapCoordinate _cameraCenter;
  bool _showMyLocation = false;
  bool _appliedPassiveLocation = false;
  bool _locating = false;

  static const MapCoordinate _safeFallback = MapCoordinate(
    latitude: 20,
    longitude: 0,
  );

  @override
  void initState() {
    super.initState();
    _cameraCenter =
        widget.args.initialCoordinate ??
        ref.read(mapPassiveLocationProvider).value ??
        _safeFallback;
    ref.listenManual(mapPassiveLocationProvider, (_, next) {
      final coordinate = next.value;
      if (coordinate != null) unawaited(_applyPassiveLocation(coordinate));
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    final coordinate = ref.read(mapPassiveLocationProvider).value;
    if (coordinate != null) await _applyPassiveLocation(coordinate);
  }

  Future<void> _applyPassiveLocation(MapCoordinate coordinate) async {
    if (!mounted) return;
    if (!_showMyLocation) setState(() => _showMyLocation = true);
    if (_controller == null ||
        _appliedPassiveLocation ||
        widget.args.initialCoordinate != null) {
      return;
    }
    await _controller!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(coordinate.latitude, coordinate.longitude),
        16,
      ),
    );
    _cameraCenter = coordinate;
    _appliedPassiveLocation = true;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onCameraMove(CameraPosition position) {
    _cameraCenter = MapCoordinate(
      latitude: position.target.latitude,
      longitude: position.target.longitude,
    );
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _confirm() {
    Navigator.of(context).pop(_cameraCenter);
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    final result = await ref.read(currentLocationServiceProvider).locate();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (result.coordinate != null) _showMyLocation = true;
    });
    final coordinate = result.coordinate;
    if (coordinate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location is unavailable.')),
      );
      return;
    }
    _cameraCenter = coordinate;
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(coordinate.latitude, coordinate.longitude),
        16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passive = ref.watch(mapPassiveLocationProvider).value;
    final initial = widget.args.initialCoordinate ?? passive ?? _safeFallback;
    final hasInitialTarget =
        widget.args.initialCoordinate != null || passive != null;
    return Scaffold(
      appBar: InternalAppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('map-picker-cancel'),
          tooltip: 'Cancel',
          onPressed: _cancel,
          icon: const Icon(Icons.close),
        ),
        title: const Text('Edit Pin Location'),
        actions: <Widget>[
          IconButton(
            key: const Key('map-picker-confirm'),
            tooltip: 'Confirm pin location',
            onPressed: _confirm,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GoogleMap(
            key: const Key('map-picker-map'),
            initialCameraPosition: CameraPosition(
              target: LatLng(initial.latitude, initial.longitude),
              zoom: hasInitialTarget ? 16 : 1.4,
            ),
            onMapCreated: _onMapCreated,
            onCameraMove: _onCameraMove,
            mapToolbarEnabled: false,
            myLocationEnabled: _showMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: const Icon(
                  Icons.location_pin,
                  key: Key('map-picker-fixed-pin'),
                  color: Colors.red,
                  size: 52,
                  shadows: <Shadow>[
                    Shadow(color: Colors.black38, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Move map to find location',
                  key: Key('map-picker-helper'),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: FloatingActionButton.small(
                key: const Key('map-picker-locate'),
                heroTag: null,
                tooltip: 'Current location',
                onPressed: _locating ? null : _locate,
                child: _locating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
