import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/c3_contact_primitives.dart';
import 'package:rmplanner/features/contacts/presentation/contact_search_screen.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/presentation/maps_screen.dart';

void main() {
  testWidgets('P1 mounts the map while marker projection is unresolved', (
    tester,
  ) async {
    final projection = Completer<List<MapMarker>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          mapProjectedMarkersProvider.overrideWith((ref) => projection.future),
          savedContactFiltersProvider.overrideWith(
            (ref) => Future.value(const <SavedContactFilter>[]),
          ),
        ],
        child: MaterialApp(
          home: MapsScreen(
            mapBuilder: (_, markers) =>
                const SizedBox(key: Key('nonblocking-map-surface')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('nonblocking-map-surface')), findsOneWidget);
    expect(find.byKey(const Key('maps-marker-loading')), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.byType(FilterPlusIcon), findsOneWidget);
    expect(find.text('Everything'), findsNothing);

    await tester.tap(find.byKey(const Key('maps-status-selector')));
    await tester.pump();
    expect(
      find.byKey(const Key('contact-view-selector-panel')),
      findsOneWidget,
    );
    expect(find.text('Contact Filters'), findsOneWidget);
    expect(find.text('Standard Filters'), findsOneWidget);
  });

  testWidgets('P3 shared Search picker debounces and returns one selection', (
    tester,
  ) async {
    var searches = 0;
    ContactSummary? selected;
    final summary = ContactSummary(
      contact: Contact(
        id: 'contact-1',
        profileId: 'profile-1',
        firstName: 'Ana',
        lastName: 'Reyes',
        displayName: 'Ana Reyes',
        preferredContactMethod: ContactPreferredMethod.message,
        isFavorite: false,
        lifecycleState: ContactLifecycleState.active,
        source: ContactSource.manual,
        createdAtUtc: DateTime.utc(2026, 9, 1),
        updatedAtUtc: DateTime.utc(2026, 9, 1),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ContactSearchPickerScreen<ContactSummary>(
          search: (query) async {
            searches += 1;
            return <ContactSummary>[summary];
          },
          onSelected: (value) => selected = value,
          resultBuilder: (context, result, onTap) =>
              ContactListRow(summary: result, onTap: onTap),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('map-search-field')), 'Ana');
    await tester.pump(const Duration(milliseconds: 249));
    expect(searches, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(searches, 1);
    await tester.tap(find.text('Ana Reyes'));
    await tester.pump();
    expect(selected?.contact.id, 'contact-1');
  });

  test('P2/P3 active Maps UI uses Status and dedicated Search', () {
    final source = File(
      'lib/features/maps/presentation/maps_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('Everything')));
    expect(source, isNot(contains('maps-contact-search-field')));
    expect(source, contains('ContactViewSelectorButton'));
    expect(source, contains('FilterPlusIcon'));
    expect(source, contains('RoutePaths.mapSearch'));
  });

  test('P4/P5/P6 correction contracts are explicit in production source', () {
    final providers = File(
      'lib/features/maps/application/map_providers.dart',
    ).readAsStringSync();
    final surface = File(
      'lib/features/maps/presentation/google_maps_surface.dart',
    ).readAsStringSync();

    expect(providers, isNot(contains('planner.readDay(')));
    expect(providers, contains('CalendarEventRangeSource'));
    expect(surface, isNot(contains('_visibleMarkerData.first.coordinate')));
    expect(surface, contains('canvas.drawPath(star, outline)'));
    expect(surface, contains('initialChildSize: 0.44'));
    expect(surface, contains('minChildSize: 0.31'));
  });
}
