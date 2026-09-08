import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/contact_search_screen.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/application/saved_place_providers.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_marker_visuals.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';

final class MapSearchSelection {
  const MapSearchSelection._({
    required this.ownerKind,
    required this.recordId,
    required this.coordinate,
    this.occurrenceId,
    this.originalDate,
    this.renderedDate,
  });

  const MapSearchSelection.contact({
    required String contactId,
    required MapCoordinate coordinate,
  }) : this._(
         ownerKind: MapFocusOwnerKind.contact,
         recordId: contactId,
         coordinate: coordinate,
       );

  const MapSearchSelection.event({
    required String eventId,
    required String occurrenceId,
    required PlannerDate originalDate,
    required PlannerDate renderedDate,
    required MapCoordinate coordinate,
  }) : this._(
         ownerKind: MapFocusOwnerKind.eventOccurrence,
         recordId: eventId,
         occurrenceId: occurrenceId,
         originalDate: originalDate,
         renderedDate: renderedDate,
         coordinate: coordinate,
       );

  const MapSearchSelection.savedPlace({
    required String placeId,
    required MapCoordinate coordinate,
  }) : this._(
         ownerKind: MapFocusOwnerKind.savedPlace,
         recordId: placeId,
         coordinate: coordinate,
       );

  final MapFocusOwnerKind ownerKind;
  final String recordId;
  final MapCoordinate coordinate;
  final String? occurrenceId;
  final PlannerDate? originalDate;
  final PlannerDate? renderedDate;
}

final class MapSearchResult {
  const MapSearchResult.contact(this.contact) : event = null, place = null;
  const MapSearchResult.event(this.event) : contact = null, place = null;
  const MapSearchResult.savedPlace(this.place) : contact = null, event = null;

  final ContactSummary? contact;
  final MapMarker? event;
  final SavedPlace? place;
}

/// Dedicated, off-map People search. The accepted Contacts Search
/// presentation owns typing/debounce/results; Maps supplies its canonical
/// filter+coordinate adapter and one-shot selection result.
final class MapsSearchScreen extends ConsumerWidget {
  const MapsSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContactSearchPickerScreen<MapSearchResult>(
      hintText: 'Search contacts, events, or places',
      emptyTitle: 'Find contacts, events, or places on your map',
      emptyMessage:
          'Search active contacts, today’s events, and your Saved Places.',
      search: (query) => _search(ref, query),
      onSelected: (result) => _select(context, ref, result),
      resultBuilder: (context, result, onTap) {
        final contact = result.contact;
        if (contact != null) {
          return ContactListRow(summary: contact, onTap: onTap);
        }
        final place = result.place;
        if (place != null) {
          return ListTile(
            key: Key('map-search-place-${place.id}'),
            leading: SavedPlaceIdentityIcon(
              identity: SavedPlaceVisualIdentity.fromPlace(place),
            ),
            title: Text(place.label),
            subtitle: const Text('Saved Place'),
            onTap: onTap,
          );
        }
        final event = result.event!;
        return ListTile(
          key: Key('map-search-event-${event.ownerKey}'),
          leading: Icon(
            Icons.calendar_month_outlined,
            color: Color(event.colorValue),
          ),
          title: Text(event.displayName),
          subtitle: const Text('Today’s Event'),
          onTap: onTap,
        );
      },
    );
  }

  Future<List<MapSearchResult>> _search(WidgetRef ref, String query) async {
    final values = await Future.wait<Object>(<Future<Object>>[
      searchMapPeople(ref, query),
      ref.read(mapEventMarkersProvider.future),
      searchSavedPlaces(ref, query),
    ]);
    final contacts = values[0] as List<ContactSummary>;
    final events = values[1] as List<MapMarker>;
    final places = values[2] as List<SavedPlace>;
    final needle = query.trim().toLowerCase();
    return <MapSearchResult>[
      for (final contact in contacts) MapSearchResult.contact(contact),
      for (final event in events)
        if (event.displayName.toLowerCase().contains(needle))
          MapSearchResult.event(event),
      for (final place in places) MapSearchResult.savedPlace(place),
    ];
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    MapSearchResult result,
  ) async {
    final place = result.place;
    if (place != null) {
      Navigator.of(context).pop(
        MapSearchSelection.savedPlace(
          placeId: place.id,
          coordinate: place.coordinate,
        ),
      );
      return;
    }
    final event = result.event;
    if (event != null) {
      final occurrenceId = event.occurrenceId;
      final originalDate = event.eventOriginalDate;
      final renderedDate = event.eventRenderedDate;
      if (occurrenceId == null ||
          originalDate == null ||
          renderedDate == null) {
        return;
      }
      Navigator.of(context).pop(
        MapSearchSelection.event(
          eventId: event.recordId,
          occurrenceId: occurrenceId,
          originalDate: originalDate,
          renderedDate: renderedDate,
          coordinate: event.coordinate,
        ),
      );
      return;
    }
    final summary = result.contact!;
    final coordinate = await ref
        .read(mapCoordinateRepositoryProvider)
        .readCoordinate(
          profileId: ref.read(mapProfileIdProvider),
          owner: MapCoordinateOwner.contact,
          recordId: summary.contact.id,
        );
    if (!context.mounted || coordinate == null) return;
    Navigator.of(context).pop(
      MapSearchSelection.contact(
        contactId: summary.contact.id,
        coordinate: coordinate,
      ),
    );
  }
}
