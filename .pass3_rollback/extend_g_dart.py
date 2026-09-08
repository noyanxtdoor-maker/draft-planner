#!/usr/bin/env python3
"""Surgical hand-extension of app_database.g.dart for MapsPreferences (v37).

Owner-authorized workaround for the drift_dev 2.34.0 <-> analyzer 12.1.0
generator failure. Every replacement is anchored to a unique existing string
and asserts exactly one match before applying.
"""
import io
import sys

PATH = r"C:/Users/sherl/Downloads/NT_C7_IMPLEMENTATION_20260825_235900/lib/core/database/app_database.g.dart"

with io.open(PATH, "r", encoding="utf-8", newline="") as f:
    src = f.read()

NL = "\n"

def replace_once(old, new, label):
    count = src.count(old)
    assert count == 1, f"{label}: expected 1 match, found {count}"
    return src.replace(old, new, 1)

# ---------------------------------------------------------------------------
# 1. Table + row + companion block, inserted before `abstract class _$AppDatabase`.
# ---------------------------------------------------------------------------
table_block = (
    "class $MapsPreferencesTable extends MapsPreferences"
    + NL
    + "    with TableInfo<$MapsPreferencesTable, MapsPreferenceRow> {"
    + NL
    + "  @override"
    + NL
    + "  final GeneratedDatabase attachedDatabase;"
    + NL
    + "  final String? _alias;"
    + NL
    + "  $MapsPreferencesTable(this.attachedDatabase, [this._alias]);"
    + NL
    + "  static const VerificationMeta _keyMeta = const VerificationMeta('key');"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<String> key = GeneratedColumn<String>("
    + NL
    + "    'key',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.string,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultValue: const Constant('primary'),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _mapTypeMeta = const VerificationMeta("
    + NL
    + "    'mapType',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<String> mapType = GeneratedColumn<String>("
    + NL
    + "    'map_type',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.string,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultValue: const Constant('satellite'),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _groupNearbyMarkersMeta = const VerificationMeta("
    + NL
    + "    'groupNearbyMarkers',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<bool> groupNearbyMarkers = GeneratedColumn<bool>("
    + NL
    + "    'group_nearby_markers',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.bool,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultConstraints: GeneratedColumn.constraintIsAlways("
    + NL
    + "      'CHECK (\"group_nearby_markers\" IN (0, 1))',"
    + NL
    + "    ),"
    + NL
    + "    defaultValue: const Constant(true),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _showContactsMeta = const VerificationMeta("
    + NL
    + "    'showContacts',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<bool> showContacts = GeneratedColumn<bool>("
    + NL
    + "    'show_contacts',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.bool,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultConstraints: GeneratedColumn.constraintIsAlways("
    + NL
    + "      'CHECK (\"show_contacts\" IN (0, 1))',"
    + NL
    + "    ),"
    + NL
    + "    defaultValue: const Constant(true),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _showEventsMeta = const VerificationMeta("
    + NL
    + "    'showEvents',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<bool> showEvents = GeneratedColumn<bool>("
    + NL
    + "    'show_events',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.bool,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultConstraints: GeneratedColumn.constraintIsAlways("
    + NL
    + "      'CHECK (\"show_events\" IN (0, 1))',"
    + NL
    + "    ),"
    + NL
    + "    defaultValue: const Constant(true),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _showSavedPlacesMeta = const VerificationMeta("
    + NL
    + "    'showSavedPlaces',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<bool> showSavedPlaces = GeneratedColumn<bool>("
    + NL
    + "    'show_saved_places',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.bool,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultConstraints: GeneratedColumn.constraintIsAlways("
    + NL
    + "      'CHECK (\"show_saved_places\" IN (0, 1))',"
    + NL
    + "    ),"
    + NL
    + "    defaultValue: const Constant(true),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _showBoundariesMeta = const VerificationMeta("
    + NL
    + "    'showBoundaries',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<bool> showBoundaries = GeneratedColumn<bool>("
    + NL
    + "    'show_boundaries',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.bool,"
    + NL
    + "    requiredDuringInsert: false,"
    + NL
    + "    defaultConstraints: GeneratedColumn.constraintIsAlways("
    + NL
    + "      'CHECK (\"show_boundaries\" IN (0, 1))',"
    + NL
    + "    ),"
    + NL
    + "    defaultValue: const Constant(true),"
    + NL
    + "  );"
    + NL
    + "  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta("
    + NL
    + "    'updatedAtUtc',"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>("
    + NL
    + "    'updated_at_utc',"
    + NL
    + "    aliasedName,"
    + NL
    + "    false,"
    + NL
    + "    type: DriftSqlType.dateTime,"
    + NL
    + "    requiredDuringInsert: true,"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  List<GeneratedColumn> get $columns => ["
    + NL
    + "    key,"
    + NL
    + "    mapType,"
    + NL
    + "    groupNearbyMarkers,"
    + NL
    + "    showContacts,"
    + NL
    + "    showEvents,"
    + NL
    + "    showSavedPlaces,"
    + NL
    + "    showBoundaries,"
    + NL
    + "    updatedAtUtc,"
    + NL
    + "  ];"
    + NL
    + "  @override"
    + NL
    + "  String get aliasedName => _alias ?? actualTableName;"
    + NL
    + "  @override"
    + NL
    + "  String get actualTableName => $name;"
    + NL
    + "  static const String $name = 'maps_preferences';"
    + NL
    + "  @override"
    + NL
    + "  VerificationContext validateIntegrity("
    + NL
    + "    Insertable<MapsPreferenceRow> instance, {"
    + NL
    + "    bool isInserting = false,"
    + NL
    + "  }) {"
    + NL
    + "    final context = VerificationContext();"
    + NL
    + "    final data = instance.toColumns(true);"
    + NL
    + "    if (data.containsKey('key')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _keyMeta,"
    + NL
    + "        key.isAcceptableOrUnknown(data['key']!, _keyMeta),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('map_type')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _mapTypeMeta,"
    + NL
    + "        mapType.isAcceptableOrUnknown(data['map_type']!, _mapTypeMeta),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('group_nearby_markers')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _groupNearbyMarkersMeta,"
    + NL
    + "        groupNearbyMarkers.isAcceptableOrUnknown("
    + NL
    + "          data['group_nearby_markers']!," + NL
    + "          _groupNearbyMarkersMeta,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('show_contacts')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _showContactsMeta,"
    + NL
    + "        showContacts.isAcceptableOrUnknown("
    + NL
    + "          data['show_contacts']!," + NL
    + "          _showContactsMeta,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('show_events')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _showEventsMeta,"
    + NL
    + "        showEvents.isAcceptableOrUnknown("
    + NL
    + "          data['show_events']!," + NL
    + "          _showEventsMeta,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('show_saved_places')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _showSavedPlacesMeta,"
    + NL
    + "        showSavedPlaces.isAcceptableOrUnknown("
    + NL
    + "          data['show_saved_places']!," + NL
    + "          _showSavedPlacesMeta,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('show_boundaries')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _showBoundariesMeta,"
    + NL
    + "        showBoundaries.isAcceptableOrUnknown("
    + NL
    + "          data['show_boundaries']!," + NL
    + "          _showBoundariesMeta,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "    }"
    + NL
    + "    if (data.containsKey('updated_at_utc')) {"
    + NL
    + "      context.handle("
    + NL
    + "        _updatedAtUtcMeta,"
    + NL
    + "        updatedAtUtc.isAcceptableOrUnknown("
    + NL
    + "          data['updated_at_utc']!," + NL
    + "          _updatedAtUtcMeta,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "    } else if (isInserting) {"
    + NL
    + "      context.missing(_updatedAtUtcMeta);"
    + NL
    + "    }"
    + NL
    + "    return context;"
    + NL
    + "  }"
    + NL
    + NL
    + "  @override"
    + NL
    + "  Set<GeneratedColumn> get $primaryKey => {key};"
    + NL
    + "  @override"
    + NL
    + "  MapsPreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {"
    + NL
    + "    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';"
    + NL
    + "    return MapsPreferenceRow("
    + NL
    + "      key: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.string,"
    + NL
    + "        data['${effectivePrefix}key'],"
    + NL
    + "      )!,"
    + NL
    + "      mapType: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.string,"
    + NL
    + "        data['${effectivePrefix}map_type'],"
    + NL
    + "      )!,"
    + NL
    + "      groupNearbyMarkers: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.bool,"
    + NL
    + "        data['${effectivePrefix}group_nearby_markers'],"
    + NL
    + "      )!,"
    + NL
    + "      showContacts: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.bool,"
    + NL
    + "        data['${effectivePrefix}show_contacts'],"
    + NL
    + "      )!,"
    + NL
    + "      showEvents: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.bool,"
    + NL
    + "        data['${effectivePrefix}show_events'],"
    + NL
    + "      )!,"
    + NL
    + "      showSavedPlaces: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.bool,"
    + NL
    + "        data['${effectivePrefix}show_saved_places'],"
    + NL
    + "      )!,"
    + NL
    + "      showBoundaries: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.bool,"
    + NL
    + "        data['${effectivePrefix}show_boundaries'],"
    + NL
    + "      )!,"
    + NL
    + "      updatedAtUtc: attachedDatabase.typeMapping.read("
    + NL
    + "        DriftSqlType.dateTime,"
    + NL
    + "        data['${effectivePrefix}updated_at_utc'],"
    + NL
    + "      )!,"
    + NL
    + "    );"
    + NL
    + "  }"
    + NL
    + NL
    + "  @override"
    + NL
    + "  $MapsPreferencesTable createAlias(String alias) {"
    + NL
    + "    return $MapsPreferencesTable(attachedDatabase, alias);"
    + NL
    + "  }"
    + NL
    + "}"
    + NL
    + NL
    + "class MapsPreferenceRow extends DataClass"
    + NL
    + "    implements Insertable<MapsPreferenceRow> {"
    + NL
    + "  final String key;"
    + NL
    + "  final String mapType;"
    + NL
    + "  final bool groupNearbyMarkers;"
    + NL
    + "  final bool showContacts;"
    + NL
    + "  final bool showEvents;"
    + NL
    + "  final bool showSavedPlaces;"
    + NL
    + "  final bool showBoundaries;"
    + NL
    + "  final DateTime updatedAtUtc;"
    + NL
    + "  const MapsPreferenceRow({"
    + NL
    + "    required this.key,"
    + NL
    + "    required this.mapType,"
    + NL
    + "    required this.groupNearbyMarkers,"
    + NL
    + "    required this.showContacts,"
    + NL
    + "    required this.showEvents,"
    + NL
    + "    required this.showSavedPlaces,"
    + NL
    + "    required this.showBoundaries,"
    + NL
    + "    required this.updatedAtUtc,"
    + NL
    + "  });"
    + NL
    + "  @override"
    + NL
    + "  Map<String, Expression> toColumns(bool nullToAbsent) {"
    + NL
    + "    final map = <String, Expression>{};"
    + NL
    + "    map['key'] = Variable<String>(key);"
    + NL
    + "    map['map_type'] = Variable<String>(mapType);"
    + NL
    + "    map['group_nearby_markers'] = Variable<bool>(groupNearbyMarkers);"
    + NL
    + "    map['show_contacts'] = Variable<bool>(showContacts);"
    + NL
    + "    map['show_events'] = Variable<bool>(showEvents);"
    + NL
    + "    map['show_saved_places'] = Variable<bool>(showSavedPlaces);"
    + NL
    + "    map['show_boundaries'] = Variable<bool>(showBoundaries);"
    + NL
    + "    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);"
    + NL
    + "    return map;"
    + NL
    + "  }"
    + NL
    + NL
    + "  MapsPreferencesCompanion toCompanion(bool nullToAbsent) {"
    + NL
    + "    return MapsPreferencesCompanion("
    + NL
    + "      key: Value(key),"
    + NL
    + "      mapType: Value(mapType),"
    + NL
    + "      groupNearbyMarkers: Value(groupNearbyMarkers),"
    + NL
    + "      showContacts: Value(showContacts),"
    + NL
    + "      showEvents: Value(showEvents),"
    + NL
    + "      showSavedPlaces: Value(showSavedPlaces),"
    + NL
    + "      showBoundaries: Value(showBoundaries),"
    + NL
    + "      updatedAtUtc: Value(updatedAtUtc),"
    + NL
    + "    );"
    + NL
    + "  }"
    + NL
    + NL
    + "  factory MapsPreferenceRow.fromJson("
    + NL
    + "    Map<String, dynamic> json, {"
    + NL
    + "    ValueSerializer? serializer,"
    + NL
    + "  }) {"
    + NL
    + "    serializer ??= driftRuntimeOptions.defaultSerializer;"
    + NL
    + "    return MapsPreferenceRow("
    + NL
    + "      key: serializer.fromJson<String>(json['key']),"
    + NL
    + "      mapType: serializer.fromJson<String>(json['mapType']),"
    + NL
    + "      groupNearbyMarkers: serializer.fromJson<bool>(json['groupNearbyMarkers']),"
    + NL
    + "      showContacts: serializer.fromJson<bool>(json['showContacts']),"
    + NL
    + "      showEvents: serializer.fromJson<bool>(json['showEvents']),"
    + NL
    + "      showSavedPlaces: serializer.fromJson<bool>(json['showSavedPlaces']),"
    + NL
    + "      showBoundaries: serializer.fromJson<bool>(json['showBoundaries']),"
    + NL
    + "      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),"
    + NL
    + "    );"
    + NL
    + "  }"
    + NL
    + "  @override"
    + NL
    + "  Map<String, dynamic> toJson({ValueSerializer? serializer}) {"
    + NL
    + "    serializer ??= driftRuntimeOptions.defaultSerializer;"
    + NL
    + "    return <String, dynamic>{"
    + NL
    + "      'key': serializer.toJson<String>(key),"
    + NL
    + "      'mapType': serializer.toJson<String>(mapType),"
    + NL
    + "      'groupNearbyMarkers': serializer.toJson<bool>(groupNearbyMarkers),"
    + NL
    + "      'showContacts': serializer.toJson<bool>(showContacts),"
    + NL
    + "      'showEvents': serializer.toJson<bool>(showEvents),"
    + NL
    + "      'showSavedPlaces': serializer.toJson<bool>(showSavedPlaces),"
    + NL
    + "      'showBoundaries': serializer.toJson<bool>(showBoundaries),"
    + NL
    + "      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),"
    + NL
    + "    };"
    + NL
    + "  }"
    + NL
    + NL
    + "  MapsPreferenceRow copyWith({"
    + NL
    + "    String? key,"
    + NL
    + "    String? mapType,"
    + NL
    + "    bool? groupNearbyMarkers,"
    + NL
    + "    bool? showContacts,"
    + NL
    + "    bool? showEvents,"
    + NL
    + "    bool? showSavedPlaces,"
    + NL
    + "    bool? showBoundaries,"
    + NL
    + "    DateTime? updatedAtUtc,"
    + NL
    + "  }) => MapsPreferenceRow("
    + NL
    + "    key: key ?? this.key,"
    + NL
    + "    mapType: mapType ?? this.mapType,"
    + NL
    + "    groupNearbyMarkers: groupNearbyMarkers ?? this.groupNearbyMarkers,"
    + NL
    + "    showContacts: showContacts ?? this.showContacts,"
    + NL
    + "    showEvents: showEvents ?? this.showEvents,"
    + NL
    + "    showSavedPlaces: showSavedPlaces ?? this.showSavedPlaces,"
    + NL
    + "    showBoundaries: showBoundaries ?? this.showBoundaries,"
    + NL
    + "    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,"
    + NL
    + "  );"
    + NL
    + "  MapsPreferenceRow copyWithCompanion(MapsPreferencesCompanion data) {"
    + NL
    + "    return MapsPreferenceRow("
    + NL
    + "      key: data.key.present ? data.key.value : this.key,"
    + NL
    + "      mapType: data.mapType.present ? data.mapType.value : this.mapType,"
    + NL
    + "      groupNearbyMarkers: data.groupNearbyMarkers.present"
    + NL
    + "          ? data.groupNearbyMarkers.value"
    + NL
    + "          : this.groupNearbyMarkers,"
    + NL
    + "      showContacts: data.showContacts.present"
    + NL
    + "          ? data.showContacts.value"
    + NL
    + "          : this.showContacts,"
    + NL
    + "      showEvents: data.showEvents.present"
    + NL
    + "          ? data.showEvents.value"
    + NL
    + "          : this.showEvents,"
    + NL
    + "      showSavedPlaces: data.showSavedPlaces.present"
    + NL
    + "          ? data.showSavedPlaces.value"
    + NL
    + "          : this.showSavedPlaces,"
    + NL
    + "      showBoundaries: data.showBoundaries.present"
    + NL
    + "          ? data.showBoundaries.value"
    + NL
    + "          : this.showBoundaries,"
    + NL
    + "      updatedAtUtc: data.updatedAtUtc.present"
    + NL
    + "          ? data.updatedAtUtc.value"
    + NL
    + "          : this.updatedAtUtc,"
    + NL
    + "    );"
    + NL
    + "  }"
    + NL
    + NL
    + "  @override"
    + NL
    + "  String toString() {"
    + NL
    + "    return (StringBuffer('MapsPreferenceRow(')"
    + NL
    + "          ..write('key: $key, ')"
    + NL
    + "          ..write('mapType: $mapType, ')"
    + NL
    + "          ..write('groupNearbyMarkers: $groupNearbyMarkers, ')"
    + NL
    + "          ..write('showContacts: $showContacts, ')"
    + NL
    + "          ..write('showEvents: $showEvents, ')"
    + NL
    + "          ..write('showSavedPlaces: $showSavedPlaces, ')"
    + NL
    + "          ..write('showBoundaries: $showBoundaries, ')"
    + NL
    + "          ..write('updatedAtUtc: $updatedAtUtc'"
    + NL
    + "          ..write(')'))"
    + NL
    + "        .toString();"
    + NL
    + "  }"
    + NL
    + NL
    + "  @override"
    + NL
    + "  int get hashCode => Object.hash("
    + NL
    + "    key,"
    + NL
    + "    mapType,"
    + NL
    + "    groupNearbyMarkers,"
    + NL
    + "    showContacts,"
    + NL
    + "    showEvents,"
    + NL
    + "    showSavedPlaces,"
    + NL
    + "    showBoundaries,"
    + NL
    + "    updatedAtUtc,"
    + NL
    + "  );"
    + NL
    + "  @override"
    + NL
    + "  bool operator ==(Object other) =>"
    + NL
    + "      identical(this, other) ||"
    + NL
    + "      (other is MapsPreferenceRow &&"
    + NL
    + "          other.key == this.key &&"
    + NL
    + "          other.mapType == this.mapType &&"
    + NL
    + "          other.groupNearbyMarkers == this.groupNearbyMarkers &&"
    + NL
    + "          other.showContacts == this.showContacts &&"
    + NL
    + "          other.showEvents == this.showEvents &&"
    + NL
    + "          other.showSavedPlaces == this.showSavedPlaces &&"
    + NL
    + "          other.showBoundaries == this.showBoundaries &&"
    + NL
    + "          other.updatedAtUtc == this.updatedAtUtc);"
    + NL
    + "}"
    + NL
    + NL
    + "class MapsPreferencesCompanion extends UpdateCompanion<MapsPreferenceRow> {"
    + NL
    + "  final Value<String> key;"
    + NL
    + "  final Value<String> mapType;"
    + NL
    + "  final Value<bool> groupNearbyMarkers;"
    + NL
    + "  final Value<bool> showContacts;"
    + NL
    + "  final Value<bool> showEvents;"
    + NL
    + "  final Value<bool> showSavedPlaces;"
    + NL
    + "  final Value<bool> showBoundaries;"
    + NL
    + "  final Value<DateTime> updatedAtUtc;"
    + NL
    + "  final Value<int> rowid;"
    + NL
    + "  const MapsPreferencesCompanion({"
    + NL
    + "    this.key = const Value.absent(),"
    + NL
    + "    this.mapType = const Value.absent(),"
    + NL
    + "    this.groupNearbyMarkers = const Value.absent(),"
    + NL
    + "    this.showContacts = const Value.absent(),"
    + NL
    + "    this.showEvents = const Value.absent(),"
    + NL
    + "    this.showSavedPlaces = const Value.absent(),"
    + NL
    + "    this.showBoundaries = const Value.absent(),"
    + NL
    + "    this.updatedAtUtc = const Value.absent(),"
    + NL
    + "    this.rowid = const Value.absent(),"
    + NL
    + "  });"
    + NL
    + "  MapsPreferencesCompanion.insert({"
    + NL
    + "    this.key = const Value.absent(),"
    + NL
    + "    this.mapType = const Value.absent(),"
    + NL
    + "    this.groupNearbyMarkers = const Value.absent(),"
    + NL
    + "    this.showContacts = const Value.absent(),"
    + NL
    + "    this.showEvents = const Value.absent(),"
    + NL
    + "    this.showSavedPlaces = const Value.absent(),"
    + NL
    + "    this.showBoundaries = const Value.absent(),"
    + NL
    + "    required DateTime updatedAtUtc,"
    + NL
    + "    this.rowid = const Value.absent(),"
    + NL
    + "  }) : updatedAtUtc = Value(updatedAtUtc);"
    + NL
    + "  static Insertable<MapsPreferenceRow> custom({"
    + NL
    + "    Expression<String>? key,"
    + NL
    + "    Expression<String>? mapType,"
    + NL
    + "    Expression<bool>? groupNearbyMarkers,"
    + NL
    + "    Expression<bool>? showContacts,"
    + NL
    + "    Expression<bool>? showEvents,"
    + NL
    + "    Expression<bool>? showSavedPlaces,"
    + NL
    + "    Expression<bool>? showBoundaries,"
    + NL
    + "    Expression<DateTime>? updatedAtUtc,"
    + NL
    + "    Expression<int>? rowid,"
    + NL
    + "  }) {"
    + NL
    + "    return RawValuesInsertable({"
    + NL
    + "      if (key != null) 'key': key,"
    + NL
    + "      if (mapType != null) 'map_type': mapType,"
    + NL
    + "      if (groupNearbyMarkers != null)"
    + NL
    + "        'group_nearby_markers': groupNearbyMarkers,"
    + NL
    + "      if (showContacts != null) 'show_contacts': showContacts,"
    + NL
    + "      if (showEvents != null) 'show_events': showEvents,"
    + NL
    + "      if (showSavedPlaces != null) 'show_saved_places': showSavedPlaces,"
    + NL
    + "      if (showBoundaries != null) 'show_boundaries': showBoundaries,"
    + NL
    + "      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,"
    + NL
    + "      if (rowid != null) 'rowid': rowid,"
    + NL
    + "    });"
    + NL
    + "  }"
    + NL
    + NL
    + "  MapsPreferencesCompanion copyWith({"
    + NL
    + "    Value<String>? key,"
    + NL
    + "    Value<String>? mapType,"
    + NL
    + "    Value<bool>? groupNearbyMarkers,"
    + NL
    + "    Value<bool>? showContacts,"
    + NL
    + "    Value<bool>? showEvents,"
    + NL
    + "    Value<bool>? showSavedPlaces,"
    + NL
    + "    Value<bool>? showBoundaries,"
    + NL
    + "    Value<DateTime>? updatedAtUtc,"
    + NL
    + "    Value<int>? rowid,"
    + NL
    + "  }) {"
    + NL
    + "    return MapsPreferencesCompanion("
    + NL
    + "      key: key ?? this.key,"
    + NL
    + "      mapType: mapType ?? this.mapType,"
    + NL
    + "      groupNearbyMarkers: groupNearbyMarkers ?? this.groupNearbyMarkers,"
    + NL
    + "      showContacts: showContacts ?? this.showContacts,"
    + NL
    + "      showEvents: showEvents ?? this.showEvents,"
    + NL
    + "      showSavedPlaces: showSavedPlaces ?? this.showSavedPlaces,"
    + NL
    + "      showBoundaries: showBoundaries ?? this.showBoundaries,"
    + NL
    + "      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,"
    + NL
    + "      rowid: rowid ?? this.rowid,"
    + NL
    + "    );"
    + NL
    + "  }"
    + NL
    + NL
    + "  @override"
    + NL
    + "  Map<String, Expression> toColumns(bool nullToAbsent) {"
    + NL
    + "    final map = <String, Expression>{};"
    + NL
    + "    if (key.present) {"
    + NL
    + "      map['key'] = Variable<String>(key.value);"
    + NL
    + "    }"
    + NL
    + "    if (mapType.present) {"
    + NL
    + "      map['map_type'] = Variable<String>(mapType.value);"
    + NL
    + "    }"
    + NL
    + "    if (groupNearbyMarkers.present) {"
    + NL
    + "      map['group_nearby_markers'] = Variable<bool>(groupNearbyMarkers.value);"
    + NL
    + "    }"
    + NL
    + "    if (showContacts.present) {"
    + NL
    + "      map['show_contacts'] = Variable<bool>(showContacts.value);"
    + NL
    + "    }"
    + NL
    + "    if (showEvents.present) {"
    + NL
    + "      map['show_events'] = Variable<bool>(showEvents.value);"
    + NL
    + "    }"
    + NL
    + "    if (showSavedPlaces.present) {"
    + NL
    + "      map['show_saved_places'] = Variable<bool>(showSavedPlaces.value);"
    + NL
    + "    }"
    + NL
    + "    if (showBoundaries.present) {"
    + NL
    + "      map['show_boundaries'] = Variable<bool>(showBoundaries.value);"
    + NL
    + "    }"
    + NL
    + "    if (updatedAtUtc.present) {"
    + NL
    + "      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);"
    + NL
    + "    }"
    + NL
    + "    if (rowid.present) {"
    + NL
    + "      map['rowid'] = Variable<int>(rowid.value);"
    + NL
    + "    }"
    + NL
    + "    return map;"
    + NL
    + "  }"
    + NL
    + NL
    + "  @override"
    + NL
    + "  String toString() {"
    + NL
    + "    return (StringBuffer('MapsPreferencesCompanion(')"
    + NL
    + "          ..write('key: $key, ')"
    + NL
    + "          ..write('mapType: $mapType, ')"
    + NL
    + "          ..write('groupNearbyMarkers: $groupNearbyMarkers, ')"
    + NL
    + "          ..write('showContacts: $showContacts, ')"
    + NL
    + "          ..write('showEvents: $showEvents, ')"
    + NL
    + "          ..write('showSavedPlaces: $showSavedPlaces, ')"
    + NL
    + "          ..write('showBoundaries: $showBoundaries, ')"
    + NL
    + "          ..write('updatedAtUtc: $updatedAtUtc, ')"
    + NL
    + "          ..write('rowid: $rowid'"
    + NL
    + "          ..write(')'))"
    + NL
    + "        .toString();"
    + NL
    + "  }"
    + NL
    + "}"
    + NL
    + NL
)

anchor1 = "}\n\nabstract class _$AppDatabase extends GeneratedDatabase {"
assert src.count(anchor1) == 1, "anchor1 (before _$AppDatabase) count mismatch"
src = src.replace(anchor1, table_block + "}\n\nabstract class _$AppDatabase extends GeneratedDatabase {", 1)

# ---------------------------------------------------------------------------
# 2. _$AppDatabase table accessor (after appearancePreferences accessor).
# ---------------------------------------------------------------------------
anchor2 = (
    "  late final $AppearancePreferencesTable appearancePreferences =\n"
    "      $AppearancePreferencesTable(this);\n"
)
assert src.count(anchor2) == 1, "anchor2 (accessor) count mismatch"
src = src.replace(
    anchor2,
    anchor2
    + "  late final $MapsPreferencesTable mapsPreferences = $MapsPreferencesTable(this);\n",
    1,
)

# ---------------------------------------------------------------------------
# 3. allSchemaEntities list entry.
# ---------------------------------------------------------------------------
anchor3 = "    savedPlaces,\n    appearancePreferences,\n    lifeIndicatorProfileKeyUnique,"
assert src.count(anchor3) == 1, "anchor3 (schema entities) count mismatch"
src = src.replace(
    anchor3,
    "    savedPlaces,\n    appearancePreferences,\n    mapsPreferences,\n    lifeIndicatorProfileKeyUnique,",
    1,
)

# ---------------------------------------------------------------------------
# 4. $AppDatabaseManager getter (before its closing brace).
# ---------------------------------------------------------------------------
anchor4 = (
    "  $$AppearancePreferencesTableTableManager get appearancePreferences =>\n"
    "      $$AppearancePreferencesTableTableManager(_db, _db.appearancePreferences);\n"
    "}\n"
)
assert src.count(anchor4) == 1, "anchor4 (manager getter) count mismatch"
src = src.replace(
    anchor4,
    "  $$AppearancePreferencesTableTableManager get appearancePreferences =>\n"
    "      $$AppearancePreferencesTableTableManager(_db, _db.appearancePreferences);\n"
    "  $$MapsPreferencesTableTableManager get mapsPreferences =>\n"
    "      $$MapsPreferencesTableTableManager(_db, _db.mapsPreferences);\n"
    "}\n",
    1,
)

# ---------------------------------------------------------------------------
# 5. Append the manager plumbing classes after the final closing brace.
# ---------------------------------------------------------------------------
plumbing = (
    "typedef $$MapsPreferencesTableCreateCompanionBuilder ="
    + NL
    + "    MapsPreferencesCompanion Function({"
    + NL
    + "      Value<String> key,"
    + NL
    + "      Value<String> mapType,"
    + NL
    + "      Value<bool> groupNearbyMarkers,"
    + NL
    + "      Value<bool> showContacts,"
    + NL
    + "      Value<bool> showEvents,"
    + NL
    + "      Value<bool> showSavedPlaces,"
    + NL
    + "      Value<bool> showBoundaries,"
    + NL
    + "      required DateTime updatedAtUtc,"
    + NL
    + "      Value<int> rowid,"
    + NL
    + "    });"
    + NL
    + "typedef $$MapsPreferencesTableUpdateCompanionBuilder ="
    + NL
    + "    MapsPreferencesCompanion Function({"
    + NL
    + "      Value<String> key,"
    + NL
    + "      Value<String> mapType,"
    + NL
    + "      Value<bool> groupNearbyMarkers,"
    + NL
    + "      Value<bool> showContacts,"
    + NL
    + "      Value<bool> showEvents,"
    + NL
    + "      Value<bool> showSavedPlaces,"
    + NL
    + "      Value<bool> showBoundaries,"
    + NL
    + "      Value<DateTime> updatedAtUtc,"
    + NL
    + "      Value<int> rowid,"
    + NL
    + "    });"
    + NL
    + NL
    + "class $$MapsPreferencesTableFilterComposer"
    + NL
    + "    extends Composer<_$AppDatabase, $MapsPreferencesTable> {"
    + NL
    + "  $$MapsPreferencesTableFilterComposer({"
    + NL
    + "    required super.$db,"
    + NL
    + "    required super.$table,"
    + NL
    + "    super.joinBuilder,"
    + NL
    + "    super.$addJoinBuilderToRootComposer,"
    + NL
    + "    super.$removeJoinBuilderFromRootComposer,"
    + NL
    + "  });"
    + NL
    + "  ColumnFilters<String> get key => $composableBuilder("
    + NL
    + "    column: $table.key,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<String> get mapType => $composableBuilder("
    + NL
    + "    column: $table.mapType,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<bool> get groupNearbyMarkers => $composableBuilder("
    + NL
    + "    column: $table.groupNearbyMarkers,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<bool> get showContacts => $composableBuilder("
    + NL
    + "    column: $table.showContacts,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<bool> get showEvents => $composableBuilder("
    + NL
    + "    column: $table.showEvents,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<bool> get showSavedPlaces => $composableBuilder("
    + NL
    + "    column: $table.showSavedPlaces,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<bool> get showBoundaries => $composableBuilder("
    + NL
    + "    column: $table.showBoundaries,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder("
    + NL
    + "    column: $table.updatedAtUtc,"
    + NL
    + "    builder: (column) => ColumnFilters(column),"
    + NL
    + "  );"
    + NL
    + "}"
    + NL
    + NL
    + "class $$MapsPreferencesTableOrderingComposer"
    + NL
    + "    extends Composer<_$AppDatabase, $MapsPreferencesTable> {"
    + NL
    + "  $$MapsPreferencesTableOrderingComposer({"
    + NL
    + "    required super.$db,"
    + NL
    + "    required super.$table,"
    + NL
    + "    super.joinBuilder,"
    + NL
    + "    super.$addJoinBuilderToRootComposer,"
    + NL
    + "    super.$removeJoinBuilderFromRootComposer,"
    + NL
    + "  });"
    + NL
    + "  ColumnOrderings<String> get key => $composableBuilder("
    + NL
    + "    column: $table.key,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<String> get mapType => $composableBuilder("
    + NL
    + "    column: $table.mapType,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<bool> get groupNearbyMarkers => $composableBuilder("
    + NL
    + "    column: $table.groupNearbyMarkers,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<bool> get showContacts => $composableBuilder("
    + NL
    + "    column: $table.showContacts,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<bool> get showEvents => $composableBuilder("
    + NL
    + "    column: $table.showEvents,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<bool> get showSavedPlaces => $composableBuilder("
    + NL
    + "    column: $table.showSavedPlaces,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<bool> get showBoundaries => $composableBuilder("
    + NL
    + "    column: $table.showBoundaries,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + NL
    + "  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder("
    + NL
    + "    column: $table.updatedAtUtc,"
    + NL
    + "    builder: (column) => ColumnOrderings(column),"
    + NL
    + "  );"
    + NL
    + "}"
    + NL
    + NL
    + "class $$MapsPreferencesTableAnnotationComposer"
    + NL
    + "    extends Composer<_$AppDatabase, $MapsPreferencesTable> {"
    + NL
    + "  $$MapsPreferencesTableAnnotationComposer({"
    + NL
    + "    required super.$db,"
    + NL
    + "    required super.$table,"
    + NL
    + "    super.joinBuilder,"
    + NL
    + "    super.$addJoinBuilderToRootComposer,"
    + NL
    + "    super.$removeJoinBuilderFromRootComposer,"
    + NL
    + "  });"
    + NL
    + "  GeneratedColumn<String> get key =>"
    + NL
    + "      $composableBuilder(column: $table.key, builder: (column) => column);"
    + NL
    + NL
    + "  GeneratedColumn<String> get mapType => $composableBuilder("
    + NL
    + "    column: $table.mapType,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + NL
    + "  GeneratedColumn<bool> get groupNearbyMarkers => $composableBuilder("
    + NL
    + "    column: $table.groupNearbyMarkers,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + NL
    + "  GeneratedColumn<bool> get showContacts => $composableBuilder("
    + NL
    + "    column: $table.showContacts,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + NL
    + "  GeneratedColumn<bool> get showEvents => $composableBuilder("
    + NL
    + "    column: $table.showEvents,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + NL
    + "  GeneratedColumn<bool> get showSavedPlaces => $composableBuilder("
    + NL
    + "    column: $table.showSavedPlaces,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + NL
    + "  GeneratedColumn<bool> get showBoundaries => $composableBuilder("
    + NL
    + "    column: $table.showBoundaries,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + NL
    + "  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder("
    + NL
    + "    column: $table.updatedAtUtc,"
    + NL
    + "    builder: (column) => column,"
    + NL
    + "  );"
    + NL
    + "}"
    + NL
    + NL
    + "class $$MapsPreferencesTableTableManager"
    + NL
    + "    extends"
    + NL
    + "        RootTableManager<"
    + NL
    + "          _$AppDatabase,"
    + NL
    + "          $MapsPreferencesTable,"
    + NL
    + "          MapsPreferenceRow,"
    + NL
    + "          $$MapsPreferencesTableFilterComposer,"
    + NL
    + "          $$MapsPreferencesTableOrderingComposer,"
    + NL
    + "          $$MapsPreferencesTableAnnotationComposer,"
    + NL
    + "          $$MapsPreferencesTableCreateCompanionBuilder,"
    + NL
    + "          $$MapsPreferencesTableUpdateCompanionBuilder,"
    + NL
    + "          ("
    + NL
    + "            MapsPreferenceRow,"
    + NL
    + "            BaseReferences<"
    + NL
    + "              _$AppDatabase,"
    + NL
    + "              $MapsPreferencesTable,"
    + NL
    + "              MapsPreferenceRow"
    + NL
    + "            >,"
    + NL
    + "          ),"
    + NL
    + "          MapsPreferenceRow,"
    + NL
    + "          PrefetchHooks Function()"
    + NL
    + "        > {"
    + NL
    + "  $$MapsPreferencesTableTableManager("
    + NL
    + "    _$AppDatabase db,"
    + NL
    + "    $MapsPreferencesTable table,"
    + NL
    + "  ) : super("
    + NL
    + "        TableManagerState("
    + NL
    + "          db: db,"
    + NL
    + "          table: table,"
    + NL
    + "          createFilteringComposer: () =>"
    + NL
    + "              $$MapsPreferencesTableFilterComposer("
    + NL
    + "                $db: db,"
    + NL
    + "                $table: table,"
    + NL
    + "              ),"
    + NL
    + "          createOrderingComposer: () =>"
    + NL
    + "              $$MapsPreferencesTableOrderingComposer("
    + NL
    + "                $db: db,"
    + NL
    + "                $table: table,"
    + NL
    + "              ),"
    + NL
    + "          createComputedFieldComposer: () =>"
    + NL
    + "              $$MapsPreferencesTableAnnotationComposer("
    + NL
    + "                $db: db,"
    + NL
    + "                $table: table,"
    + NL
    + "              ),"
    + NL
    + "          updateCompanionCallback:"
    + NL
    + "              ({"
    + NL
    + "                Value<String> key = const Value.absent(),"
    + NL
    + "                Value<String> mapType = const Value.absent(),"
    + NL
    + "                Value<bool> groupNearbyMarkers = const Value.absent(),"
    + NL
    + "                Value<bool> showContacts = const Value.absent(),"
    + NL
    + "                Value<bool> showEvents = const Value.absent(),"
    + NL
    + "                Value<bool> showSavedPlaces = const Value.absent(),"
    + NL
    + "                Value<bool> showBoundaries = const Value.absent(),"
    + NL
    + "                Value<DateTime> updatedAtUtc = const Value.absent(),"
    + NL
    + "                Value<int> rowid = const Value.absent(),"
    + NL
    + "              }) => MapsPreferencesCompanion("
    + NL
    + "                key: key,"
    + NL
    + "                mapType: mapType,"
    + NL
    + "                groupNearbyMarkers: groupNearbyMarkers,"
    + NL
    + "                showContacts: showContacts,"
    + NL
    + "                showEvents: showEvents,"
    + NL
    + "                showSavedPlaces: showSavedPlaces,"
    + NL
    + "                showBoundaries: showBoundaries,"
    + NL
    + "                updatedAtUtc: updatedAtUtc,"
    + NL
    + "                rowid: rowid,"
    + NL
    + "              ),"
    + NL
    + "          createCompanionCallback:"
    + NL
    + "              ({"
    + NL
    + "                Value<String> key = const Value.absent(),"
    + NL
    + "                Value<String> mapType = const Value.absent(),"
    + NL
    + "                Value<bool> groupNearbyMarkers = const Value.absent(),"
    + NL
    + "                Value<bool> showContacts = const Value.absent(),"
    + NL
    + "                Value<bool> showEvents = const Value.absent(),"
    + NL
    + "                Value<bool> showSavedPlaces = const Value.absent(),"
    + NL
    + "                Value<bool> showBoundaries = const Value.absent(),"
    + NL
    + "                required DateTime updatedAtUtc,"
    + NL
    + "                Value<int> rowid = const Value.absent(),"
    + NL
    + "              }) => MapsPreferencesCompanion.insert("
    + NL
    + "                key: key,"
    + NL
    + "                mapType: mapType,"
    + NL
    + "                groupNearbyMarkers: groupNearbyMarkers,"
    + NL
    + "                showContacts: showContacts,"
    + NL
    + "                showEvents: showEvents,"
    + NL
    + "                showSavedPlaces: showSavedPlaces,"
    + NL
    + "                showBoundaries: showBoundaries,"
    + NL
    + "                updatedAtUtc: updatedAtUtc,"
    + NL
    + "                rowid: rowid,"
    + NL
    + "              ),"
    + NL
    + "          withReferenceMapper: (p0) => p0"
    + NL
    + "              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))"
    + NL
    + "              .toList(),"
    + NL
    + "          prefetchHooksCallback: null,"
    + NL
    + "        ),"
    + NL
    + "      );"
    + NL
    + "}"
    + NL
    + NL
    + "typedef $$MapsPreferencesTableProcessedTableManager ="
    + NL
    + "    ProcessedTableManager<"
    + NL
    + "      _$AppDatabase,"
    + NL
    + "      $MapsPreferencesTable,"
    + NL
    + "      MapsPreferenceRow,"
    + NL
    + "      $$MapsPreferencesTableFilterComposer,"
    + NL
    + "      $$MapsPreferencesTableOrderingComposer,"
    + NL
    + "      $$MapsPreferencesTableAnnotationComposer,"
    + NL
    + "      $$MapsPreferencesTableCreateCompanionBuilder,"
    + NL
    + "      $$MapsPreferencesTableUpdateCompanionBuilder,"
    + NL
    + "      ("
    + NL
    + "        MapsPreferenceRow,"
    + NL
    + "        BaseReferences<"
    + NL
    + "          _$AppDatabase,"
    + NL
    + "          $MapsPreferencesTable,"
    + NL
    + "          MapsPreferenceRow"
    + NL
    + "        >,"
    + NL
    + "      ),"
    + NL
    + "      MapsPreferenceRow,"
    + NL
    + "      PrefetchHooks Function()"
    + NL
    + "    >;"
    + NL
)

assert src.endswith("}\n") or src.endswith("}"), "unexpected file tail"
src = src.rstrip("\n") + "\n" + plumbing.rstrip("\n") + "\n"

with io.open(PATH, "w", encoding="utf-8", newline="") as f:
    f.write(src)

print("OK: MapsPreferences generated structures inserted (5 anchors, all unique).")