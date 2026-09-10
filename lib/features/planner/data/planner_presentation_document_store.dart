import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/time/app_clock.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';

/// One read-only view of the profile's presentation preference document,
/// handed to an [PlannerPresentationDocumentStore.update] mutation.
///
/// [document] is the validated view (valid entries only). [rawGoalEventTypeNames]
/// carries the verbatim parsed `goalEventTypeNames` map, including entries the
/// validated view rejects, so unrelated writes can preserve unknown owner
/// content byte-for-byte instead of destroying it.
final class PlannerPresentationDocumentSnapshot {
  const PlannerPresentationDocumentSnapshot({
    required this.document,
    required this.rawGoalEventTypeNames,
    required this.hasStoredJson,
  });

  final PlannerColorPreferencesDocument document;

  /// Verbatim raw `goalEventTypeNames` entries (may contain invalid shapes).
  final Map<String, Object?> rawGoalEventTypeNames;

  /// Whether a non-blank JSON document was stored for this profile.
  final bool hasStoredJson;
}

/// Transactional read/merge/write helper for the profile-scoped Planner
/// Preferences presentation document (schema 46: event colors, Contact Group
/// colors, and Goal Event Type name overrides in ONE JSON column).
///
/// Every active full-document JSON write path must delegate here so a color
/// save, a group save, and a Goal name/color merge can never lose each
/// other's concurrent updates (lost-update prevention).
///
/// Atomicity law: [update] reads the current raw JSON, decodes it, applies
/// the narrow mutation, and writes only when the encoded result differs.
/// The whole read/merge/write — including loading the preference row — runs
/// inside `database.transaction`. When called inside an enclosing AppDatabase
/// transaction (for example the Goal Save transaction), the nested
/// `transaction` call participates in that enclosing zone, so the Goal row,
/// targets, outbox, and presentation merge commit or roll back together.
///
/// Fail-closed law: completely malformed stored JSON (unparseable, or not a
/// JSON object) REJECTS the mutation — unknown owner content is never
/// replaced with an empty document. Read-only access keeps the existing
/// fallback behavior (malformed reads as empty).
final class PlannerPresentationDocumentStore {
  const PlannerPresentationDocumentStore({
    required this.database,
    required this.clock,
  });

  final AppDatabase database;
  final AppClock clock;

