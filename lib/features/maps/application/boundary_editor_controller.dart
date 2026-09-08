import 'package:flutter/foundation.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';

/// Pure in-editor drawing state for the VS-15 M6.1 Define Boundary screen.
///
/// The map tap -> vertex -> Undo/Clear/Done lifecycle lives here so it is
/// unit-testable without a native map. The controller never touches the
/// database: Done only RETURNS a validated draft (draft-until-Save law),
/// X/Cancel discards this visit's taps, and Clear keeps the user inside the
/// editor with zero writes.
final class BoundaryEditorController extends ChangeNotifier {
  BoundaryEditorController({
    required this.colorHex,
    List<MapCoordinate> initialVertices = const <MapCoordinate>[],
  }) : _vertices = List<MapCoordinate>.of(initialVertices);

  /// Boundary color used for the live draft polygon. Edited in the owning
  /// Add/Edit Place form; the editor renders with it and returns it unchanged.
  final String colorHex;

  final List<MapCoordinate> _vertices;

  /// Unmodifiable view of the current draft vertices in tap order.
  List<MapCoordinate> get vertices => List.unmodifiable(_vertices);

  bool get canUndo => _vertices.isNotEmpty;
  bool get canClear => _vertices.isNotEmpty;

  /// Done unlocks only for a geometry-valid outline (3+ non-collinear
  /// distinct vertices after dedupe/cap). Zero-area drafts stay locked out.
  bool get canDone => sanitizeBoundaryVertices(_vertices) != null;

  /// One map tap appends ONE vertex. Taps beyond the V1 cap are ignored so
  /// the draft can never exceed the persisted representation.
  void addVertex(MapCoordinate coordinate) {
    if (_vertices.length >= maxBoundaryVertices) return;
    _vertices.add(coordinate);
    notifyListeners();
  }

  /// Removes ONLY the newest vertex and stays in the editor.
  void undo() {
    if (_vertices.isEmpty) return;
    _vertices.removeLast();
    notifyListeners();
  }

  /// Removes ALL draft vertices and stays in the editor; the user can start
  /// redrawing immediately. Never writes anything.
  void clear() {
    if (_vertices.isEmpty) return;
    _vertices.clear();
    notifyListeners();
  }

  /// Validates and freezes the draft. Returns null when the outline cannot
  /// form a valid polygon (<3 distinct vertices or zero area); the caller
  /// keeps the editor open in that case.
  SavedPlaceBoundary? complete() {
    final vertices = sanitizeBoundaryVertices(_vertices);
    if (vertices == null) return null;
    return SavedPlaceBoundary(colorHex: colorHex, vertices: vertices);
  }
}
