import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

import 'maps_preferences_test_support.dart';

void main() {
  const coordinate = MapCoordinate(latitude: 14.5995, longitude: 120.9842);

  test('M2 Event markers retain exact occurrence identity', () {
    const marker = MapMarker(
      owner: MapCoordinateOwner.event,
      recordId: 'event-1',
      occurrenceId: 'event-1@2026-09-07',
      eventOriginalDate: PlannerDate(year: 2026, month: 9, day: 7),
      eventRenderedDate: PlannerDate(year: 2026, month: 9, day: 8),
      coordinate: coordinate,
      displayName: 'Follow-up',
    );

    expect(marker.ownerKey, 'event:event-1:event-1@2026-09-07');
    expect(marker.eventOriginalDate?.iso8601, '2026-09-07');
    expect(marker.eventRenderedDate?.iso8601, '2026-09-08');
  });

  test('M2 typed focus targets a Contact or exact Event occurrence', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(mapTransientFocusProvider.notifier);

    controller.focusContact(contactId: 'contact-1', coordinate: coordinate);
    final contact = container.read(mapTransientFocusProvider).pending!;
    expect(contact.ownerKind, MapFocusOwnerKind.contact);
    expect(contact.markerKey, 'contact:contact-1');

    controller.focusEventOccurrence(
      eventId: 'event-1',
      occurrenceId: 'event-1@2026-09-07',
      originalDate: const PlannerDate(year: 2026, month: 9, day: 7),
      renderedDate: const PlannerDate(year: 2026, month: 9, day: 8),
      coordinate: coordinate,
    );
    final event = container.read(mapTransientFocusProvider).pending!;
    expect(event.ownerKind, MapFocusOwnerKind.eventOccurrence);
    expect(event.markerKey, 'event:event-1:event-1@2026-09-07');
    expect(event.nonce, greaterThan(contact.nonce));

    controller.consume(event.nonce);
    expect(container.read(mapTransientFocusProvider).pending, isNull);
    expect(
      container.read(mapTransientFocusProvider).visibilityLease?.markerKey,
      event.markerKey,
    );
    controller.clearVisibilityLease();
    expect(container.read(mapTransientFocusProvider).visibilityLease, isNull);
  });

  testWidgets('M2 People and Event layers are independently switchable', (
    tester,
  ) async {
    const markers = <MapMarker>[
      MapMarker(
        owner: MapCoordinateOwner.contact,
        recordId: 'contact-1',
        coordinate: coordinate,
        displayName: 'Ana Reyes',
        isFavorite: true,
        colorValue: 0xFF175A8F,
      ),
      MapMarker(
        owner: MapCoordinateOwner.event,
        recordId: 'event-1',
        occurrenceId: 'event-1@2026-09-07',
        eventOriginalDate: PlannerDate(year: 2026, month: 9, day: 7),
        eventRenderedDate: PlannerDate(year: 2026, month: 9, day: 7),
        coordinate: MapCoordinate(latitude: 10.3157, longitude: 123.8854),
        displayName: 'Temple Visit',
      ),
    ];
    List<MapMarker> visible = const <MapMarker>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: mapsPreferencesOverrides(),
        child: MaterialApp(
          home: Scaffold(
            body: GoogleMapsSurface(
              markers: markers,
              initialCoordinate: null,
              onMarkerTap: (_) {},
              mapBuilder: (context, projected) {
                visible = projected;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(visible, hasLength(2));

    await tester.tap(find.byKey(const Key('maps-type-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maps-layer-people')));
    await tester.pumpAndSettle();

    expect(visible, hasLength(1));
    expect(visible.single.owner, MapCoordinateOwner.event);
  });

  test('M1.1 and M2 route/clustering contracts remain explicit', () {
    final screen = File(
      'lib/features/maps/presentation/maps_screen.dart',
    ).readAsStringSync();
    final surface = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();
    final eventDetail = File(
      'lib/features/planner/presentation/calendar_event_detail_screen.dart',
    ).readAsStringSync();
    final markerPreview = File(
      'lib/features/maps/presentation/map_marker_preview_sheet.dart',
    ).readAsStringSync();

    expect(screen, contains('MapMarkerPreviewSheet('));
    expect(screen, contains('MapSelectedMarkerController'));
    expect(markerPreview, contains('RoutePaths.calendarEventDetail('));
    // M6.2: grouping ON keeps the accepted cluster-manager pipeline; the
    // durable Group nearby markers OFF branch removes the active managers.
    expect(
      surface,
      contains(
        'clusterManagers: _groupNearby\n                    ? _clusterManagers',
      ),
    );
    expect(surface, contains("ClusterManagerId(\n    'maps-people'"));
    expect(surface, contains("ClusterManagerId(\n    'maps-events'"));
    expect(eventDetail, contains('.focusEventOccurrence('));
  });
}
