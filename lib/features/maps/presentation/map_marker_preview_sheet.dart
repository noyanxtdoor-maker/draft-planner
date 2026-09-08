import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/maps/application/map_coordinate_repository.dart';
import 'package:rmplanner/features/maps/application/map_providers.dart';
import 'package:rmplanner/features/maps/presentation/google_maps_surface.dart';
import 'package:rmplanner/features/maps/presentation/map_external_navigation.dart';
import 'package:rmplanner/features/planner/application/calendar_event_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/calendar_event.dart';

/// The direct-marker preview shown over the canonical Maps surface.
///
/// It deliberately has no persistence of its own. The selected marker is a
/// transient Maps state; all Contact/Event facts and all mutations remain with
/// their existing canonical repositories and editors. Edit Pin Location is
/// delivered upward to the owning Maps screen so it can run the inline
/// same-surface edit mode instead of hosting a second picker route.
final class MapMarkerPreviewSheet extends ConsumerWidget {
  const MapMarkerPreviewSheet({
    required this.selection,
    required this.onDismiss,
    required this.onEditLocation,
    this.onEditPlace,
    this.onDeletePlace,
    this.controller,
    super.key,
  });

  final MapSelectedMarker selection;
  final VoidCallback onDismiss;

  /// Enters the inline, same-MapsScreen edit-location mode.
  final VoidCallback onEditLocation;
  final VoidCallback? onEditPlace;
  final VoidCallback? onDeletePlace;

  /// Drives the sheet so the owning screen can animate progress and move the
  /// floating controls in sync.
  final DraggableScrollableController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marker = selection.marker;
    return DraggableScrollableSheet(
      key: const Key('maps-marker-preview-sheet'),
      controller: controller,
      expand: false,
      initialChildSize:
          selection.isGroup || marker.owner == MapCoordinateOwner.savedPlace
          ? .38
          : .31,
      minChildSize: .18,
      maxChildSize: .72,
      builder: (context, scrollController) =>
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if (notification.extent <= .181) onDismiss();
              return false;
            },
            child: Material(
              color: AppTheme.surfaceOf(context),
              elevation: 12,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  children: <Widget>[
                    Center(
                      child: Container(
                        key: const Key('maps-marker-preview-handle'),
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.dragHandleOf(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selection.isGroup) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${selection.members.length} records',
                              style: AppTypography.sectionTitle,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: onDismiss,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      for (final member in selection.members)
                        ListTile(
                          key: Key('maps-group-row-${member.ownerKey}'),
                          contentPadding: EdgeInsets.zero,
                          leading: MapMarkerIdentityIcon(marker: member),
                          title: Text(
                            member.displayName,
                            style: AppTypography.body,
                          ),
                          onTap: () => ref
                              .read(mapSelectedMarkerProvider.notifier)
                              .select(member),
                        ),
                    ] else
                      switch (marker.owner) {
                        MapCoordinateOwner.contact => _ContactMarkerPreview(
                          key: ValueKey<String>('contact:${marker.recordId}'),
                          marker: marker,
                          onDismiss: onDismiss,
                          onEditLocation: onEditLocation,
                        ),
                        MapCoordinateOwner.event => _EventMarkerPreview(
                          key: ValueKey<String>('event:${marker.ownerKey}'),
                          marker: marker,
                          onDismiss: onDismiss,
                          onEditLocation: onEditLocation,
                        ),
                        MapCoordinateOwner.savedPlace =>
                          _SavedPlaceMarkerPreview(
                            key: ValueKey<String>('place:${marker.recordId}'),
                            marker: marker,
                            onDismiss: onDismiss,
                            onEditLocation: onEditLocation,
                            onEditPlace: onEditPlace,
                            onDeletePlace: onDeletePlace,
                          ),
                      },
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

final class _ContactMarkerPreview extends ConsumerStatefulWidget {
  const _ContactMarkerPreview({
    required this.marker,
    required this.onDismiss,
    required this.onEditLocation,
    super.key,
  });

  final MapMarker marker;
  final VoidCallback onDismiss;
  final VoidCallback onEditLocation;

  @override
  ConsumerState<_ContactMarkerPreview> createState() =>
      _ContactMarkerPreviewState();
}

final class _ContactMarkerPreviewState
    extends ConsumerState<_ContactMarkerPreview> {
  late Future<_ContactPreviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _ContactMarkerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marker.recordId != widget.marker.recordId) {
      _future = _load();
    }
  }

  Future<_ContactPreviewData> _load() async {
    final profileId = ref.read(contactProfileIdProvider);
    final today = ref.read(plannerDateSourceProvider).today();
    final results = await Future.wait<Object>(<Future<Object>>[
      ref
          .read(contactRepositoryProvider)
          .readContactDetail(
            profileId: profileId,
            contactId: widget.marker.recordId,
          ),
      ref
          .read(contactRepositoryProvider)
          .readContactsByIds(
            profileId: profileId,
            contactIds: <String>[widget.marker.recordId],
            today: today,
          ),
    ]);
    final detail = results[0] as ContactDetail;
    final summaries = results[1] as Map<String, ContactSummary>;
    return _ContactPreviewData(
      detail: detail,
      summary: summaries[widget.marker.recordId],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ContactPreviewData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          return _PendingMarkerPreview(
            marker: widget.marker,
            failed: snapshot.hasError,
          );
        }
        final detail = data.detail;
        final address = detail.contact.addressText?.trim();
        final phone = _preferredPhone(detail.methods);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SinglePreviewHeading(
              marker: widget.marker,
              title: detail.contact.displayName,
              titleKey: const Key('maps-contact-preview-name'),
            ),
            const SizedBox(height: 6),
            Text(
              _lastInteractionLabel(
                data.summary?.latestQualifyingInteractionDate,
              ),
              key: const Key('maps-contact-preview-last-interacted'),
              style: AppTypography.secondary.copyWith(
                color: AppTheme.secondaryTextOf(context),
              ),
            ),
            if (phone != null)
              _PreviewFact(label: 'Phone', value: phone.rawValue),
            if (address != null && address.isNotEmpty)
              _PreviewFact(label: 'Address', value: address),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              key: const Key('maps-contact-preview-directions'),
              onPressed: () => unawaited(
                MapExternalNavigation.launchWithFallback(
                  context,
                  widget.marker.coordinate,
                  label: detail.contact.displayName,
                ),
              ),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Directions'),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const Key('maps-contact-preview-edit-location'),
              onPressed: widget.onEditLocation,
              child: const Text('Edit Pin Location'),
            ),
            TextButton(
              key: const Key('maps-contact-preview-view'),
              onPressed: () {
                widget.onDismiss();
                unawaited(
                  context.push(RoutePaths.contactDetail(detail.contact.id)),
                );
              },
              child: const Text('View Contact'),
            ),
          ],
        );
      },
    );
  }
}

