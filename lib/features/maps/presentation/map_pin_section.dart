import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/presentation/map_external_navigation.dart';
import 'package:rmplanner/features/maps/presentation/map_location_picker_screen.dart';

/// Maps V1 pin control used by the Contact and Event forms.
///
/// This widget is purely presentational: it opens the picker, reports
/// changes through [onChanged], and never writes to the database itself.
/// The owning form persists the pin AFTER the record save succeeds, so a
/// create-mode pin is never written to a row that does not exist yet.
final class MapPinSection extends StatelessWidget {
  const MapPinSection({
    super.key,
    required this.displayName,
    required this.coordinate,
    required this.onChanged,
  });

  /// The record's display name, used as the picker marker label.
  final String displayName;

  /// Current persisted (or pending) pin; null means no pin.
  final MapCoordinate? coordinate;

  /// Called with the newly picked coordinate, or null after Clear.
  final ValueChanged<MapCoordinate?> onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final result = await context.push<MapCoordinate>(
      RoutePaths.mapPicker,
      extra: MapPickerArgs(
        displayName: displayName,
        initialCoordinate: coordinate,
      ),
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = coordinate;
    return Semantics(
      container: true,
      label: current == null ? 'No map pin set' : 'Map pin set',
      child: Container(
        key: const Key('map-pin-section'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.outlineOf(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current == null ? 'Map pin' : 'Map pin: ${current.description}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                if (current == null)
                  FilledButton.tonalIcon(
                    key: const Key('map-pin-set'),
                    onPressed: () => _openPicker(context),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                    label: const Text('Set on map'),
                  )
                else ...<Widget>[
                  FilledButton.tonalIcon(
                    key: const Key('map-pin-edit'),
                    onPressed: () => _openPicker(context),
                    icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: const Text('Edit pin'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const Key('map-pin-clear'),
                    onPressed: () => onChanged(null),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const Key('map-pin-navigate'),
                    onPressed: () =>
                        MapExternalNavigation.launch(current, label: displayName),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Navigate'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
