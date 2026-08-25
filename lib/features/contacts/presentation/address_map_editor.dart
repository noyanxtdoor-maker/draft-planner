import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/contacts/presentation/unsaved_changes_guard.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/presentation/map_location_picker_screen.dart';
import 'package:rmplanner/features/maps/presentation/map_pin_section.dart';

/// Scoped A2 editor result. [coordinateChanged] distinguishes Cancel/no map
/// action from a deliberate set, edit, or clear; it owns no other Contact data.
final class AddressMapEditResult {
  const AddressMapEditResult({
    required this.address,
    required this.coordinate,
    required this.coordinateChanged,
  });

  final String address;
  final MapCoordinate? coordinate;
  final bool coordinateChanged;
}

final class AddressMapEditor extends StatefulWidget {
  const AddressMapEditor({
    required this.displayName,
    required this.initialAddress,
    required this.initialCoordinate,
    super.key,
  });

  final String displayName;
  final String? initialAddress;
  final MapCoordinate? initialCoordinate;

  @override
  State<AddressMapEditor> createState() => _AddressMapEditorState();
}

final class _AddressMapEditorState extends State<AddressMapEditor> {
  late final TextEditingController _address;
  late MapCoordinate? _coordinate;
  var _coordinateChanged = false;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.initialAddress ?? '');
    _coordinate = widget.initialCoordinate;
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickCoordinate() async {
    final picked = await context.push<MapCoordinate>(
      RoutePaths.mapPicker,
      extra: MapPickerArgs(
        displayName: widget.displayName,
        initialCoordinate: _coordinate,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _coordinate = picked;
        _coordinateChanged = true;
      });
    }
  }

  bool get _isDirty =>
      _address.text != (widget.initialAddress ?? '') ||
      _coordinate != widget.initialCoordinate;

  void _saveAndLeave() => Navigator.of(context).pop(
    AddressMapEditResult(
      address: _address.text,
      coordinate: _coordinate,
      coordinateChanged: _coordinateChanged,
    ),
  );

  Future<void> _requestClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final decision = await showUnsavedChangesGuard(context);
    if (!mounted) {
      return;
    }
    switch (decision) {
      case UnsavedChangesDecision.saveAndLeave:
        _saveAndLeave();
        return;
      case UnsavedChangesDecision.discardAndLeave:
        Navigator.of(context).pop();
        return;
      case UnsavedChangesDecision.keepEditing:
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinate = _coordinate;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address & Map'),
        leading: IconButton(
          key: const Key('address-map-cancel'),
          tooltip: 'Cancel',
          onPressed: _requestClose,
          icon: const Icon(Icons.close),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('address-map-save'),
            onPressed: _saveAndLeave,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              key: const Key('address-map-address'),
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 20),
            Text(
              'Saved Location',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (coordinate == null)
              FilledButton.tonalIcon(
                key: const Key('address-map-set-coordinate'),
                onPressed: _pickCoordinate,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Set saved location'),
              )
            else ...<Widget>[
              InkWell(
                key: const Key('address-map-coordinate'),
                onTap: _pickCoordinate,
                child: ContactLocationPreview(coordinate: coordinate),
              ),
              Row(
                children: <Widget>[
                  TextButton.icon(
                    key: const Key('address-map-edit-coordinate'),
                    onPressed: _pickCoordinate,
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Edit location'),
                  ),
                  TextButton.icon(
                    key: const Key('address-map-clear-coordinate'),
                    onPressed: () => setState(() {
                      _coordinate = null;
                      _coordinateChanged = true;
                    }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear location'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
