import 'dart:convert';

import 'package:rmplanner/features/planner/domain/event_type.dart';

/// The two user-editable colors that describe one Planner Event Type.
///
/// Preferences are keyed by an Event Type stable key rather than copied onto
/// Calendar Event rows. This keeps color changes presentation-only and lets a
/// renamed or re-seeded Event Type retain its saved colors.
final class EventColorPreference {
  const EventColorPreference({
    required this.accentArgb,
    required this.surfaceArgb,
  });

  final int accentArgb;
  final int surfaceArgb;

  Map<String, int> toJson() => <String, int>{
    'accent': accentArgb,
    'surface': surfaceArgb,
  };

  static EventColorPreference? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final accent = _readArgb(value['accent']);
    final surface = _readArgb(value['surface']);
    if (accent == null || surface == null) {
      return null;
    }
    return EventColorPreference(accentArgb: accent, surfaceArgb: surface);
  }

  static int? _readArgb(Object? value) {
    if (value is! num || !value.isFinite) {
      return null;
    }
    final integer = value.toInt();
    return integer >= 0 && integer <= 0xFFFFFFFF ? integer : null;
  }

  @override
  bool operator ==(Object other) =>
      other is EventColorPreference &&
      other.accentArgb == accentArgb &&
      other.surfaceArgb == surfaceArgb;

  @override
  int get hashCode => Object.hash(accentArgb, surfaceArgb);
}

/// JSON codec for the existing profile-scoped Planner Preferences row.
abstract final class EventColorPreferenceCodec {
  static Map<String, EventColorPreference> decode(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) {
      return const <String, EventColorPreference>{};
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return const <String, EventColorPreference>{};
      }
      final result = <String, EventColorPreference>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        if (key is! String || key.trim().isEmpty) {
          continue;
        }
        final preference = EventColorPreference.fromJson(entry.value);
        if (preference != null) {
          result[key] = preference;
        }
      }
      return Map<String, EventColorPreference>.unmodifiable(result);
    } on FormatException {
      return const <String, EventColorPreference>{};
    }
  }

  static String encode(Map<String, EventColorPreference> preferences) {
    final json = <String, Map<String, int>>{
      for (final entry in preferences.entries)
        if (entry.key.trim().isNotEmpty) entry.key: entry.value.toJson(),
    };
    return jsonEncode(json);
  }
}

/// PMG-derived defaults used by the Event Colors settings screen.
///
/// The label map supports an existing or future custom Event Type whose
/// approved name already matches the PMG vocabulary. The icon map provides a
/// deterministic muted fallback for the current Next Transfer system types,
/// which intentionally do not use those PMG labels.
abstract final class PlannerEventColorDefaults {
  static const EventColorPreference teaching = EventColorPreference(
    accentArgb: 0xFFEBC766,
    surfaceArgb: 0xFF4C4942,
  );
  static const EventColorPreference finding = EventColorPreference(
    accentArgb: 0xFFDE9EDA,
    surfaceArgb: 0xFF4C464A,
  );
  static const EventColorPreference service = EventColorPreference(
    accentArgb: 0xFFDEEDF2,
    surfaceArgb: 0xFF404447,
  );
  static const EventColorPreference other = EventColorPreference(
    accentArgb: 0xFF868A8D,
    surfaceArgb: 0xFF494949,
  );
  static const EventColorPreference meeting = EventColorPreference(
    accentArgb: 0xFFE27386,
    surfaceArgb: 0xFF463D40,
  );
  static const EventColorPreference studyOrPlan = EventColorPreference(
    accentArgb: 0xFFA272C8,
    surfaceArgb: 0xFF47444B,
  );
  static const EventColorPreference contact = EventColorPreference(
    accentArgb: 0xFF76B181,
    surfaceArgb: 0xFF494E48,
  );
  static const EventColorPreference baptism = EventColorPreference(
    accentArgb: 0xFF98CED8,
    surfaceArgb: 0xFF454B4B,
  );
  static const EventColorPreference travel = EventColorPreference(
    accentArgb: 0xFFECC7D8,
    surfaceArgb: 0xFF4F4D4E,
  );
  static const EventColorPreference meal = EventColorPreference(
    accentArgb: 0xFFE1CFB9,
    surfaceArgb: 0xFF4B4744,
  );
  static const EventColorPreference task = EventColorPreference(
    accentArgb: 0xFFF2E9E0,
    surfaceArgb: 0xFF494844,
  );

  static const Map<String, EventColorPreference> _labelDefaults =
      <String, EventColorPreference>{
        'teaching': teaching,
        'finding': finding,
        'service': service,
        'other': other,
        'meeting': meeting,
        'study or plan': studyOrPlan,
        'contact': contact,
        'baptism': baptism,
        'travel': travel,
        'meal': meal,
        'task': task,
        'church activity': other,
        'new referral group message': other,
        'sacrament': EventColorPreference(
          accentArgb: 0xFFEAA15D,
          surfaceArgb: 0xFF474141,
        ),
      };

  /// Return the approved default pair for an existing Event Type.
  ///
  /// Current system types are mapped by icon so their category identity is
  /// retained even if the user has localized or renamed their label. Unknown
  /// custom types receive the muted neutral pair instead of a bright full
  /// block.
  static EventColorPreference forEventType(EventType type) {
    final byLabel = _labelDefaults[_normalize(type.label)];
    if (byLabel != null) {
      return byLabel;
    }
    return switch (type.icon) {
      EventTypeIcon.calendar => other,
      EventTypeIcon.temple => baptism,
      EventTypeIcon.scripture => studyOrPlan,
      EventTypeIcon.exercise => contact,
      EventTypeIcon.budget => meal,
      EventTypeIcon.job => finding,
      EventTypeIcon.connection => contact,
      EventTypeIcon.appointment => meeting,
      EventTypeIcon.work => service,
      EventTypeIcon.personal => travel,
    };
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}