final class _EventMarkerPreview extends ConsumerStatefulWidget {
  const _EventMarkerPreview({
    required this.marker,
    required this.onDismiss,
    required this.onEditLocation,
    super.key,
  });

  final MapMarker marker;
  final VoidCallback onDismiss;
  final VoidCallback onEditLocation;

  @override
  ConsumerState<_EventMarkerPreview> createState() =>
      _EventMarkerPreviewState();
}

final class _EventMarkerPreviewState
    extends ConsumerState<_EventMarkerPreview> {
  late Future<_EventPreviewData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _EventMarkerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marker.ownerKey != widget.marker.ownerKey) {
      _future = _load();
    }
  }

  Future<_EventPreviewData?> _load() async {
    final originalDate = widget.marker.eventOriginalDate;
    if (originalDate == null) return null;
    final profileId = ref.read(mapProfileIdProvider);
    final occurrence = await ref
        .read(calendarEventRepositoryProvider)
        .readOccurrence(
          profileId: profileId,
          eventId: widget.marker.recordId,
          originalDate: originalDate,
        );
    if (occurrence == null) return null;
    final contacts = await ref
        .read(contactRepositoryProvider)
        .readEventParticipantPresentation(
          profileId: profileId,
          eventId: occurrence.eventId,
          occurrenceId: occurrence.id,
          historical: false,
        );
    return _EventPreviewData(occurrence: occurrence, contacts: contacts);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EventPreviewData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _PendingMarkerPreview(
            marker: widget.marker,
            failed: snapshot.hasError,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Text('This Event is no longer available on the map.');
        }
        final occurrence = data.occurrence;
        final address = occurrence.locationText?.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SinglePreviewHeading(
              marker: widget.marker,
              title: occurrence.displayTitle,
              titleKey: const Key('maps-event-preview-title'),
            ),
            const SizedBox(height: 6),
            Text(
              _eventTimeLabel(context, occurrence),
              key: const Key('maps-event-preview-time'),
              style: AppTypography.secondary.copyWith(
                color: AppTheme.secondaryTextOf(context),
              ),
            ),
            if (address != null && address.isNotEmpty)
              _PreviewFact(label: 'Address', value: address),
            if (data.contacts.isNotEmpty)
              _PreviewFact(
                label: 'Linked Contacts',
                value: data.contacts
                    .map((contact) => contact.displayName)
                    .join(', '),
              ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              key: const Key('maps-event-preview-directions'),
              onPressed: () => unawaited(
                MapExternalNavigation.launchWithFallback(
                  context,
                  widget.marker.coordinate,
                  label: occurrence.displayTitle,
                ),
              ),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Directions'),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const Key('maps-event-preview-edit-location'),
              onPressed: widget.onEditLocation,
              child: const Text('Edit Pin Location'),
            ),
            TextButton(
              key: const Key('maps-event-preview-view'),
              onPressed: () {
                widget.onDismiss();
                unawaited(
                  context.push(
                    RoutePaths.calendarEventDetail(
                      occurrence.eventId,
                      occurrence.originalDate,
                    ),
                  ),
                );
              },
              child: const Text('View Event'),
            ),
          ],
        );
      },
    );
  }
}