  /// Validated read-only view of the current document. Malformed/absent data
  /// reads as the empty document (existing read fallback, zero writes).
  Future<PlannerColorPreferencesDocument> read(String profileId) async {
    final row = await (database.select(
      database.plannerPreferences,
    )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
    return EventColorPreferenceCodec.decodeDocument(
      row?.eventColorPreferencesJson,
    );
  }

  /// Transactional narrow mutation. The callback receives the current
  /// snapshot and returns the next validated document, or null when nothing
  /// should be written. Invalid raw metadata entries are preserved verbatim
  /// on unrelated writes; a valid entry removed by the mutation is removed
  /// exactly and never resurrected from the raw map.
  Future<PlannerColorPreferencesDocument> update(
    String profileId,
    Future<PlannerColorPreferencesDocument?> Function(
      PlannerPresentationDocumentSnapshot current,
    )
    mutate,
  ) async {
    // Participates in an enclosing transaction (drift runs nested
    // transaction blocks in the current transaction zone), so Goal Save and
    // this merge commit atomically together.
    return database.transaction(() async {
      final row = await (database.select(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
      final raw = row?.eventColorPreferencesJson;

      var rawGoalEventTypeNames = <String, Object?>{};
      if (raw != null && raw.trim().isNotEmpty) {
        final Object? decoded;
        try {
          decoded = jsonDecode(raw);
        } on FormatException {
          // Fail closed: never overwrite unknown owner content.
          throw const PresentationMutationRejectedException(
            'Stored planner preferences are not valid JSON; '
            'the change was rejected to protect your data.',
          );
        }
        if (decoded is! Map) {
          throw const PresentationMutationRejectedException(
            'Stored planner preferences have an unexpected shape; '
            'the change was rejected to protect your data.',
          );
        }
        final rawNames = decoded['goalEventTypeNames'];
        if (rawNames is Map) {
          rawGoalEventTypeNames = <String, Object?>{
            for (final entry in rawNames.entries)
              if (entry.key is String) entry.key as String: entry.value,
          };
        }
      }

      final current = EventColorPreferenceCodec.decodeDocument(raw);
      final next = await mutate(
        PlannerPresentationDocumentSnapshot(
          document: current,
          rawGoalEventTypeNames: rawGoalEventTypeNames,
          hasStoredJson: raw != null && raw.trim().isNotEmpty,
        ),
      );
      if (next == null) {
        return current;
      }

      final encoded = EventColorPreferenceCodec.encodeDocument(
        events: next.events,
        groups: next.groups,
        goalEventTypeNames: next.goalEventTypeNames,
      );
      final preserved = _preservedRawEntries(
        rawGoalEventTypeNames: rawGoalEventTypeNames,
        currentValid: current.goalEventTypeNames,
        nextValid: next.goalEventTypeNames,
      );
      final toWrite = preserved.isEmpty
          ? encoded
          : _injectPreservedEntries(encoded, preserved);

      if (toWrite == raw) {
        // Repeated read/update with no effective change: zero writes.
        return next;
      }

      if (row == null) {
        await database.into(database.plannerPreferences).insert(
              PlannerPreferencesCompanion.insert(
                profileId: profileId,
                eventColorPreferencesJson: Value<String?>(toWrite),
                updatedAtUtc: clock.nowUtc(),
              ),
            );
      } else {
        // Partial companion write: every unrelated PlannerPreferences column
        // is preserved untouched.
        await (database.update(
          database.plannerPreferences,
        )..where((table) => table.profileId.equals(profileId))).write(
          PlannerPreferencesCompanion(
            eventColorPreferencesJson: Value<String?>(toWrite),
            updatedAtUtc: Value<DateTime>(clock.nowUtc()),
          ),
        );
      }
      return next;
    });
  }

  /// Losslessly re-encodes the currently stored document (validated entries
  /// plus verbatim invalid metadata preservation) without writing. Used by
  /// full-document writers that must carry metadata forward inside their own
  /// transaction (for example savePlannerSettings).
  Future<String?> encodedCurrentDocument(String profileId) async {
    return database.transaction(() async {
      final row = await (database.select(
        database.plannerPreferences,
      )..where((table) => table.profileId.equals(profileId))).getSingleOrNull();
      final raw = row?.eventColorPreferencesJson;
      if (raw == null) {
        return null;
      }
      if (raw.trim().isEmpty) {
        return raw;
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        // Unparseable owner content is carried forward verbatim; a
        // full-document settings write must not silently destroy it.
        return raw;
      }
      if (decoded is! Map) {
        return raw;
      }
      final current = EventColorPreferenceCodec.decodeDocument(raw);
      final rawNames = decoded['goalEventTypeNames'];
      final rawGoalEventTypeNames = <String, Object?>{
        if (rawNames is Map)
          for (final entry in rawNames.entries)
            if (entry.key is String) entry.key as String: entry.value,
      };
      final encoded = EventColorPreferenceCodec.encodeDocument(
        events: current.events,
        groups: current.groups,
        goalEventTypeNames: current.goalEventTypeNames,
      );
      final preserved = _preservedRawEntries(
        rawGoalEventTypeNames: rawGoalEventTypeNames,
        currentValid: current.goalEventTypeNames,
        // Identity re-encode: nothing is removed, so every raw entry that is
        // not a valid override key is preserved.
        nextValid: current.goalEventTypeNames,
      );
      return preserved.isEmpty ? encoded : _injectPreservedEntries(
        encoded,
        preserved,
      );
    });
  }

  /// Raw entries to preserve verbatim: present in the raw map, absent from
  /// the next validated map, and NOT a valid current entry (a valid entry
  /// removed by the mutation is an explicit removal, never resurrected).
  static Map<String, Object?> _preservedRawEntries({
    required Map<String, Object?> rawGoalEventTypeNames,
    required Map<String, GoalEventTypeNameOverride> currentValid,
    required Map<String, GoalEventTypeNameOverride> nextValid,
  }) {
    final preserved = <String, Object?>{};
    rawGoalEventTypeNames.forEach((key, value) {
      if (nextValid.containsKey(key)) {
        return;
      }
      if (currentValid.containsKey(key)) {
        return;
      }
      preserved[key] = value;
    });
    return preserved;
  }

  static String _injectPreservedEntries(
    String encoded,
    Map<String, Object?> preserved,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      // encodeDocument output is always valid JSON; unreachable guard.
      return encoded;
    }
    final map = (decoded as Map).cast<String, Object?>();
    if (!map.containsKey('events')) {
      // Legacy flat document: injecting goalEventTypeNames at the top level
      // would make the mixed document envelope-shaped and the flat colors
      // would stop resolving (decodeDocument treats the whole map as
      // envelope contents only when an envelope key exists). Re-encode as a
      // proper envelope so flat event colors AND preserved raw metadata
      // both survive.
      return jsonEncode(<String, Object?>{
        'events': map,
        'goalEventTypeNames': <String, Object?>{...preserved},
      });
    }
    final names = (map['goalEventTypeNames'] as Map?)?.cast<String, Object?>()
        ?? <String, Object?>{};
    names.addAll(preserved);
    map['goalEventTypeNames'] = names;
    return jsonEncode(map);
  }
}

/// Sanitized mutation rejection (fail closed). Carries no row data.
final class PresentationMutationRejectedException implements Exception {
  const PresentationMutationRejectedException(this.message);

  final String message;

  @override
  String toString() => 'PresentationMutationRejectedException: $message';
}
