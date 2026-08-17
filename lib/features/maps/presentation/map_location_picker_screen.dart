import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';

final class MapPickerArgs {
  const MapPickerArgs({required this.displayName, this.initialCoordinate});

  final String displayName;
  final MapCoordinate? initialCoordinate;
}

/// Maps V1 coordinate picker.
///
/// The map itself never persists anything: a tap moves a candidate marker,
/// Confirm pops with the chosen [MapCoordinate], and Cancel pops with null
/// (no write).  The owning form persists the confirmed pin after its record
/// save succeeds.  Without an existing pin the map opens on a neutral world
/// view — the device location is NEVER inferred or requested.
final class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({required this.args, super.key});

  final MapPickerArgs args;

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

final class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  MapLibreMapController? _controller;
  Symbol? _candidate;
  MapCoordinate? _selected;

  @override
  void dispose() {
    _controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }

  void _onSymbolTapped(Symbol _) {}

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    final initial = widget.args.initialCoordinate;
    if (controller == null || initial == null) {
      return;
    }
    await controller.setSymbolIconAllowOverlap(true);
    final symbol = await controller.addSymbol(
      SymbolOptions(
        geometry: LatLng(initial.latitude, initial.longitude),
        iconImage: 'default_marker',
        iconSize: 1.1,
        textField: widget.args.displayName,
        textSize: 12,
        textAnchor: 'top',
        textOffset: const Offset(0, 1.6),
        textHaloColor: '#ffffff',
        textHaloWidth: 1.4,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _candidate = symbol;
      _selected = initial;
    });
  }

  Future<void> _onMapTap(LatLng latLng) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final coordinate = MapCoordinate(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
    final previous = _candidate;
    if (previous != null) {
      await controller.removeSymbol(previous);
    }
    final symbol = await controller.addSymbol(
      SymbolOptions(
        geometry: LatLng(coordinate.latitude, coordinate.longitude),
        iconImage: 'default_marker',
        iconSize: 1.1,
        textField: widget.args.displayName,
        textSize: 12,
        textAnchor: 'top',
        textOffset: const Offset(0, 1.6),
        textHaloColor: '#ffffff',
        textHaloWidth: 1.4,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _candidate = symbol;
      _selected = coordinate;
    });
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _confirm() {
    final selected = _selected;
    if (selected == null) {
      return;
    }
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.args.initialCoordinate;
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Set map pin')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: MapLibreMap(
              key: const Key('map-picker-map'),
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  initial?.latitude ?? 20.0,
                  initial?.longitude ?? 0.0,
                ),
                zoom: initial == null ? 1.4 : 14,
              ),
              styleString: MapLibreStyles.openfreemapLiberty,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onMapClick: (_, coordinates) => _onMapTap(coordinates),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Tap the map to place the pin.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextButton(
                          key: const Key('map-picker-cancel'),
                          onPressed: _cancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('map-picker-confirm'),
                          onPressed: _selected == null ? null : _confirm,
                          child: const Text('Confirm pin'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
