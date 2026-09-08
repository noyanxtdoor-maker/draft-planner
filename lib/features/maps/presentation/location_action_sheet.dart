import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';

/// One of the three location actions reachable from a chosen map coordinate.
/// Only the canonical Add Flow is opened; opening this chooser never persists
/// a Saved Place or any other row by itself.
enum MapLocationAction { place, contact, event }

/// Shared, draggable bottom sheet that both the exact long-press coordinate
/// and the confirmed dedicated Drop Pin coordinate converge on.
///
/// Visual intent follows the PMG-style reference: a small, high-contrast drag
/// handle, a smooth bottom-up entrance, established Next Transfer typography/
/// density, and reference icon concepts — place = map pin, contact = person,
/// event = calendar. Singular nouns only.
Future<MapLocationAction?> showMapLocationActionSheet(BuildContext context) {
  return showModalBottomSheet<MapLocationAction>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 260),
      reverseDuration: Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                key: const Key('location-action-handle'),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dragHandleOf(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add at this location',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 8),
            _LocationActionTile(
              key: const Key('location-action-place'),
              icon: Icons.location_on_outlined,
              label: 'Add Place',
              onTap: () =>
                  Navigator.of(sheetContext).pop(MapLocationAction.place),
            ),
            _LocationActionTile(
              key: const Key('location-action-contact'),
              icon: Icons.person_outline,
              label: 'Add Contact',
              onTap: () =>
                  Navigator.of(sheetContext).pop(MapLocationAction.contact),
            ),
            _LocationActionTile(
              key: const Key('location-action-event'),
              icon: Icons.calendar_month_outlined,
              label: 'Add Event',
              onTap: () =>
                  Navigator.of(sheetContext).pop(MapLocationAction.event),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _LocationActionTile extends StatelessWidget {
  const _LocationActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
    );
  }
}
