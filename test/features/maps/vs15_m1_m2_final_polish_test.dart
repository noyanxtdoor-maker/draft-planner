import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';

void main() {
  testWidgets('final Maps header has menu and returns footer space to map', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          mapProjectedMarkersProvider.overrideWith(
            (ref) => Future.value(const <MapMarker>[]),
          ),
          savedContactFiltersProvider.overrideWith(
            (ref) => Future.value(const <SavedContactFilter>[]),
          ),
        ],
        child: MaterialApp(
          home: MapsScreen(
            mapBuilder: (_, markers) =>
                const SizedBox.expand(key: Key('final-polish-map')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('maps-menu-button')), findsOneWidget);
    expect(find.text('Maps'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.textContaining('visible pin'), findsNothing);
    expect(find.textContaining('tap a marker'), findsNothing);
  });

  test('today Event/search/picker/sheet/filter laws are explicit', () {
    final providers = File(
      'lib/features/maps/application/map_providers.dart',
    ).readAsStringSync();
    final surface = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();
    final picker = File(
      'lib/features/maps/presentation/map_location_picker_screen.dart',
    ).readAsStringSync();
    final search = File(
      'lib/features/maps/presentation/maps_search_screen.dart',
    ).readAsStringSync();
    final selector = File(
      'lib/features/contacts/presentation/saved_filters_screen.dart',
    ).readAsStringSync();
    final builder = File(
      'lib/features/contacts/presentation/filter_builder_screen.dart',
    ).readAsStringSync();
    final eventController = File(
      'lib/features/planner/application/calendar_event_providers.dart',
    ).readAsStringSync();
    final eventForm = File(
      'lib/features/planner/presentation/calendar_event_form_screen.dart',
    ).readAsStringSync();

    expect(providers, contains('endDate: today'));
    expect(providers, isNot(contains('today.addDays(90)')));
    expect(search, contains('MapSearchSelection.event'));
    expect(search, contains('mapEventMarkersProvider.future'));
    expect(search, contains('Find contacts, events, or places on your map'));
    expect(picker, contains('mapPassiveLocationProvider'));
    expect(picker, contains('myLocationEnabled: _showMyLocation'));
    expect(
      surface.indexOf("'Map Type'"),
      lessThan(surface.indexOf("'Markers'")),
    );
    expect(surface, contains('PmgStyleSortField('));
    expect(surface, contains("labelText: 'Map Type'"));
    expect(surface, contains("label: 'Contacts'"));
    expect(surface, isNot(contains("'Map layers'")));
    expect(surface, isNot(contains("title: const Text('People')")));
    expect(surface, contains('calendarInk'));
    expect(selector, contains('Contact Filters'));
    expect(selector, isNot(contains('Area Filters')));
    expect(builder, contains('Save as Contact Filter'));
    expect(builder, isNot(contains('Save as Area Filter')));
    expect(eventController, contains('bool awaitPlannerRefresh = true'));
    expect(eventForm, contains('awaitPlannerRefresh: false'));
  });
}