final class _SavedPlaceMarkerPreview extends ConsumerWidget {
  const _SavedPlaceMarkerPreview({
    required this.marker,
    required this.onDismiss,
    required this.onEditLocation,
    required this.onEditPlace,
    required this.onDeletePlace,
    super.key,
  });

  final MapMarker marker;
  final VoidCallback onDismiss;
  final VoidCallback onEditLocation;
  final VoidCallback? onEditPlace;
  final VoidCallback? onDeletePlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SinglePreviewHeading(
          marker: marker,
          title: marker.displayName,
          titleKey: const Key('maps-place-preview-label'),
        ),
        const SizedBox(height: 12),
        const _PreviewFact(label: 'Location', value: 'Saved map location'),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          key: const Key('maps-place-preview-directions'),
          onPressed: () => unawaited(
            MapExternalNavigation.launchWithFallback(
              context,
              marker.coordinate,
              label: marker.displayName,
            ),
          ),
          icon: const Icon(Icons.directions_outlined),
          label: const Text('Directions'),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const Key('maps-place-preview-edit-location'),
          onPressed: onEditLocation,
          child: const Text('Edit Pin Location'),
        ),
        if (onEditPlace != null || onDeletePlace != null)
          Row(
            children: <Widget>[
              if (onEditPlace != null)
                TextButton(
                  key: const Key('maps-place-preview-edit-place'),
                  onPressed: onEditPlace,
                  child: const Text('Edit Place'),
                ),
              if (onDeletePlace != null)
                TextButton(
                  key: const Key('maps-place-preview-delete-place'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onDeletePlace,
                  child: const Text('Delete Place'),
                ),
            ],
          ),
      ],
    );
  }
}

/// Selection identity is already in the marker payload. Show it immediately
/// while canonical repository details load, without retaining the prior row.
final class _PendingMarkerPreview extends StatelessWidget {
  const _PendingMarkerPreview({required this.marker, required this.failed});
  final MapMarker marker;
  final bool failed;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SinglePreviewHeading(marker: marker, title: marker.displayName),
      const SizedBox(height: 12),
      if (failed)
        const Text('Details could not be loaded.')
      else
        const LinearProgressIndicator(),
    ],
  );
}

final class _SinglePreviewHeading extends StatelessWidget {
  const _SinglePreviewHeading({
    required this.marker,
    required this.title,
    this.titleKey,
  });
  final MapMarker marker;
  final String title;
  final Key? titleKey;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      MapMarkerIdentityIcon(marker: marker),
      const SizedBox(width: 12),
      Expanded(
        child: Text(title, key: titleKey, style: AppTypography.sectionTitle),
      ),
    ],
  );
}

final class _ContactPreviewData {
  const _ContactPreviewData({required this.detail, required this.summary});

  final ContactDetail detail;
  final ContactSummary? summary;
}

final class _EventPreviewData {
  const _EventPreviewData({required this.occurrence, required this.contacts});

  final CalendarEventOccurrence occurrence;
  final List<EventParticipantPresentation> contacts;
}

final class _PreviewFact extends StatelessWidget {
  const _PreviewFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.micro.copyWith(
              color: AppTheme.secondaryTextOf(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: AppTypography.body),
        ],
      ),
    );
  }
}

ContactMethod? _preferredPhone(List<ContactMethod> methods) {
  for (final method in methods) {
    if (method.type == ContactMethodType.phone && method.isPrimary) {
      return method;
    }
  }
  for (final method in methods) {
    if (method.type == ContactMethodType.phone) {
      return method;
    }
  }
  return null;
}

String _lastInteractionLabel(DateTime? date) {
  if (date == null) return 'No recorded interaction yet';
  final days = DateTime.now().toLocal().difference(date.toLocal()).inDays;
  final relative = switch (days) {
    <= 0 => 'today',
    1 => '1 day ago',
    _ => '$days days ago',
  };
  return 'Last interacted $relative';
}

String _eventTimeLabel(
  BuildContext context,
  CalendarEventOccurrence occurrence,
) {
  if (occurrence.timing == CalendarEventTiming.allDay) return 'Today • All day';
  final start = occurrence.startDisplay;
  final end = occurrence.endDisplay;
  if (start == null || end == null) return 'Today';
  final localizations = MaterialLocalizations.of(context);
  final startText = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(start),
  );
  final endText = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end));
  return 'Today • $startText – $endText';
}
