import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/maps/application/boundary_editor_controller.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';

/// Immutable snapshot of the owning Add/Edit Place form at the moment it
/// yields to the canonical Maps Define Boundary mode (M6.1 Pass 2).
///
/// The snapshot travels inside the session so the SAME form can be re-opened
/// with every unsaved value intact after Done/X — no form recreation that
/// destroys unsaved label/mode/category/emoji/color/boundary state.
final class SavedPlaceFormSnapshot {
  const SavedPlaceFormSnapshot({
    required this.label,
    required this.markerMode,
    required this.standardCategory,
    this.customEmoji,
    required this.markerColorHex,
    required this.boundaryColorHex,
    this.boundaryDraft,
    this.boundaryColorFollowsMarkerForNewBoundary = false,
  });

  /// Raw label text (unsaved values included).
  final String label;

  /// Standard/Custom segment state.
  final SavedPlaceMarkerMode markerMode;

  /// Selected Standard category (meaningful only in standard mode).
  final SavedPlaceStandardCategory standardCategory;

  /// Raw Custom emoji field text (may be empty).
  final String? customEmoji;

  /// Unsaved marker color hex.
  final String markerColorHex;

  /// Unsaved boundary color hex (independent of the marker color).
  final String boundaryColorHex;

  /// The form's current boundary draft. Null on Add with no boundary yet;
  /// on Edit it is the form's working copy of the persisted boundary.
  final SavedPlaceBoundary? boundaryDraft;

  /// M6.1 Pass 3 transient color-follow law: while TRUE, the form's pending
  /// boundary color automatically inherits every marker-color change for a
  /// NEW (not yet existing) boundary. It is form/session state ONLY — never
  /// Saved Place domain persistence, never database schema, never repository
  /// persistence. A successful Done boundary, an existing boundary, or any
  /// explicit Boundary Color choice sets it FALSE (independence).
  final bool boundaryColorFollowsMarkerForNewBoundary;

  /// Returns the snapshot with [boundary] applied. A Done draft also adopts
  /// its color AND its independence (followsMarker false); a Cancel keeps the
  /// prior draft, color, and follow flag untouched.
  SavedPlaceFormSnapshot withBoundary(SavedPlaceBoundary? boundary) {
    if (boundary == null) return this;
    return SavedPlaceFormSnapshot(
      label: label,
      markerMode: markerMode,
      standardCategory: standardCategory,
      customEmoji: customEmoji,
      markerColorHex: markerColorHex,
      boundaryColorHex: boundary.colorHex,
      boundaryDraft: boundary,
      boundaryColorFollowsMarkerForNewBoundary: false,
    );
  }
}

/// Which Add/Edit Place visit yielded to the canonical map, and how the form
/// must be re-opened when Define Boundary resolves.
sealed class BoundaryEditOrigin {
  const BoundaryEditOrigin();
}

/// The Add Place form yielded; the place does not exist yet.
final class BoundaryEditOriginAdd extends BoundaryEditOrigin {
  const BoundaryEditOriginAdd({required this.coordinate});

  final MapCoordinate coordinate;
}

/// The Edit Place form yielded; the place row identity re-opens the form.
final class BoundaryEditOriginEdit extends BoundaryEditOrigin {
  const BoundaryEditOriginEdit({required this.place});

  final SavedPlace place;
}

/// A live same-map Define Boundary session (M6.1 Pass 2).
///
/// The Add/Edit Place form no longer pushes a second GoogleMap. Instead the
/// form yields: it commits a [SavedPlaceFormSnapshot] here, pops itself, and
/// the canonical MapsScreen enters Define Boundary mode against its OWN
/// living map — same camera, same map type, same Contacts/Events/Places
/// context. Reusing [BoundaryEditorController] keeps the accepted M6.1
/// tap/undo/clear/done geometry law intact.
final class BoundaryEditSession {
  const BoundaryEditSession({
    required this.sessionId,
    required this.origin,
    required this.snapshot,
    required this.controller,
  });

