// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalProfilesTable extends LocalProfiles
    with TableInfo<$LocalProfilesTable, LocalProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    defaultValue: const Constant('primary'),
  );
  static const VerificationMeta _localNameMeta = const VerificationMeta(
    'localName',
  );
  @override
  late final GeneratedColumn<String> localName = GeneratedColumn<String>(
    'local_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    slot,
    localName,
    displayName,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('local_name')) {
      context.handle(
        _localNameMeta,
        localName.isAcceptableOrUnknown(data['local_name']!, _localNameMeta),
      );
    } else if (isInserting) {
      context.missing(_localNameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      localName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_name'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $LocalProfilesTable createAlias(String alias) {
    return $LocalProfilesTable(attachedDatabase, alias);
  }
}

class LocalProfileRow extends DataClass implements Insertable<LocalProfileRow> {
  final String id;
  final String slot;
  final String localName;
  final String? displayName;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const LocalProfileRow({
    required this.id,
    required this.slot,
    required this.localName,
    this.displayName,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['slot'] = Variable<String>(slot);
    map['local_name'] = Variable<String>(localName);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  LocalProfilesCompanion toCompanion(bool nullToAbsent) {
    return LocalProfilesCompanion(
      id: Value(id),
      slot: Value(slot),
      localName: Value(localName),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory LocalProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfileRow(
      id: serializer.fromJson<String>(json['id']),
      slot: serializer.fromJson<String>(json['slot']),
      localName: serializer.fromJson<String>(json['localName']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'slot': serializer.toJson<String>(slot),
      'localName': serializer.toJson<String>(localName),
      'displayName': serializer.toJson<String?>(displayName),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  LocalProfileRow copyWith({
    String? id,
    String? slot,
    String? localName,
    Value<String?> displayName = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => LocalProfileRow(
    id: id ?? this.id,
    slot: slot ?? this.slot,
    localName: localName ?? this.localName,
    displayName: displayName.present ? displayName.value : this.displayName,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  LocalProfileRow copyWithCompanion(LocalProfilesCompanion data) {
    return LocalProfileRow(
      id: data.id.present ? data.id.value : this.id,
      slot: data.slot.present ? data.slot.value : this.slot,
      localName: data.localName.present ? data.localName.value : this.localName,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfileRow(')
          ..write('id: $id, ')
          ..write('slot: $slot, ')
          ..write('localName: $localName, ')
          ..write('displayName: $displayName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, slot, localName, displayName, createdAtUtc, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfileRow &&
          other.id == this.id &&
          other.slot == this.slot &&
          other.localName == this.localName &&
          other.displayName == this.displayName &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class LocalProfilesCompanion extends UpdateCompanion<LocalProfileRow> {
  final Value<String> id;
  final Value<String> slot;
  final Value<String> localName;
  final Value<String?> displayName;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const LocalProfilesCompanion({
    this.id = const Value.absent(),
    this.slot = const Value.absent(),
    this.localName = const Value.absent(),
    this.displayName = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalProfilesCompanion.insert({
    required String id,
    this.slot = const Value.absent(),
    required String localName,
    this.displayName = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localName = Value(localName),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<LocalProfileRow> custom({
    Expression<String>? id,
    Expression<String>? slot,
    Expression<String>? localName,
    Expression<String>? displayName,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (slot != null) 'slot': slot,
      if (localName != null) 'local_name': localName,
      if (displayName != null) 'display_name': displayName,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? slot,
    Value<String>? localName,
    Value<String?>? displayName,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return LocalProfilesCompanion(
      id: id ?? this.id,
      slot: slot ?? this.slot,
      localName: localName ?? this.localName,
      displayName: displayName ?? this.displayName,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (localName.present) {
      map['local_name'] = Variable<String>(localName.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfilesCompanion(')
          ..write('id: $id, ')
          ..write('slot: $slot, ')
          ..write('localName: $localName, ')
          ..write('displayName: $displayName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnboardingCheckpointsTable extends OnboardingCheckpoints
    with TableInfo<$OnboardingCheckpointsTable, OnboardingCheckpointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingCheckpointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('primary'),
  );
  static const VerificationMeta _pendingProfileIdMeta = const VerificationMeta(
    'pendingProfileId',
  );
  @override
  late final GeneratedColumn<String> pendingProfileId = GeneratedColumn<String>(
    'pending_profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftDisplayNameMeta = const VerificationMeta(
    'draftDisplayName',
  );
  @override
  late final GeneratedColumn<String> draftDisplayName = GeneratedColumn<String>(
    'draft_display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    pendingProfileId,
    stage,
    draftDisplayName,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnboardingCheckpointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('pending_profile_id')) {
      context.handle(
        _pendingProfileIdMeta,
        pendingProfileId.isAcceptableOrUnknown(
          data['pending_profile_id']!,
          _pendingProfileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pendingProfileIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('draft_display_name')) {
      context.handle(
        _draftDisplayNameMeta,
        draftDisplayName.isAcceptableOrUnknown(
          data['draft_display_name']!,
          _draftDisplayNameMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  OnboardingCheckpointRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingCheckpointRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      pendingProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pending_profile_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      draftDisplayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_display_name'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $OnboardingCheckpointsTable createAlias(String alias) {
    return $OnboardingCheckpointsTable(attachedDatabase, alias);
  }
}

class OnboardingCheckpointRow extends DataClass
    implements Insertable<OnboardingCheckpointRow> {
  final String key;
  final String pendingProfileId;
  final String stage;
  final String? draftDisplayName;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const OnboardingCheckpointRow({
    required this.key,
    required this.pendingProfileId,
    required this.stage,
    this.draftDisplayName,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['pending_profile_id'] = Variable<String>(pendingProfileId);
    map['stage'] = Variable<String>(stage);
    if (!nullToAbsent || draftDisplayName != null) {
      map['draft_display_name'] = Variable<String>(draftDisplayName);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  OnboardingCheckpointsCompanion toCompanion(bool nullToAbsent) {
    return OnboardingCheckpointsCompanion(
      key: Value(key),
      pendingProfileId: Value(pendingProfileId),
      stage: Value(stage),
      draftDisplayName: draftDisplayName == null && nullToAbsent
          ? const Value.absent()
          : Value(draftDisplayName),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory OnboardingCheckpointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingCheckpointRow(
      key: serializer.fromJson<String>(json['key']),
      pendingProfileId: serializer.fromJson<String>(json['pendingProfileId']),
      stage: serializer.fromJson<String>(json['stage']),
      draftDisplayName: serializer.fromJson<String?>(json['draftDisplayName']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'pendingProfileId': serializer.toJson<String>(pendingProfileId),
      'stage': serializer.toJson<String>(stage),
      'draftDisplayName': serializer.toJson<String?>(draftDisplayName),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  OnboardingCheckpointRow copyWith({
    String? key,
    String? pendingProfileId,
    String? stage,
    Value<String?> draftDisplayName = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => OnboardingCheckpointRow(
    key: key ?? this.key,
    pendingProfileId: pendingProfileId ?? this.pendingProfileId,
    stage: stage ?? this.stage,
    draftDisplayName: draftDisplayName.present
        ? draftDisplayName.value
        : this.draftDisplayName,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  OnboardingCheckpointRow copyWithCompanion(
    OnboardingCheckpointsCompanion data,
  ) {
    return OnboardingCheckpointRow(
      key: data.key.present ? data.key.value : this.key,
      pendingProfileId: data.pendingProfileId.present
          ? data.pendingProfileId.value
          : this.pendingProfileId,
      stage: data.stage.present ? data.stage.value : this.stage,
      draftDisplayName: data.draftDisplayName.present
          ? data.draftDisplayName.value
          : this.draftDisplayName,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCheckpointRow(')
          ..write('key: $key, ')
          ..write('pendingProfileId: $pendingProfileId, ')
          ..write('stage: $stage, ')
          ..write('draftDisplayName: $draftDisplayName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    key,
    pendingProfileId,
    stage,
    draftDisplayName,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingCheckpointRow &&
          other.key == this.key &&
          other.pendingProfileId == this.pendingProfileId &&
          other.stage == this.stage &&
          other.draftDisplayName == this.draftDisplayName &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class OnboardingCheckpointsCompanion
    extends UpdateCompanion<OnboardingCheckpointRow> {
  final Value<String> key;
  final Value<String> pendingProfileId;
  final Value<String> stage;
  final Value<String?> draftDisplayName;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const OnboardingCheckpointsCompanion({
    this.key = const Value.absent(),
    this.pendingProfileId = const Value.absent(),
    this.stage = const Value.absent(),
    this.draftDisplayName = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnboardingCheckpointsCompanion.insert({
    this.key = const Value.absent(),
    required String pendingProfileId,
    required String stage,
    this.draftDisplayName = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : pendingProfileId = Value(pendingProfileId),
       stage = Value(stage),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<OnboardingCheckpointRow> custom({
    Expression<String>? key,
    Expression<String>? pendingProfileId,
    Expression<String>? stage,
    Expression<String>? draftDisplayName,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (pendingProfileId != null) 'pending_profile_id': pendingProfileId,
      if (stage != null) 'stage': stage,
      if (draftDisplayName != null) 'draft_display_name': draftDisplayName,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnboardingCheckpointsCompanion copyWith({
    Value<String>? key,
    Value<String>? pendingProfileId,
    Value<String>? stage,
    Value<String?>? draftDisplayName,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return OnboardingCheckpointsCompanion(
      key: key ?? this.key,
      pendingProfileId: pendingProfileId ?? this.pendingProfileId,
      stage: stage ?? this.stage,
      draftDisplayName: draftDisplayName ?? this.draftDisplayName,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (pendingProfileId.present) {
      map['pending_profile_id'] = Variable<String>(pendingProfileId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (draftDisplayName.present) {
      map['draft_display_name'] = Variable<String>(draftDisplayName.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingCheckpointsCompanion(')
          ..write('key: $key, ')
          ..write('pendingProfileId: $pendingProfileId, ')
          ..write('stage: $stage, ')
          ..write('draftDisplayName: $draftDisplayName, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LifeIndicatorDefinitionsTable extends LifeIndicatorDefinitions
    with TableInfo<$LifeIndicatorDefinitionsTable, LifeIndicatorDefinitionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifeIndicatorDefinitionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_profiles (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _indicatorKeyMeta = const VerificationMeta(
    'indicatorKey',
  );
  @override
  late final GeneratedColumn<String> indicatorKey = GeneratedColumn<String>(
    'indicator_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> createdAtUtc = GeneratedColumn<DateTime>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    indicatorKey,
    label,
    unit,
    position,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'life_indicator_definitions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LifeIndicatorDefinitionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('indicator_key')) {
      context.handle(
        _indicatorKeyMeta,
        indicatorKey.isAcceptableOrUnknown(
          data['indicator_key']!,
          _indicatorKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_indicatorKeyMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifeIndicatorDefinitionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifeIndicatorDefinitionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      indicatorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}indicator_key'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $LifeIndicatorDefinitionsTable createAlias(String alias) {
    return $LifeIndicatorDefinitionsTable(attachedDatabase, alias);
  }
}

class LifeIndicatorDefinitionRow extends DataClass
    implements Insertable<LifeIndicatorDefinitionRow> {
  final String id;
  final String profileId;
  final String indicatorKey;
  final String label;
  final String unit;
  final int position;
  final DateTime createdAtUtc;
  const LifeIndicatorDefinitionRow({
    required this.id,
    required this.profileId,
    required this.indicatorKey,
    required this.label,
    required this.unit,
    required this.position,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['indicator_key'] = Variable<String>(indicatorKey);
    map['label'] = Variable<String>(label);
    map['unit'] = Variable<String>(unit);
    map['position'] = Variable<int>(position);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  LifeIndicatorDefinitionsCompanion toCompanion(bool nullToAbsent) {
    return LifeIndicatorDefinitionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      indicatorKey: Value(indicatorKey),
      label: Value(label),
      unit: Value(unit),
      position: Value(position),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory LifeIndicatorDefinitionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifeIndicatorDefinitionRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      indicatorKey: serializer.fromJson<String>(json['indicatorKey']),
      label: serializer.fromJson<String>(json['label']),
      unit: serializer.fromJson<String>(json['unit']),
      position: serializer.fromJson<int>(json['position']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'indicatorKey': serializer.toJson<String>(indicatorKey),
      'label': serializer.toJson<String>(label),
      'unit': serializer.toJson<String>(unit),
      'position': serializer.toJson<int>(position),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  LifeIndicatorDefinitionRow copyWith({
    String? id,
    String? profileId,
    String? indicatorKey,
    String? label,
    String? unit,
    int? position,
    DateTime? createdAtUtc,
  }) => LifeIndicatorDefinitionRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    indicatorKey: indicatorKey ?? this.indicatorKey,
    label: label ?? this.label,
    unit: unit ?? this.unit,
    position: position ?? this.position,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  LifeIndicatorDefinitionRow copyWithCompanion(
    LifeIndicatorDefinitionsCompanion data,
  ) {
    return LifeIndicatorDefinitionRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      indicatorKey: data.indicatorKey.present
          ? data.indicatorKey.value
          : this.indicatorKey,
      label: data.label.present ? data.label.value : this.label,
      unit: data.unit.present ? data.unit.value : this.unit,
      position: data.position.present ? data.position.value : this.position,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifeIndicatorDefinitionRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('indicatorKey: $indicatorKey, ')
          ..write('label: $label, ')
          ..write('unit: $unit, ')
          ..write('position: $position, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    indicatorKey,
    label,
    unit,
    position,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifeIndicatorDefinitionRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.indicatorKey == this.indicatorKey &&
          other.label == this.label &&
          other.unit == this.unit &&
          other.position == this.position &&
          other.createdAtUtc == this.createdAtUtc);
}

class LifeIndicatorDefinitionsCompanion
    extends UpdateCompanion<LifeIndicatorDefinitionRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> indicatorKey;
  final Value<String> label;
  final Value<String> unit;
  final Value<int> position;
  final Value<DateTime> createdAtUtc;
  final Value<int> rowid;
  const LifeIndicatorDefinitionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.indicatorKey = const Value.absent(),
    this.label = const Value.absent(),
    this.unit = const Value.absent(),
    this.position = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LifeIndicatorDefinitionsCompanion.insert({
    required String id,
    required String profileId,
    required String indicatorKey,
    required String label,
    required String unit,
    required int position,
    required DateTime createdAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       indicatorKey = Value(indicatorKey),
       label = Value(label),
       unit = Value(unit),
       position = Value(position),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<LifeIndicatorDefinitionRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? indicatorKey,
    Expression<String>? label,
    Expression<String>? unit,
    Expression<int>? position,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (indicatorKey != null) 'indicator_key': indicatorKey,
      if (label != null) 'label': label,
      if (unit != null) 'unit': unit,
      if (position != null) 'position': position,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LifeIndicatorDefinitionsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? indicatorKey,
    Value<String>? label,
    Value<String>? unit,
    Value<int>? position,
    Value<DateTime>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return LifeIndicatorDefinitionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      indicatorKey: indicatorKey ?? this.indicatorKey,
      label: label ?? this.label,
      unit: unit ?? this.unit,
      position: position ?? this.position,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (indicatorKey.present) {
      map['indicator_key'] = Variable<String>(indicatorKey.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<DateTime>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifeIndicatorDefinitionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('indicatorKey: $indicatorKey, ')
          ..write('label: $label, ')
          ..write('unit: $unit, ')
          ..write('position: $position, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrivacyPreferencesTable extends PrivacyPreferences
    with TableInfo<$PrivacyPreferencesTable, PrivacyPreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrivacyPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('primary'),
  );
  static const VerificationMeta _lockEnabledMeta = const VerificationMeta(
    'lockEnabled',
  );
  @override
  late final GeneratedColumn<bool> lockEnabled = GeneratedColumn<bool>(
    'lock_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lock_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notificationPreviewModeMeta =
      const VerificationMeta('notificationPreviewMode');
  @override
  late final GeneratedColumn<String> notificationPreviewMode =
      GeneratedColumn<String>(
        'notification_preview_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('hidden'),
      );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    key,
    lockEnabled,
    notificationPreviewMode,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'privacy_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrivacyPreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    }
    if (data.containsKey('lock_enabled')) {
      context.handle(
        _lockEnabledMeta,
        lockEnabled.isAcceptableOrUnknown(
          data['lock_enabled']!,
          _lockEnabledMeta,
        ),
      );
    }
    if (data.containsKey('notification_preview_mode')) {
      context.handle(
        _notificationPreviewModeMeta,
        notificationPreviewMode.isAcceptableOrUnknown(
          data['notification_preview_mode']!,
          _notificationPreviewModeMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  PrivacyPreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrivacyPreferenceRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      lockEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lock_enabled'],
      )!,
      notificationPreviewMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notification_preview_mode'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $PrivacyPreferencesTable createAlias(String alias) {
    return $PrivacyPreferencesTable(attachedDatabase, alias);
  }
}

class PrivacyPreferenceRow extends DataClass
    implements Insertable<PrivacyPreferenceRow> {
  final String key;
  final bool lockEnabled;
  final String notificationPreviewMode;
  final DateTime updatedAtUtc;
  const PrivacyPreferenceRow({
    required this.key,
    required this.lockEnabled,
    required this.notificationPreviewMode,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['lock_enabled'] = Variable<bool>(lockEnabled);
    map['notification_preview_mode'] = Variable<String>(
      notificationPreviewMode,
    );
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  PrivacyPreferencesCompanion toCompanion(bool nullToAbsent) {
    return PrivacyPreferencesCompanion(
      key: Value(key),
      lockEnabled: Value(lockEnabled),
      notificationPreviewMode: Value(notificationPreviewMode),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PrivacyPreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrivacyPreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      lockEnabled: serializer.fromJson<bool>(json['lockEnabled']),
      notificationPreviewMode: serializer.fromJson<String>(
        json['notificationPreviewMode'],
      ),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'lockEnabled': serializer.toJson<bool>(lockEnabled),
      'notificationPreviewMode': serializer.toJson<String>(
        notificationPreviewMode,
      ),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  PrivacyPreferenceRow copyWith({
    String? key,
    bool? lockEnabled,
    String? notificationPreviewMode,
    DateTime? updatedAtUtc,
  }) => PrivacyPreferenceRow(
    key: key ?? this.key,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    notificationPreviewMode:
        notificationPreviewMode ?? this.notificationPreviewMode,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PrivacyPreferenceRow copyWithCompanion(PrivacyPreferencesCompanion data) {
    return PrivacyPreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      lockEnabled: data.lockEnabled.present
          ? data.lockEnabled.value
          : this.lockEnabled,
      notificationPreviewMode: data.notificationPreviewMode.present
          ? data.notificationPreviewMode.value
          : this.notificationPreviewMode,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrivacyPreferenceRow(')
          ..write('key: $key, ')
          ..write('lockEnabled: $lockEnabled, ')
          ..write('notificationPreviewMode: $notificationPreviewMode, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, lockEnabled, notificationPreviewMode, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrivacyPreferenceRow &&
          other.key == this.key &&
          other.lockEnabled == this.lockEnabled &&
          other.notificationPreviewMode == this.notificationPreviewMode &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PrivacyPreferencesCompanion
    extends UpdateCompanion<PrivacyPreferenceRow> {
  final Value<String> key;
  final Value<bool> lockEnabled;
  final Value<String> notificationPreviewMode;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const PrivacyPreferencesCompanion({
    this.key = const Value.absent(),
    this.lockEnabled = const Value.absent(),
    this.notificationPreviewMode = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrivacyPreferencesCompanion.insert({
    this.key = const Value.absent(),
    this.lockEnabled = const Value.absent(),
    this.notificationPreviewMode = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PrivacyPreferenceRow> custom({
    Expression<String>? key,
    Expression<bool>? lockEnabled,
    Expression<String>? notificationPreviewMode,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (lockEnabled != null) 'lock_enabled': lockEnabled,
      if (notificationPreviewMode != null)
        'notification_preview_mode': notificationPreviewMode,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrivacyPreferencesCompanion copyWith({
    Value<String>? key,
    Value<bool>? lockEnabled,
    Value<String>? notificationPreviewMode,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PrivacyPreferencesCompanion(
      key: key ?? this.key,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      notificationPreviewMode:
          notificationPreviewMode ?? this.notificationPreviewMode,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (lockEnabled.present) {
      map['lock_enabled'] = Variable<bool>(lockEnabled.value);
    }
    if (notificationPreviewMode.present) {
      map['notification_preview_mode'] = Variable<String>(
        notificationPreviewMode.value,
      );
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrivacyPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('lockEnabled: $lockEnabled, ')
          ..write('notificationPreviewMode: $notificationPreviewMode, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PermissionAuditsTable extends PermissionAudits
    with TableInfo<$PermissionAuditsTable, PermissionAuditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PermissionAuditsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _permissionKeyMeta = const VerificationMeta(
    'permissionKey',
  );
  @override
  late final GeneratedColumn<String> permissionKey = GeneratedColumn<String>(
    'permission_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestedByAppMeta = const VerificationMeta(
    'requestedByApp',
  );
  @override
  late final GeneratedColumn<bool> requestedByApp = GeneratedColumn<bool>(
    'requested_by_app',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requested_by_app" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _everGrantedMeta = const VerificationMeta(
    'everGranted',
  );
  @override
  late final GeneratedColumn<bool> everGranted = GeneratedColumn<bool>(
    'ever_granted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ever_granted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAtUtc = GeneratedColumn<DateTime>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    permissionKey,
    requestedByApp,
    everGranted,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'permission_audits';
  @override
  VerificationContext validateIntegrity(
    Insertable<PermissionAuditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('permission_key')) {
      context.handle(
        _permissionKeyMeta,
        permissionKey.isAcceptableOrUnknown(
          data['permission_key']!,
          _permissionKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_permissionKeyMeta);
    }
    if (data.containsKey('requested_by_app')) {
      context.handle(
        _requestedByAppMeta,
        requestedByApp.isAcceptableOrUnknown(
          data['requested_by_app']!,
          _requestedByAppMeta,
        ),
      );
    }
    if (data.containsKey('ever_granted')) {
      context.handle(
        _everGrantedMeta,
        everGranted.isAcceptableOrUnknown(
          data['ever_granted']!,
          _everGrantedMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {permissionKey};
  @override
  PermissionAuditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PermissionAuditRow(
      permissionKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission_key'],
      )!,
      requestedByApp: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requested_by_app'],
      )!,
      everGranted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ever_granted'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $PermissionAuditsTable createAlias(String alias) {
    return $PermissionAuditsTable(attachedDatabase, alias);
  }
}

class PermissionAuditRow extends DataClass
    implements Insertable<PermissionAuditRow> {
  final String permissionKey;
  final bool requestedByApp;
  final bool everGranted;
  final DateTime updatedAtUtc;
  const PermissionAuditRow({
    required this.permissionKey,
    required this.requestedByApp,
    required this.everGranted,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['permission_key'] = Variable<String>(permissionKey);
    map['requested_by_app'] = Variable<bool>(requestedByApp);
    map['ever_granted'] = Variable<bool>(everGranted);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  PermissionAuditsCompanion toCompanion(bool nullToAbsent) {
    return PermissionAuditsCompanion(
      permissionKey: Value(permissionKey),
      requestedByApp: Value(requestedByApp),
      everGranted: Value(everGranted),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PermissionAuditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PermissionAuditRow(
      permissionKey: serializer.fromJson<String>(json['permissionKey']),
      requestedByApp: serializer.fromJson<bool>(json['requestedByApp']),
      everGranted: serializer.fromJson<bool>(json['everGranted']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'permissionKey': serializer.toJson<String>(permissionKey),
      'requestedByApp': serializer.toJson<bool>(requestedByApp),
      'everGranted': serializer.toJson<bool>(everGranted),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  PermissionAuditRow copyWith({
    String? permissionKey,
    bool? requestedByApp,
    bool? everGranted,
    DateTime? updatedAtUtc,
  }) => PermissionAuditRow(
    permissionKey: permissionKey ?? this.permissionKey,
    requestedByApp: requestedByApp ?? this.requestedByApp,
    everGranted: everGranted ?? this.everGranted,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PermissionAuditRow copyWithCompanion(PermissionAuditsCompanion data) {
    return PermissionAuditRow(
      permissionKey: data.permissionKey.present
          ? data.permissionKey.value
          : this.permissionKey,
      requestedByApp: data.requestedByApp.present
          ? data.requestedByApp.value
          : this.requestedByApp,
      everGranted: data.everGranted.present
          ? data.everGranted.value
          : this.everGranted,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PermissionAuditRow(')
          ..write('permissionKey: $permissionKey, ')
          ..write('requestedByApp: $requestedByApp, ')
          ..write('everGranted: $everGranted, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(permissionKey, requestedByApp, everGranted, updatedAtUtc);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PermissionAuditRow &&
          other.permissionKey == this.permissionKey &&
          other.requestedByApp == this.requestedByApp &&
          other.everGranted == this.everGranted &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PermissionAuditsCompanion extends UpdateCompanion<PermissionAuditRow> {
  final Value<String> permissionKey;
  final Value<bool> requestedByApp;
  final Value<bool> everGranted;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const PermissionAuditsCompanion({
    this.permissionKey = const Value.absent(),
    this.requestedByApp = const Value.absent(),
    this.everGranted = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PermissionAuditsCompanion.insert({
    required String permissionKey,
    this.requestedByApp = const Value.absent(),
    this.everGranted = const Value.absent(),
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : permissionKey = Value(permissionKey),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PermissionAuditRow> custom({
    Expression<String>? permissionKey,
    Expression<bool>? requestedByApp,
    Expression<bool>? everGranted,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (permissionKey != null) 'permission_key': permissionKey,
      if (requestedByApp != null) 'requested_by_app': requestedByApp,
      if (everGranted != null) 'ever_granted': everGranted,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PermissionAuditsCompanion copyWith({
    Value<String>? permissionKey,
    Value<bool>? requestedByApp,
    Value<bool>? everGranted,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PermissionAuditsCompanion(
      permissionKey: permissionKey ?? this.permissionKey,
      requestedByApp: requestedByApp ?? this.requestedByApp,
      everGranted: everGranted ?? this.everGranted,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (permissionKey.present) {
      map['permission_key'] = Variable<String>(permissionKey.value);
    }
    if (requestedByApp.present) {
      map['requested_by_app'] = Variable<bool>(requestedByApp.value);
    }
    if (everGranted.present) {
      map['ever_granted'] = Variable<bool>(everGranted.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PermissionAuditsCompanion(')
          ..write('permissionKey: $permissionKey, ')
          ..write('requestedByApp: $requestedByApp, ')
          ..write('everGranted: $everGranted, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalProfilesTable localProfiles = $LocalProfilesTable(this);
  late final $OnboardingCheckpointsTable onboardingCheckpoints =
      $OnboardingCheckpointsTable(this);
  late final $LifeIndicatorDefinitionsTable lifeIndicatorDefinitions =
      $LifeIndicatorDefinitionsTable(this);
  late final $PrivacyPreferencesTable privacyPreferences =
      $PrivacyPreferencesTable(this);
  late final $PermissionAuditsTable permissionAudits = $PermissionAuditsTable(
    this,
  );
  late final Index lifeIndicatorProfileKeyUnique = Index(
    'life_indicator_profile_key_unique',
    'CREATE UNIQUE INDEX life_indicator_profile_key_unique ON life_indicator_definitions (profile_id, indicator_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localProfiles,
    onboardingCheckpoints,
    lifeIndicatorDefinitions,
    privacyPreferences,
    permissionAudits,
    lifeIndicatorProfileKeyUnique,
  ];
}

typedef $$LocalProfilesTableCreateCompanionBuilder =
    LocalProfilesCompanion Function({
      required String id,
      Value<String> slot,
      required String localName,
      Value<String?> displayName,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$LocalProfilesTableUpdateCompanionBuilder =
    LocalProfilesCompanion Function({
      Value<String> id,
      Value<String> slot,
      Value<String> localName,
      Value<String?> displayName,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$LocalProfilesTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalProfilesTable, LocalProfileRow> {
  $$LocalProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $LifeIndicatorDefinitionsTable,
    List<LifeIndicatorDefinitionRow>
  >
  _lifeIndicatorDefinitionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.lifeIndicatorDefinitions,
        aliasName: 'local_profiles__id__life_indicator_definitions__profile_id',
      );

  $$LifeIndicatorDefinitionsTableProcessedTableManager
  get lifeIndicatorDefinitionsRefs {
    final manager = $$LifeIndicatorDefinitionsTableTableManager(
      $_db,
      $_db.lifeIndicatorDefinitions,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _lifeIndicatorDefinitionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localName => $composableBuilder(
    column: $table.localName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> lifeIndicatorDefinitionsRefs(
    Expression<bool> Function($$LifeIndicatorDefinitionsTableFilterComposer f)
    f,
  ) {
    final $$LifeIndicatorDefinitionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.lifeIndicatorDefinitions,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifeIndicatorDefinitionsTableFilterComposer(
                $db: $db,
                $table: $db.lifeIndicatorDefinitions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localName => $composableBuilder(
    column: $table.localName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalProfilesTable> {
  $$LocalProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get localName =>
      $composableBuilder(column: $table.localName, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  Expression<T> lifeIndicatorDefinitionsRefs<T extends Object>(
    Expression<T> Function($$LifeIndicatorDefinitionsTableAnnotationComposer a)
    f,
  ) {
    final $$LifeIndicatorDefinitionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.lifeIndicatorDefinitions,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifeIndicatorDefinitionsTableAnnotationComposer(
                $db: $db,
                $table: $db.lifeIndicatorDefinitions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LocalProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalProfilesTable,
          LocalProfileRow,
          $$LocalProfilesTableFilterComposer,
          $$LocalProfilesTableOrderingComposer,
          $$LocalProfilesTableAnnotationComposer,
          $$LocalProfilesTableCreateCompanionBuilder,
          $$LocalProfilesTableUpdateCompanionBuilder,
          (LocalProfileRow, $$LocalProfilesTableReferences),
          LocalProfileRow,
          PrefetchHooks Function({bool lifeIndicatorDefinitionsRefs})
        > {
  $$LocalProfilesTableTableManager(_$AppDatabase db, $LocalProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String> localName = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion(
                id: id,
                slot: slot,
                localName: localName,
                displayName: displayName,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> slot = const Value.absent(),
                required String localName,
                Value<String?> displayName = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => LocalProfilesCompanion.insert(
                id: id,
                slot: slot,
                localName: localName,
                displayName: displayName,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({lifeIndicatorDefinitionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (lifeIndicatorDefinitionsRefs) db.lifeIndicatorDefinitions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (lifeIndicatorDefinitionsRefs)
                    await $_getPrefetchedData<
                      LocalProfileRow,
                      $LocalProfilesTable,
                      LifeIndicatorDefinitionRow
                    >(
                      currentTable: table,
                      referencedTable: $$LocalProfilesTableReferences
                          ._lifeIndicatorDefinitionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).lifeIndicatorDefinitionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.profileId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalProfilesTable,
      LocalProfileRow,
      $$LocalProfilesTableFilterComposer,
      $$LocalProfilesTableOrderingComposer,
      $$LocalProfilesTableAnnotationComposer,
      $$LocalProfilesTableCreateCompanionBuilder,
      $$LocalProfilesTableUpdateCompanionBuilder,
      (LocalProfileRow, $$LocalProfilesTableReferences),
      LocalProfileRow,
      PrefetchHooks Function({bool lifeIndicatorDefinitionsRefs})
    >;
typedef $$OnboardingCheckpointsTableCreateCompanionBuilder =
    OnboardingCheckpointsCompanion Function({
      Value<String> key,
      required String pendingProfileId,
      required String stage,
      Value<String?> draftDisplayName,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$OnboardingCheckpointsTableUpdateCompanionBuilder =
    OnboardingCheckpointsCompanion Function({
      Value<String> key,
      Value<String> pendingProfileId,
      Value<String> stage,
      Value<String?> draftDisplayName,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$OnboardingCheckpointsTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingCheckpointsTable> {
  $$OnboardingCheckpointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pendingProfileId => $composableBuilder(
    column: $table.pendingProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftDisplayName => $composableBuilder(
    column: $table.draftDisplayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnboardingCheckpointsTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingCheckpointsTable> {
  $$OnboardingCheckpointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pendingProfileId => $composableBuilder(
    column: $table.pendingProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftDisplayName => $composableBuilder(
    column: $table.draftDisplayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnboardingCheckpointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingCheckpointsTable> {
  $$OnboardingCheckpointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get pendingProfileId => $composableBuilder(
    column: $table.pendingProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get draftDisplayName => $composableBuilder(
    column: $table.draftDisplayName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$OnboardingCheckpointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnboardingCheckpointsTable,
          OnboardingCheckpointRow,
          $$OnboardingCheckpointsTableFilterComposer,
          $$OnboardingCheckpointsTableOrderingComposer,
          $$OnboardingCheckpointsTableAnnotationComposer,
          $$OnboardingCheckpointsTableCreateCompanionBuilder,
          $$OnboardingCheckpointsTableUpdateCompanionBuilder,
          (
            OnboardingCheckpointRow,
            BaseReferences<
              _$AppDatabase,
              $OnboardingCheckpointsTable,
              OnboardingCheckpointRow
            >,
          ),
          OnboardingCheckpointRow,
          PrefetchHooks Function()
        > {
  $$OnboardingCheckpointsTableTableManager(
    _$AppDatabase db,
    $OnboardingCheckpointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingCheckpointsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OnboardingCheckpointsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OnboardingCheckpointsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> pendingProfileId = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String?> draftDisplayName = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnboardingCheckpointsCompanion(
                key: key,
                pendingProfileId: pendingProfileId,
                stage: stage,
                draftDisplayName: draftDisplayName,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                required String pendingProfileId,
                required String stage,
                Value<String?> draftDisplayName = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => OnboardingCheckpointsCompanion.insert(
                key: key,
                pendingProfileId: pendingProfileId,
                stage: stage,
                draftDisplayName: draftDisplayName,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnboardingCheckpointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnboardingCheckpointsTable,
      OnboardingCheckpointRow,
      $$OnboardingCheckpointsTableFilterComposer,
      $$OnboardingCheckpointsTableOrderingComposer,
      $$OnboardingCheckpointsTableAnnotationComposer,
      $$OnboardingCheckpointsTableCreateCompanionBuilder,
      $$OnboardingCheckpointsTableUpdateCompanionBuilder,
      (
        OnboardingCheckpointRow,
        BaseReferences<
          _$AppDatabase,
          $OnboardingCheckpointsTable,
          OnboardingCheckpointRow
        >,
      ),
      OnboardingCheckpointRow,
      PrefetchHooks Function()
    >;
typedef $$LifeIndicatorDefinitionsTableCreateCompanionBuilder =
    LifeIndicatorDefinitionsCompanion Function({
      required String id,
      required String profileId,
      required String indicatorKey,
      required String label,
      required String unit,
      required int position,
      required DateTime createdAtUtc,
      Value<int> rowid,
    });
typedef $$LifeIndicatorDefinitionsTableUpdateCompanionBuilder =
    LifeIndicatorDefinitionsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> indicatorKey,
      Value<String> label,
      Value<String> unit,
      Value<int> position,
      Value<DateTime> createdAtUtc,
      Value<int> rowid,
    });

final class $$LifeIndicatorDefinitionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LifeIndicatorDefinitionsTable,
          LifeIndicatorDefinitionRow
        > {
  $$LifeIndicatorDefinitionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) =>
      db.localProfiles.createAlias(
        'life_indicator_definitions__profile_id__local_profiles__id',
      );

  $$LocalProfilesTableProcessedTableManager get profileId {
    final $_column = $_itemColumn<String>('profile_id')!;

    final manager = $$LocalProfilesTableTableManager(
      $_db,
      $_db.localProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LifeIndicatorDefinitionsTableFilterComposer
    extends Composer<_$AppDatabase, $LifeIndicatorDefinitionsTable> {
  $$LifeIndicatorDefinitionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indicatorKey => $composableBuilder(
    column: $table.indicatorKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalProfilesTableFilterComposer get profileId {
    final $$LocalProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.localProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalProfilesTableFilterComposer(
            $db: $db,
            $table: $db.localProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LifeIndicatorDefinitionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LifeIndicatorDefinitionsTable> {
  $$LifeIndicatorDefinitionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indicatorKey => $composableBuilder(
    column: $table.indicatorKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalProfilesTableOrderingComposer get profileId {
    final $$LocalProfilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.localProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalProfilesTableOrderingComposer(
            $db: $db,
            $table: $db.localProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LifeIndicatorDefinitionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifeIndicatorDefinitionsTable> {
  $$LifeIndicatorDefinitionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get indicatorKey => $composableBuilder(
    column: $table.indicatorKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  $$LocalProfilesTableAnnotationComposer get profileId {
    final $$LocalProfilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileId,
      referencedTable: $db.localProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalProfilesTableAnnotationComposer(
            $db: $db,
            $table: $db.localProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LifeIndicatorDefinitionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LifeIndicatorDefinitionsTable,
          LifeIndicatorDefinitionRow,
          $$LifeIndicatorDefinitionsTableFilterComposer,
          $$LifeIndicatorDefinitionsTableOrderingComposer,
          $$LifeIndicatorDefinitionsTableAnnotationComposer,
          $$LifeIndicatorDefinitionsTableCreateCompanionBuilder,
          $$LifeIndicatorDefinitionsTableUpdateCompanionBuilder,
          (
            LifeIndicatorDefinitionRow,
            $$LifeIndicatorDefinitionsTableReferences,
          ),
          LifeIndicatorDefinitionRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$LifeIndicatorDefinitionsTableTableManager(
    _$AppDatabase db,
    $LifeIndicatorDefinitionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifeIndicatorDefinitionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LifeIndicatorDefinitionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LifeIndicatorDefinitionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> indicatorKey = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LifeIndicatorDefinitionsCompanion(
                id: id,
                profileId: profileId,
                indicatorKey: indicatorKey,
                label: label,
                unit: unit,
                position: position,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String indicatorKey,
                required String label,
                required String unit,
                required int position,
                required DateTime createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => LifeIndicatorDefinitionsCompanion.insert(
                id: id,
                profileId: profileId,
                indicatorKey: indicatorKey,
                label: label,
                unit: unit,
                position: position,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LifeIndicatorDefinitionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileId,
                                referencedTable:
                                    $$LifeIndicatorDefinitionsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$LifeIndicatorDefinitionsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LifeIndicatorDefinitionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LifeIndicatorDefinitionsTable,
      LifeIndicatorDefinitionRow,
      $$LifeIndicatorDefinitionsTableFilterComposer,
      $$LifeIndicatorDefinitionsTableOrderingComposer,
      $$LifeIndicatorDefinitionsTableAnnotationComposer,
      $$LifeIndicatorDefinitionsTableCreateCompanionBuilder,
      $$LifeIndicatorDefinitionsTableUpdateCompanionBuilder,
      (LifeIndicatorDefinitionRow, $$LifeIndicatorDefinitionsTableReferences),
      LifeIndicatorDefinitionRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$PrivacyPreferencesTableCreateCompanionBuilder =
    PrivacyPreferencesCompanion Function({
      Value<String> key,
      Value<bool> lockEnabled,
      Value<String> notificationPreviewMode,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PrivacyPreferencesTableUpdateCompanionBuilder =
    PrivacyPreferencesCompanion Function({
      Value<String> key,
      Value<bool> lockEnabled,
      Value<String> notificationPreviewMode,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$PrivacyPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PrivacyPreferencesTable> {
  $$PrivacyPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notificationPreviewMode => $composableBuilder(
    column: $table.notificationPreviewMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrivacyPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PrivacyPreferencesTable> {
  $$PrivacyPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notificationPreviewMode => $composableBuilder(
    column: $table.notificationPreviewMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrivacyPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrivacyPreferencesTable> {
  $$PrivacyPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<bool> get lockEnabled => $composableBuilder(
    column: $table.lockEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notificationPreviewMode => $composableBuilder(
    column: $table.notificationPreviewMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$PrivacyPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrivacyPreferencesTable,
          PrivacyPreferenceRow,
          $$PrivacyPreferencesTableFilterComposer,
          $$PrivacyPreferencesTableOrderingComposer,
          $$PrivacyPreferencesTableAnnotationComposer,
          $$PrivacyPreferencesTableCreateCompanionBuilder,
          $$PrivacyPreferencesTableUpdateCompanionBuilder,
          (
            PrivacyPreferenceRow,
            BaseReferences<
              _$AppDatabase,
              $PrivacyPreferencesTable,
              PrivacyPreferenceRow
            >,
          ),
          PrivacyPreferenceRow,
          PrefetchHooks Function()
        > {
  $$PrivacyPreferencesTableTableManager(
    _$AppDatabase db,
    $PrivacyPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrivacyPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrivacyPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrivacyPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<bool> lockEnabled = const Value.absent(),
                Value<String> notificationPreviewMode = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrivacyPreferencesCompanion(
                key: key,
                lockEnabled: lockEnabled,
                notificationPreviewMode: notificationPreviewMode,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<bool> lockEnabled = const Value.absent(),
                Value<String> notificationPreviewMode = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PrivacyPreferencesCompanion.insert(
                key: key,
                lockEnabled: lockEnabled,
                notificationPreviewMode: notificationPreviewMode,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrivacyPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrivacyPreferencesTable,
      PrivacyPreferenceRow,
      $$PrivacyPreferencesTableFilterComposer,
      $$PrivacyPreferencesTableOrderingComposer,
      $$PrivacyPreferencesTableAnnotationComposer,
      $$PrivacyPreferencesTableCreateCompanionBuilder,
      $$PrivacyPreferencesTableUpdateCompanionBuilder,
      (
        PrivacyPreferenceRow,
        BaseReferences<
          _$AppDatabase,
          $PrivacyPreferencesTable,
          PrivacyPreferenceRow
        >,
      ),
      PrivacyPreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$PermissionAuditsTableCreateCompanionBuilder =
    PermissionAuditsCompanion Function({
      required String permissionKey,
      Value<bool> requestedByApp,
      Value<bool> everGranted,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PermissionAuditsTableUpdateCompanionBuilder =
    PermissionAuditsCompanion Function({
      Value<String> permissionKey,
      Value<bool> requestedByApp,
      Value<bool> everGranted,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

class $$PermissionAuditsTableFilterComposer
    extends Composer<_$AppDatabase, $PermissionAuditsTable> {
  $$PermissionAuditsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get permissionKey => $composableBuilder(
    column: $table.permissionKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requestedByApp => $composableBuilder(
    column: $table.requestedByApp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get everGranted => $composableBuilder(
    column: $table.everGranted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PermissionAuditsTableOrderingComposer
    extends Composer<_$AppDatabase, $PermissionAuditsTable> {
  $$PermissionAuditsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get permissionKey => $composableBuilder(
    column: $table.permissionKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requestedByApp => $composableBuilder(
    column: $table.requestedByApp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get everGranted => $composableBuilder(
    column: $table.everGranted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PermissionAuditsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PermissionAuditsTable> {
  $$PermissionAuditsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get permissionKey => $composableBuilder(
    column: $table.permissionKey,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requestedByApp => $composableBuilder(
    column: $table.requestedByApp,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get everGranted => $composableBuilder(
    column: $table.everGranted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$PermissionAuditsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PermissionAuditsTable,
          PermissionAuditRow,
          $$PermissionAuditsTableFilterComposer,
          $$PermissionAuditsTableOrderingComposer,
          $$PermissionAuditsTableAnnotationComposer,
          $$PermissionAuditsTableCreateCompanionBuilder,
          $$PermissionAuditsTableUpdateCompanionBuilder,
          (
            PermissionAuditRow,
            BaseReferences<
              _$AppDatabase,
              $PermissionAuditsTable,
              PermissionAuditRow
            >,
          ),
          PermissionAuditRow,
          PrefetchHooks Function()
        > {
  $$PermissionAuditsTableTableManager(
    _$AppDatabase db,
    $PermissionAuditsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PermissionAuditsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PermissionAuditsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PermissionAuditsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> permissionKey = const Value.absent(),
                Value<bool> requestedByApp = const Value.absent(),
                Value<bool> everGranted = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PermissionAuditsCompanion(
                permissionKey: permissionKey,
                requestedByApp: requestedByApp,
                everGranted: everGranted,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String permissionKey,
                Value<bool> requestedByApp = const Value.absent(),
                Value<bool> everGranted = const Value.absent(),
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PermissionAuditsCompanion.insert(
                permissionKey: permissionKey,
                requestedByApp: requestedByApp,
                everGranted: everGranted,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PermissionAuditsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PermissionAuditsTable,
      PermissionAuditRow,
      $$PermissionAuditsTableFilterComposer,
      $$PermissionAuditsTableOrderingComposer,
      $$PermissionAuditsTableAnnotationComposer,
      $$PermissionAuditsTableCreateCompanionBuilder,
      $$PermissionAuditsTableUpdateCompanionBuilder,
      (
        PermissionAuditRow,
        BaseReferences<
          _$AppDatabase,
          $PermissionAuditsTable,
          PermissionAuditRow
        >,
      ),
      PermissionAuditRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalProfilesTableTableManager get localProfiles =>
      $$LocalProfilesTableTableManager(_db, _db.localProfiles);
  $$OnboardingCheckpointsTableTableManager get onboardingCheckpoints =>
      $$OnboardingCheckpointsTableTableManager(_db, _db.onboardingCheckpoints);
  $$LifeIndicatorDefinitionsTableTableManager get lifeIndicatorDefinitions =>
      $$LifeIndicatorDefinitionsTableTableManager(
        _db,
        _db.lifeIndicatorDefinitions,
      );
  $$PrivacyPreferencesTableTableManager get privacyPreferences =>
      $$PrivacyPreferencesTableTableManager(_db, _db.privacyPreferences);
  $$PermissionAuditsTableTableManager get permissionAudits =>
      $$PermissionAuditsTableTableManager(_db, _db.permissionAudits);
}
