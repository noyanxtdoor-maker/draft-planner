import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';

/// Maps V1 — the fourth primary tab.
///
/// Shows ONLY records with explicitly saved coordinates as markers; the
/// empty state is honest ("no saved pins yet"), and a style/network failure
/// surfaces an explicit error, never a crash.  No location permission is
/// requested anywhere.
final class MapsScreen extends ConsumerStatefulWidget {
  const MapsScreen({this.mapBuilder, super.key});

  /// Test seam: builds the interactive map surface.  Defaults to the real
  /// maplibre surface; widget tests override it with a plain widget so the
  /// platform view is never mounted in tests.
  final Widget Function(BuildContext, List<MapMarker>)? mapBuilder;

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

final class _MapsScreenState extends ConsumerState<MapsScreen> {
  @override
  Widget build(BuildContext context) {
    final markersAsync = ref.watch(mapMarkersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Maps')),
      body: markersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () {
            ref.invalidate(mapMarkersProvider);
          },
        ),
        data: (markers) {
          if (markers.isEmpty) {
            return const _EmptyState();
          }
          final builder = widget.mapBuilder;
          if (builder != null) {
            return builder(context, markers);
          }
          return _MapSurface(onMarkerTap: _openRecord);
        },
      ),
    );
  }

  void _openRecord(MapMarker marker) {
    switch (marker.owner) {
      case MapCoordinateOwner.contact:
        context.go(RoutePaths.contactDetail(marker.recordId));
      case MapCoordinateOwner.event:
        final startDate = marker.eventStartDate;
        if (startDate == null) {
          return;
        }
        context.go(RoutePaths.calendarEventDetail(marker.recordId, startDate));
    }
  }
}

final class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.location_off_outlined,
              size: 56,
              color: AppTheme.secondaryTextOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No saved map pins yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Open a Contact or Event, choose “Set on map”, and place a pin. '
              'Your saved locations appear here — nothing is shared.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryTextOf(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: AppTheme.secondaryTextOf(context),
            ),
            const SizedBox(height: 16),
            Text(
              'Maps could not be loaded',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The map tiles need a network connection. Your saved pins are '
              'safe on this device. Try again when you are back online.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryTextOf(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real maplibre surface.  Markers are added ONLY after the style has
/// loaded; a marker tap resolves the linked record through [onMarkerTap].
final class _MapSurface extends ConsumerStatefulWidget {
  const _MapSurface({required this.onMarkerTap});

  final ValueChanged<MapMarker> onMarkerTap;

  @override
  ConsumerState<_MapSurface> createState() => _MapSurfaceState();
}

final class _MapSurfaceState extends ConsumerState<_MapSurface> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;
  final List<Symbol> _symbols = <Symbol>[];
  final Map<String, MapMarker> _bySymbolId = <String, MapMarker>{};

  @override
  void initState() {
    super.initState();
    ref.listenManual(mapMarkersProvider, (_, _) {
      unawaited(_syncMarkers());
    });
    ref.listenManual(mapTransientFocusProvider, (_, requestedFocus) {
      if (requestedFocus != null) {
        unawaited(_syncMarkers());
      }
    });
  }

  @override
  void dispose() {
    _controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  void _onSymbolTapped(Symbol symbol) {
    final marker = _bySymbolId[symbol.id];
    if (marker != null) {
      widget.onMarkerTap(marker);
    }
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    await _syncMarkers();
  }

  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null || !_styleLoaded) {
      return;
    }
    final markers = ref.read(mapMarkersProvider).value ?? const <MapMarker>[];
    final hadSymbols = _symbols.isNotEmpty;
    for (final symbol in List<Symbol>.of(_symbols)) {
      await controller.removeSymbol(symbol);
    }
    _symbols.clear();
    _bySymbolId.clear();
    await controller.setSymbolIconAllowOverlap(true);
    for (final marker in markers) {
      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(
            marker.coordinate.latitude,
            marker.coordinate.longitude,
          ),
          iconImage: 'default_marker',
          iconSize: 1.0,
          textField: marker.displayName,
          textSize: 11,
          textAnchor: 'top',
          textOffset: const Offset(0, 1.6),
          textHaloColor: '#ffffff',
          textHaloWidth: 1.3,
        ),
      );
      _symbols.add(symbol);
      _bySymbolId[symbol.id] = marker;
    }
    final requestedFocus = ref.read(mapTransientFocusProvider);
    if (requestedFocus != null) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(requestedFocus.latitude, requestedFocus.longitude),
          14,
        ),
      );
      ref.read(mapTransientFocusProvider.notifier).clear();
    } else if (!hadSymbols && markers.isNotEmpty) {
      // First appearance: frame the first saved pin instead of the world view.
      final first = markers.first;
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(first.coordinate.latitude, first.coordinate.longitude),
          13,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = ref.watch(mapMarkersProvider).value ?? const <MapMarker>[];
    final first = markers.isEmpty ? null : markers.first.coordinate;
    return Column(
      children: <Widget>[
        Expanded(
          child: MapLibreMap(
            key: const Key('maps-screen-map'),
            initialCameraPosition: CameraPosition(
              target: LatLng(first?.latitude ?? 20.0, first?.longitude ?? 0.0),
              zoom: first == null ? 1.4 : 13,
            ),
            styleString: MapLibreStyles.openfreemapLiberty,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${markers.length} saved ${markers.length == 1 ? 'pin' : 'pins'}'
              ' — tap a marker to open its record',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.secondaryTextOf(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