  /// Stable nonce so results can never be delivered to the wrong visit.
  final int sessionId;

  final BoundaryEditOrigin origin;

  /// The exact form state at yield time; restores the form verbatim.
  final SavedPlaceFormSnapshot snapshot;

  /// Live draft lifecycle (tap/undo/clear/done). Zero persistence.
  final BoundaryEditorController controller;
}

final boundaryEditSessionProvider =
    NotifierProvider<BoundaryEditSessionController, BoundaryEditSession?>(
      BoundaryEditSessionController.new,
    );

final class BoundaryEditSessionController
    extends Notifier<BoundaryEditSession?> {
  int _nextSessionId = 0;

  @override
  BoundaryEditSession? build() => null;

  /// Called by the yielding Add/Edit Place form. Ends any stale session,
  /// records the bounded DEBUG timing origin (T0), and creates the live
  /// draft controller with the form's boundary color.
  void begin({
    required BoundaryEditOrigin origin,
    required SavedPlaceFormSnapshot snapshot,
  }) {
    endSession();
    BoundaryEditTimingTrace.reset();
    BoundaryEditTimingTrace.formRequest();
    state = BoundaryEditSession(
      sessionId: ++_nextSessionId,
      origin: origin,
      snapshot: snapshot,
      controller: BoundaryEditorController(colorHex: snapshot.boundaryColorHex),
    );
  }

  /// Resolves the session: Done passes the validated draft, X passes null.
  /// Always clears the active session (the canonical map returns to normal
  /// M3 interactions) and disposes the draft controller. Never writes the
  /// database — persistence stays exclusively with the main form Save.
  BoundaryEditSession? resolve(SavedPlaceBoundary? draft) {
    final session = state;
    endSession();
    return session;
  }

  /// Clears the active session and releases its draft controller.
  void endSession() {
    final session = state;
    if (session == null) return;
    session.controller.dispose();
    state = null;
  }
}

/// Bounded, DEBUG-only timing evidence for the owner-observed first-tap
/// delay. Four points, one line, no personal data:
/// T0 = form requests Define Boundary, T1 = canonical map boundary mode
/// active, T2 = first map tap callback, T3 = first vertex committed.
final class BoundaryEditTimingTrace {
  const BoundaryEditTimingTrace._();

  static int? _t0;
  static int? _t1;
  static int? _t2;
  static int? _t3;

  @visibleForTesting
  static int? get t0 => _t0;
  @visibleForTesting
  static int? get t1 => _t1;
  @visibleForTesting
  static int? get t2 => _t2;
  @visibleForTesting
  static int? get t3 => _t3;

  static void reset() {
    if (!kDebugMode) return;
    _t0 = _t1 = _t2 = _t3 = null;
  }

  static void formRequest() {
    if (!kDebugMode || _t0 != null) return;
    _t0 = _now();
  }

  static void mapModeActive() {
    if (!kDebugMode || _t1 != null) return;
    _t1 = _now();
    _flush();
  }

  static void tapReceived() {
    if (!kDebugMode || _t2 != null) return;
    _t2 = _now();
  }

  static void firstVertexCommitted() {
    if (!kDebugMode || _t3 != null) return;
    _t3 = _now();
    _flush();
  }

  static int _now() => DateTime.now().microsecondsSinceEpoch;

  static void _flush() {
    debugPrint(
      '[BoundaryTiming] T0=${_ms(_t0, _t0)}ms T0->T1=${_ms(_t0, _t1)}ms '
      'T1->T2=${_ms(_t1, _t2)}ms T2->T3=${_ms(_t2, _t3)}ms',
    );
  }

  static String _ms(int? from, int? to) {
    if (from == null || to == null) return 'n/a';
    return ((to - from) / 1000).toStringAsFixed(1);
  }
}
