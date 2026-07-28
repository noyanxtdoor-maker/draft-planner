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

class $PlannerTasksTable extends PlannerTasks
    with TableInfo<$PlannerTasksTable, PlannerTaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlannerTasksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('incomplete'),
  );
  static const VerificationMeta _requiresReportMeta = const VerificationMeta(
    'requiresReport',
  );
  @override
  late final GeneratedColumn<bool> requiresReport = GeneratedColumn<bool>(
    'requires_report',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_report" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contributionRuleKeyMeta =
      const VerificationMeta('contributionRuleKey');
  @override
  late final GeneratedColumn<String> contributionRuleKey =
      GeneratedColumn<String>(
        'contribution_rule_key',
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
    profileId,
    title,
    notes,
    dueDate,
    status,
    requiresReport,
    contributionRuleKey,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planner_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlannerTaskRow> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('requires_report')) {
      context.handle(
        _requiresReportMeta,
        requiresReport.isAcceptableOrUnknown(
          data['requires_report']!,
          _requiresReportMeta,
        ),
      );
    }
    if (data.containsKey('contribution_rule_key')) {
      context.handle(
        _contributionRuleKeyMeta,
        contributionRuleKey.isAcceptableOrUnknown(
          data['contribution_rule_key']!,
          _contributionRuleKeyMeta,
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
  PlannerTaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlannerTaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requiresReport: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_report'],
      )!,
      contributionRuleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contribution_rule_key'],
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
  $PlannerTasksTable createAlias(String alias) {
    return $PlannerTasksTable(attachedDatabase, alias);
  }
}

class PlannerTaskRow extends DataClass implements Insertable<PlannerTaskRow> {
  final String id;
  final String profileId;
  final String title;
  final String? notes;
  final String? dueDate;
  final String status;
  final bool requiresReport;
  final String? contributionRuleKey;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const PlannerTaskRow({
    required this.id,
    required this.profileId,
    required this.title,
    this.notes,
    this.dueDate,
    required this.status,
    required this.requiresReport,
    this.contributionRuleKey,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<String>(dueDate);
    }
    map['status'] = Variable<String>(status);
    map['requires_report'] = Variable<bool>(requiresReport);
    if (!nullToAbsent || contributionRuleKey != null) {
      map['contribution_rule_key'] = Variable<String>(contributionRuleKey);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  PlannerTasksCompanion toCompanion(bool nullToAbsent) {
    return PlannerTasksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      status: Value(status),
      requiresReport: Value(requiresReport),
      contributionRuleKey: contributionRuleKey == null && nullToAbsent
          ? const Value.absent()
          : Value(contributionRuleKey),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PlannerTaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlannerTaskRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      dueDate: serializer.fromJson<String?>(json['dueDate']),
      status: serializer.fromJson<String>(json['status']),
      requiresReport: serializer.fromJson<bool>(json['requiresReport']),
      contributionRuleKey: serializer.fromJson<String?>(
        json['contributionRuleKey'],
      ),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'dueDate': serializer.toJson<String?>(dueDate),
      'status': serializer.toJson<String>(status),
      'requiresReport': serializer.toJson<bool>(requiresReport),
      'contributionRuleKey': serializer.toJson<String?>(contributionRuleKey),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  PlannerTaskRow copyWith({
    String? id,
    String? profileId,
    String? title,
    Value<String?> notes = const Value.absent(),
    Value<String?> dueDate = const Value.absent(),
    String? status,
    bool? requiresReport,
    Value<String?> contributionRuleKey = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => PlannerTaskRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    status: status ?? this.status,
    requiresReport: requiresReport ?? this.requiresReport,
    contributionRuleKey: contributionRuleKey.present
        ? contributionRuleKey.value
        : this.contributionRuleKey,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PlannerTaskRow copyWithCompanion(PlannerTasksCompanion data) {
    return PlannerTaskRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      status: data.status.present ? data.status.value : this.status,
      requiresReport: data.requiresReport.present
          ? data.requiresReport.value
          : this.requiresReport,
      contributionRuleKey: data.contributionRuleKey.present
          ? data.contributionRuleKey.value
          : this.contributionRuleKey,
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
    return (StringBuffer('PlannerTaskRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('requiresReport: $requiresReport, ')
          ..write('contributionRuleKey: $contributionRuleKey, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    title,
    notes,
    dueDate,
    status,
    requiresReport,
    contributionRuleKey,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlannerTaskRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.dueDate == this.dueDate &&
          other.status == this.status &&
          other.requiresReport == this.requiresReport &&
          other.contributionRuleKey == this.contributionRuleKey &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PlannerTasksCompanion extends UpdateCompanion<PlannerTaskRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<String?> dueDate;
  final Value<String> status;
  final Value<bool> requiresReport;
  final Value<String?> contributionRuleKey;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const PlannerTasksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.requiresReport = const Value.absent(),
    this.contributionRuleKey = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlannerTasksCompanion.insert({
    required String id,
    required String profileId,
    required String title,
    this.notes = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.status = const Value.absent(),
    this.requiresReport = const Value.absent(),
    this.contributionRuleKey = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       title = Value(title),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PlannerTaskRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? dueDate,
    Expression<String>? status,
    Expression<bool>? requiresReport,
    Expression<String>? contributionRuleKey,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate,
      if (status != null) 'status': status,
      if (requiresReport != null) 'requires_report': requiresReport,
      if (contributionRuleKey != null)
        'contribution_rule_key': contributionRuleKey,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlannerTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? title,
    Value<String?>? notes,
    Value<String?>? dueDate,
    Value<String>? status,
    Value<bool>? requiresReport,
    Value<String?>? contributionRuleKey,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PlannerTasksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      requiresReport: requiresReport ?? this.requiresReport,
      contributionRuleKey: contributionRuleKey ?? this.contributionRuleKey,
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
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requiresReport.present) {
      map['requires_report'] = Variable<bool>(requiresReport.value);
    }
    if (contributionRuleKey.present) {
      map['contribution_rule_key'] = Variable<String>(
        contributionRuleKey.value,
      );
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
    return (StringBuffer('PlannerTasksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('dueDate: $dueDate, ')
          ..write('status: $status, ')
          ..write('requiresReport: $requiresReport, ')
          ..write('contributionRuleKey: $contributionRuleKey, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskStatusChangesTable extends TaskStatusChanges
    with TableInfo<$TaskStatusChangesTable, TaskStatusChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskStatusChangesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES planner_tasks (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStatusMeta = const VerificationMeta(
    'fromStatus',
  );
  @override
  late final GeneratedColumn<String> fromStatus = GeneratedColumn<String>(
    'from_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toStatusMeta = const VerificationMeta(
    'toStatus',
  );
  @override
  late final GeneratedColumn<String> toStatus = GeneratedColumn<String>(
    'to_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _changedAtUtcMeta = const VerificationMeta(
    'changedAtUtc',
  );
  @override
  late final GeneratedColumn<DateTime> changedAtUtc = GeneratedColumn<DateTime>(
    'changed_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    taskId,
    operationId,
    fromStatus,
    toStatus,
    reason,
    changedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_status_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskStatusChangeRow> instance, {
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
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('from_status')) {
      context.handle(
        _fromStatusMeta,
        fromStatus.isAcceptableOrUnknown(data['from_status']!, _fromStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_fromStatusMeta);
    }
    if (data.containsKey('to_status')) {
      context.handle(
        _toStatusMeta,
        toStatus.isAcceptableOrUnknown(data['to_status']!, _toStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_toStatusMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    if (data.containsKey('changed_at_utc')) {
      context.handle(
        _changedAtUtcMeta,
        changedAtUtc.isAcceptableOrUnknown(
          data['changed_at_utc']!,
          _changedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_changedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskStatusChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskStatusChangeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      fromStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_status'],
      )!,
      toStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_status'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
      changedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at_utc'],
      )!,
    );
  }

  @override
  $TaskStatusChangesTable createAlias(String alias) {
    return $TaskStatusChangesTable(attachedDatabase, alias);
  }
}

class TaskStatusChangeRow extends DataClass
    implements Insertable<TaskStatusChangeRow> {
  final String id;
  final String profileId;
  final String taskId;
  final String operationId;
  final String fromStatus;
  final String toStatus;
  final String? reason;
  final DateTime changedAtUtc;
  const TaskStatusChangeRow({
    required this.id,
    required this.profileId,
    required this.taskId,
    required this.operationId,
    required this.fromStatus,
    required this.toStatus,
    this.reason,
    required this.changedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['task_id'] = Variable<String>(taskId);
    map['operation_id'] = Variable<String>(operationId);
    map['from_status'] = Variable<String>(fromStatus);
    map['to_status'] = Variable<String>(toStatus);
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    map['changed_at_utc'] = Variable<DateTime>(changedAtUtc);
    return map;
  }

  TaskStatusChangesCompanion toCompanion(bool nullToAbsent) {
    return TaskStatusChangesCompanion(
      id: Value(id),
      profileId: Value(profileId),
      taskId: Value(taskId),
      operationId: Value(operationId),
      fromStatus: Value(fromStatus),
      toStatus: Value(toStatus),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
      changedAtUtc: Value(changedAtUtc),
    );
  }

  factory TaskStatusChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskStatusChangeRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      fromStatus: serializer.fromJson<String>(json['fromStatus']),
      toStatus: serializer.fromJson<String>(json['toStatus']),
      reason: serializer.fromJson<String?>(json['reason']),
      changedAtUtc: serializer.fromJson<DateTime>(json['changedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'taskId': serializer.toJson<String>(taskId),
      'operationId': serializer.toJson<String>(operationId),
      'fromStatus': serializer.toJson<String>(fromStatus),
      'toStatus': serializer.toJson<String>(toStatus),
      'reason': serializer.toJson<String?>(reason),
      'changedAtUtc': serializer.toJson<DateTime>(changedAtUtc),
    };
  }

  TaskStatusChangeRow copyWith({
    String? id,
    String? profileId,
    String? taskId,
    String? operationId,
    String? fromStatus,
    String? toStatus,
    Value<String?> reason = const Value.absent(),
    DateTime? changedAtUtc,
  }) => TaskStatusChangeRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    taskId: taskId ?? this.taskId,
    operationId: operationId ?? this.operationId,
    fromStatus: fromStatus ?? this.fromStatus,
    toStatus: toStatus ?? this.toStatus,
    reason: reason.present ? reason.value : this.reason,
    changedAtUtc: changedAtUtc ?? this.changedAtUtc,
  );
  TaskStatusChangeRow copyWithCompanion(TaskStatusChangesCompanion data) {
    return TaskStatusChangeRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      fromStatus: data.fromStatus.present
          ? data.fromStatus.value
          : this.fromStatus,
      toStatus: data.toStatus.present ? data.toStatus.value : this.toStatus,
      reason: data.reason.present ? data.reason.value : this.reason,
      changedAtUtc: data.changedAtUtc.present
          ? data.changedAtUtc.value
          : this.changedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskStatusChangeRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('taskId: $taskId, ')
          ..write('operationId: $operationId, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('reason: $reason, ')
          ..write('changedAtUtc: $changedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    taskId,
    operationId,
    fromStatus,
    toStatus,
    reason,
    changedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskStatusChangeRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.taskId == this.taskId &&
          other.operationId == this.operationId &&
          other.fromStatus == this.fromStatus &&
          other.toStatus == this.toStatus &&
          other.reason == this.reason &&
          other.changedAtUtc == this.changedAtUtc);
}

class TaskStatusChangesCompanion extends UpdateCompanion<TaskStatusChangeRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> taskId;
  final Value<String> operationId;
  final Value<String> fromStatus;
  final Value<String> toStatus;
  final Value<String?> reason;
  final Value<DateTime> changedAtUtc;
  final Value<int> rowid;
  const TaskStatusChangesCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.fromStatus = const Value.absent(),
    this.toStatus = const Value.absent(),
    this.reason = const Value.absent(),
    this.changedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskStatusChangesCompanion.insert({
    required String id,
    required String profileId,
    required String taskId,
    required String operationId,
    required String fromStatus,
    required String toStatus,
    this.reason = const Value.absent(),
    required DateTime changedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       taskId = Value(taskId),
       operationId = Value(operationId),
       fromStatus = Value(fromStatus),
       toStatus = Value(toStatus),
       changedAtUtc = Value(changedAtUtc);
  static Insertable<TaskStatusChangeRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? taskId,
    Expression<String>? operationId,
    Expression<String>? fromStatus,
    Expression<String>? toStatus,
    Expression<String>? reason,
    Expression<DateTime>? changedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (taskId != null) 'task_id': taskId,
      if (operationId != null) 'operation_id': operationId,
      if (fromStatus != null) 'from_status': fromStatus,
      if (toStatus != null) 'to_status': toStatus,
      if (reason != null) 'reason': reason,
      if (changedAtUtc != null) 'changed_at_utc': changedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskStatusChangesCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? taskId,
    Value<String>? operationId,
    Value<String>? fromStatus,
    Value<String>? toStatus,
    Value<String?>? reason,
    Value<DateTime>? changedAtUtc,
    Value<int>? rowid,
  }) {
    return TaskStatusChangesCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      taskId: taskId ?? this.taskId,
      operationId: operationId ?? this.operationId,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      reason: reason ?? this.reason,
      changedAtUtc: changedAtUtc ?? this.changedAtUtc,
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
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (fromStatus.present) {
      map['from_status'] = Variable<String>(fromStatus.value);
    }
    if (toStatus.present) {
      map['to_status'] = Variable<String>(toStatus.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (changedAtUtc.present) {
      map['changed_at_utc'] = Variable<DateTime>(changedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskStatusChangesCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('taskId: $taskId, ')
          ..write('operationId: $operationId, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('reason: $reason, ')
          ..write('changedAtUtc: $changedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventsTable extends CalendarEvents
    with TableInfo<$CalendarEventsTable, CalendarEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timingMeta = const VerificationMeta('timing');
  @override
  late final GeneratedColumn<String> timing = GeneratedColumn<String>(
    'timing',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationTextMeta = const VerificationMeta(
    'locationText',
  );
  @override
  late final GeneratedColumn<String> locationText = GeneratedColumn<String>(
    'location_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresReportMeta = const VerificationMeta(
    'requiresReport',
  );
  @override
  late final GeneratedColumn<bool> requiresReport = GeneratedColumn<bool>(
    'requires_report',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_report" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contributionRuleKeyMeta =
      const VerificationMeta('contributionRuleKey');
  @override
  late final GeneratedColumn<String> contributionRuleKey =
      GeneratedColumn<String>(
        'contribution_rule_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceFrequencyMeta =
      const VerificationMeta('recurrenceFrequency');
  @override
  late final GeneratedColumn<String> recurrenceFrequency =
      GeneratedColumn<String>(
        'recurrence_frequency',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  static const VerificationMeta _recurrenceEndModeMeta = const VerificationMeta(
    'recurrenceEndMode',
  );
  @override
  late final GeneratedColumn<String> recurrenceEndMode =
      GeneratedColumn<String>(
        'recurrence_end_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('never'),
      );
  static const VerificationMeta _recurrenceEndDateMeta = const VerificationMeta(
    'recurrenceEndDate',
  );
  @override
  late final GeneratedColumn<String> recurrenceEndDate =
      GeneratedColumn<String>(
        'recurrence_end_date',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _recurrenceCountMeta = const VerificationMeta(
    'recurrenceCount',
  );
  @override
  late final GeneratedColumn<int> recurrenceCount = GeneratedColumn<int>(
    'recurrence_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('scheduled'),
  );
  static const VerificationMeta _parentEventIdMeta = const VerificationMeta(
    'parentEventId',
  );
  @override
  late final GeneratedColumn<String> parentEventId = GeneratedColumn<String>(
    'parent_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replacementEventIdMeta =
      const VerificationMeta('replacementEventId');
  @override
  late final GeneratedColumn<String> replacementEventId =
      GeneratedColumn<String>(
        'replacement_event_id',
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
    profileId,
    title,
    notes,
    timing,
    startDate,
    startMinute,
    endMinute,
    timeZoneId,
    locationText,
    requiresReport,
    contributionRuleKey,
    recurrenceFrequency,
    recurrenceEndMode,
    recurrenceEndDate,
    recurrenceCount,
    status,
    parentEventId,
    replacementEventId,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEventRow> instance, {
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('timing')) {
      context.handle(
        _timingMeta,
        timing.isAcceptableOrUnknown(data['timing']!, _timingMeta),
      );
    } else if (isInserting) {
      context.missing(_timingMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('location_text')) {
      context.handle(
        _locationTextMeta,
        locationText.isAcceptableOrUnknown(
          data['location_text']!,
          _locationTextMeta,
        ),
      );
    }
    if (data.containsKey('requires_report')) {
      context.handle(
        _requiresReportMeta,
        requiresReport.isAcceptableOrUnknown(
          data['requires_report']!,
          _requiresReportMeta,
        ),
      );
    }
    if (data.containsKey('contribution_rule_key')) {
      context.handle(
        _contributionRuleKeyMeta,
        contributionRuleKey.isAcceptableOrUnknown(
          data['contribution_rule_key']!,
          _contributionRuleKeyMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_frequency')) {
      context.handle(
        _recurrenceFrequencyMeta,
        recurrenceFrequency.isAcceptableOrUnknown(
          data['recurrence_frequency']!,
          _recurrenceFrequencyMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_end_mode')) {
      context.handle(
        _recurrenceEndModeMeta,
        recurrenceEndMode.isAcceptableOrUnknown(
          data['recurrence_end_mode']!,
          _recurrenceEndModeMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_end_date')) {
      context.handle(
        _recurrenceEndDateMeta,
        recurrenceEndDate.isAcceptableOrUnknown(
          data['recurrence_end_date']!,
          _recurrenceEndDateMeta,
        ),
      );
    }
    if (data.containsKey('recurrence_count')) {
      context.handle(
        _recurrenceCountMeta,
        recurrenceCount.isAcceptableOrUnknown(
          data['recurrence_count']!,
          _recurrenceCountMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('parent_event_id')) {
      context.handle(
        _parentEventIdMeta,
        parentEventId.isAcceptableOrUnknown(
          data['parent_event_id']!,
          _parentEventIdMeta,
        ),
      );
    }
    if (data.containsKey('replacement_event_id')) {
      context.handle(
        _replacementEventIdMeta,
        replacementEventId.isAcceptableOrUnknown(
          data['replacement_event_id']!,
          _replacementEventIdMeta,
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
  CalendarEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      timing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timing'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      ),
      locationText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_text'],
      ),
      requiresReport: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_report'],
      )!,
      contributionRuleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contribution_rule_key'],
      ),
      recurrenceFrequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_frequency'],
      )!,
      recurrenceEndMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_end_mode'],
      )!,
      recurrenceEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_end_date'],
      ),
      recurrenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recurrence_count'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      parentEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_event_id'],
      ),
      replacementEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_event_id'],
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
  $CalendarEventsTable createAlias(String alias) {
    return $CalendarEventsTable(attachedDatabase, alias);
  }
}

class CalendarEventRow extends DataClass
    implements Insertable<CalendarEventRow> {
  final String id;
  final String profileId;
  final String title;
  final String? notes;
  final String timing;
  final String startDate;
  final int? startMinute;
  final int? endMinute;
  final String? timeZoneId;
  final String? locationText;
  final bool requiresReport;
  final String? contributionRuleKey;
  final String recurrenceFrequency;
  final String recurrenceEndMode;
  final String? recurrenceEndDate;
  final int? recurrenceCount;
  final String status;
  final String? parentEventId;
  final String? replacementEventId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const CalendarEventRow({
    required this.id,
    required this.profileId,
    required this.title,
    this.notes,
    required this.timing,
    required this.startDate,
    this.startMinute,
    this.endMinute,
    this.timeZoneId,
    this.locationText,
    required this.requiresReport,
    this.contributionRuleKey,
    required this.recurrenceFrequency,
    required this.recurrenceEndMode,
    this.recurrenceEndDate,
    this.recurrenceCount,
    required this.status,
    this.parentEventId,
    this.replacementEventId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['timing'] = Variable<String>(timing);
    map['start_date'] = Variable<String>(startDate);
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    if (!nullToAbsent || timeZoneId != null) {
      map['time_zone_id'] = Variable<String>(timeZoneId);
    }
    if (!nullToAbsent || locationText != null) {
      map['location_text'] = Variable<String>(locationText);
    }
    map['requires_report'] = Variable<bool>(requiresReport);
    if (!nullToAbsent || contributionRuleKey != null) {
      map['contribution_rule_key'] = Variable<String>(contributionRuleKey);
    }
    map['recurrence_frequency'] = Variable<String>(recurrenceFrequency);
    map['recurrence_end_mode'] = Variable<String>(recurrenceEndMode);
    if (!nullToAbsent || recurrenceEndDate != null) {
      map['recurrence_end_date'] = Variable<String>(recurrenceEndDate);
    }
    if (!nullToAbsent || recurrenceCount != null) {
      map['recurrence_count'] = Variable<int>(recurrenceCount);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || parentEventId != null) {
      map['parent_event_id'] = Variable<String>(parentEventId);
    }
    if (!nullToAbsent || replacementEventId != null) {
      map['replacement_event_id'] = Variable<String>(replacementEventId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  CalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      timing: Value(timing),
      startDate: Value(startDate),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      timeZoneId: timeZoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZoneId),
      locationText: locationText == null && nullToAbsent
          ? const Value.absent()
          : Value(locationText),
      requiresReport: Value(requiresReport),
      contributionRuleKey: contributionRuleKey == null && nullToAbsent
          ? const Value.absent()
          : Value(contributionRuleKey),
      recurrenceFrequency: Value(recurrenceFrequency),
      recurrenceEndMode: Value(recurrenceEndMode),
      recurrenceEndDate: recurrenceEndDate == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceEndDate),
      recurrenceCount: recurrenceCount == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceCount),
      status: Value(status),
      parentEventId: parentEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentEventId),
      replacementEventId: replacementEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacementEventId),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory CalendarEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      timing: serializer.fromJson<String>(json['timing']),
      startDate: serializer.fromJson<String>(json['startDate']),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      timeZoneId: serializer.fromJson<String?>(json['timeZoneId']),
      locationText: serializer.fromJson<String?>(json['locationText']),
      requiresReport: serializer.fromJson<bool>(json['requiresReport']),
      contributionRuleKey: serializer.fromJson<String?>(
        json['contributionRuleKey'],
      ),
      recurrenceFrequency: serializer.fromJson<String>(
        json['recurrenceFrequency'],
      ),
      recurrenceEndMode: serializer.fromJson<String>(json['recurrenceEndMode']),
      recurrenceEndDate: serializer.fromJson<String?>(
        json['recurrenceEndDate'],
      ),
      recurrenceCount: serializer.fromJson<int?>(json['recurrenceCount']),
      status: serializer.fromJson<String>(json['status']),
      parentEventId: serializer.fromJson<String?>(json['parentEventId']),
      replacementEventId: serializer.fromJson<String?>(
        json['replacementEventId'],
      ),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'timing': serializer.toJson<String>(timing),
      'startDate': serializer.toJson<String>(startDate),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endMinute': serializer.toJson<int?>(endMinute),
      'timeZoneId': serializer.toJson<String?>(timeZoneId),
      'locationText': serializer.toJson<String?>(locationText),
      'requiresReport': serializer.toJson<bool>(requiresReport),
      'contributionRuleKey': serializer.toJson<String?>(contributionRuleKey),
      'recurrenceFrequency': serializer.toJson<String>(recurrenceFrequency),
      'recurrenceEndMode': serializer.toJson<String>(recurrenceEndMode),
      'recurrenceEndDate': serializer.toJson<String?>(recurrenceEndDate),
      'recurrenceCount': serializer.toJson<int?>(recurrenceCount),
      'status': serializer.toJson<String>(status),
      'parentEventId': serializer.toJson<String?>(parentEventId),
      'replacementEventId': serializer.toJson<String?>(replacementEventId),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  CalendarEventRow copyWith({
    String? id,
    String? profileId,
    String? title,
    Value<String?> notes = const Value.absent(),
    String? timing,
    String? startDate,
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<String?> timeZoneId = const Value.absent(),
    Value<String?> locationText = const Value.absent(),
    bool? requiresReport,
    Value<String?> contributionRuleKey = const Value.absent(),
    String? recurrenceFrequency,
    String? recurrenceEndMode,
    Value<String?> recurrenceEndDate = const Value.absent(),
    Value<int?> recurrenceCount = const Value.absent(),
    String? status,
    Value<String?> parentEventId = const Value.absent(),
    Value<String?> replacementEventId = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => CalendarEventRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    timing: timing ?? this.timing,
    startDate: startDate ?? this.startDate,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    timeZoneId: timeZoneId.present ? timeZoneId.value : this.timeZoneId,
    locationText: locationText.present ? locationText.value : this.locationText,
    requiresReport: requiresReport ?? this.requiresReport,
    contributionRuleKey: contributionRuleKey.present
        ? contributionRuleKey.value
        : this.contributionRuleKey,
    recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
    recurrenceEndMode: recurrenceEndMode ?? this.recurrenceEndMode,
    recurrenceEndDate: recurrenceEndDate.present
        ? recurrenceEndDate.value
        : this.recurrenceEndDate,
    recurrenceCount: recurrenceCount.present
        ? recurrenceCount.value
        : this.recurrenceCount,
    status: status ?? this.status,
    parentEventId: parentEventId.present
        ? parentEventId.value
        : this.parentEventId,
    replacementEventId: replacementEventId.present
        ? replacementEventId.value
        : this.replacementEventId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  CalendarEventRow copyWithCompanion(CalendarEventsCompanion data) {
    return CalendarEventRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      timing: data.timing.present ? data.timing.value : this.timing,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      locationText: data.locationText.present
          ? data.locationText.value
          : this.locationText,
      requiresReport: data.requiresReport.present
          ? data.requiresReport.value
          : this.requiresReport,
      contributionRuleKey: data.contributionRuleKey.present
          ? data.contributionRuleKey.value
          : this.contributionRuleKey,
      recurrenceFrequency: data.recurrenceFrequency.present
          ? data.recurrenceFrequency.value
          : this.recurrenceFrequency,
      recurrenceEndMode: data.recurrenceEndMode.present
          ? data.recurrenceEndMode.value
          : this.recurrenceEndMode,
      recurrenceEndDate: data.recurrenceEndDate.present
          ? data.recurrenceEndDate.value
          : this.recurrenceEndDate,
      recurrenceCount: data.recurrenceCount.present
          ? data.recurrenceCount.value
          : this.recurrenceCount,
      status: data.status.present ? data.status.value : this.status,
      parentEventId: data.parentEventId.present
          ? data.parentEventId.value
          : this.parentEventId,
      replacementEventId: data.replacementEventId.present
          ? data.replacementEventId.value
          : this.replacementEventId,
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
    return (StringBuffer('CalendarEventRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('startDate: $startDate, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('locationText: $locationText, ')
          ..write('requiresReport: $requiresReport, ')
          ..write('contributionRuleKey: $contributionRuleKey, ')
          ..write('recurrenceFrequency: $recurrenceFrequency, ')
          ..write('recurrenceEndMode: $recurrenceEndMode, ')
          ..write('recurrenceEndDate: $recurrenceEndDate, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('status: $status, ')
          ..write('parentEventId: $parentEventId, ')
          ..write('replacementEventId: $replacementEventId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    profileId,
    title,
    notes,
    timing,
    startDate,
    startMinute,
    endMinute,
    timeZoneId,
    locationText,
    requiresReport,
    contributionRuleKey,
    recurrenceFrequency,
    recurrenceEndMode,
    recurrenceEndDate,
    recurrenceCount,
    status,
    parentEventId,
    replacementEventId,
    createdAtUtc,
    updatedAtUtc,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.timing == this.timing &&
          other.startDate == this.startDate &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.timeZoneId == this.timeZoneId &&
          other.locationText == this.locationText &&
          other.requiresReport == this.requiresReport &&
          other.contributionRuleKey == this.contributionRuleKey &&
          other.recurrenceFrequency == this.recurrenceFrequency &&
          other.recurrenceEndMode == this.recurrenceEndMode &&
          other.recurrenceEndDate == this.recurrenceEndDate &&
          other.recurrenceCount == this.recurrenceCount &&
          other.status == this.status &&
          other.parentEventId == this.parentEventId &&
          other.replacementEventId == this.replacementEventId &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class CalendarEventsCompanion extends UpdateCompanion<CalendarEventRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> title;
  final Value<String?> notes;
  final Value<String> timing;
  final Value<String> startDate;
  final Value<int?> startMinute;
  final Value<int?> endMinute;
  final Value<String?> timeZoneId;
  final Value<String?> locationText;
  final Value<bool> requiresReport;
  final Value<String?> contributionRuleKey;
  final Value<String> recurrenceFrequency;
  final Value<String> recurrenceEndMode;
  final Value<String?> recurrenceEndDate;
  final Value<int?> recurrenceCount;
  final Value<String> status;
  final Value<String?> parentEventId;
  final Value<String?> replacementEventId;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const CalendarEventsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.timing = const Value.absent(),
    this.startDate = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.locationText = const Value.absent(),
    this.requiresReport = const Value.absent(),
    this.contributionRuleKey = const Value.absent(),
    this.recurrenceFrequency = const Value.absent(),
    this.recurrenceEndMode = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.status = const Value.absent(),
    this.parentEventId = const Value.absent(),
    this.replacementEventId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventsCompanion.insert({
    required String id,
    required String profileId,
    required String title,
    this.notes = const Value.absent(),
    required String timing,
    required String startDate,
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.locationText = const Value.absent(),
    this.requiresReport = const Value.absent(),
    this.contributionRuleKey = const Value.absent(),
    this.recurrenceFrequency = const Value.absent(),
    this.recurrenceEndMode = const Value.absent(),
    this.recurrenceEndDate = const Value.absent(),
    this.recurrenceCount = const Value.absent(),
    this.status = const Value.absent(),
    this.parentEventId = const Value.absent(),
    this.replacementEventId = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       title = Value(title),
       timing = Value(timing),
       startDate = Value(startDate),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<CalendarEventRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? timing,
    Expression<String>? startDate,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<String>? timeZoneId,
    Expression<String>? locationText,
    Expression<bool>? requiresReport,
    Expression<String>? contributionRuleKey,
    Expression<String>? recurrenceFrequency,
    Expression<String>? recurrenceEndMode,
    Expression<String>? recurrenceEndDate,
    Expression<int>? recurrenceCount,
    Expression<String>? status,
    Expression<String>? parentEventId,
    Expression<String>? replacementEventId,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (timing != null) 'timing': timing,
      if (startDate != null) 'start_date': startDate,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (locationText != null) 'location_text': locationText,
      if (requiresReport != null) 'requires_report': requiresReport,
      if (contributionRuleKey != null)
        'contribution_rule_key': contributionRuleKey,
      if (recurrenceFrequency != null)
        'recurrence_frequency': recurrenceFrequency,
      if (recurrenceEndMode != null) 'recurrence_end_mode': recurrenceEndMode,
      if (recurrenceEndDate != null) 'recurrence_end_date': recurrenceEndDate,
      if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
      if (status != null) 'status': status,
      if (parentEventId != null) 'parent_event_id': parentEventId,
      if (replacementEventId != null)
        'replacement_event_id': replacementEventId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? title,
    Value<String?>? notes,
    Value<String>? timing,
    Value<String>? startDate,
    Value<int?>? startMinute,
    Value<int?>? endMinute,
    Value<String?>? timeZoneId,
    Value<String?>? locationText,
    Value<bool>? requiresReport,
    Value<String?>? contributionRuleKey,
    Value<String>? recurrenceFrequency,
    Value<String>? recurrenceEndMode,
    Value<String?>? recurrenceEndDate,
    Value<int?>? recurrenceCount,
    Value<String>? status,
    Value<String?>? parentEventId,
    Value<String?>? replacementEventId,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return CalendarEventsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      timing: timing ?? this.timing,
      startDate: startDate ?? this.startDate,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      locationText: locationText ?? this.locationText,
      requiresReport: requiresReport ?? this.requiresReport,
      contributionRuleKey: contributionRuleKey ?? this.contributionRuleKey,
      recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
      recurrenceEndMode: recurrenceEndMode ?? this.recurrenceEndMode,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      status: status ?? this.status,
      parentEventId: parentEventId ?? this.parentEventId,
      replacementEventId: replacementEventId ?? this.replacementEventId,
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
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (timing.present) {
      map['timing'] = Variable<String>(timing.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (locationText.present) {
      map['location_text'] = Variable<String>(locationText.value);
    }
    if (requiresReport.present) {
      map['requires_report'] = Variable<bool>(requiresReport.value);
    }
    if (contributionRuleKey.present) {
      map['contribution_rule_key'] = Variable<String>(
        contributionRuleKey.value,
      );
    }
    if (recurrenceFrequency.present) {
      map['recurrence_frequency'] = Variable<String>(recurrenceFrequency.value);
    }
    if (recurrenceEndMode.present) {
      map['recurrence_end_mode'] = Variable<String>(recurrenceEndMode.value);
    }
    if (recurrenceEndDate.present) {
      map['recurrence_end_date'] = Variable<String>(recurrenceEndDate.value);
    }
    if (recurrenceCount.present) {
      map['recurrence_count'] = Variable<int>(recurrenceCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (parentEventId.present) {
      map['parent_event_id'] = Variable<String>(parentEventId.value);
    }
    if (replacementEventId.present) {
      map['replacement_event_id'] = Variable<String>(replacementEventId.value);
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
    return (StringBuffer('CalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('startDate: $startDate, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('locationText: $locationText, ')
          ..write('requiresReport: $requiresReport, ')
          ..write('contributionRuleKey: $contributionRuleKey, ')
          ..write('recurrenceFrequency: $recurrenceFrequency, ')
          ..write('recurrenceEndMode: $recurrenceEndMode, ')
          ..write('recurrenceEndDate: $recurrenceEndDate, ')
          ..write('recurrenceCount: $recurrenceCount, ')
          ..write('status: $status, ')
          ..write('parentEventId: $parentEventId, ')
          ..write('replacementEventId: $replacementEventId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventExceptionsTable extends CalendarEventExceptions
    with TableInfo<$CalendarEventExceptionsTable, CalendarEventExceptionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventExceptionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calendar_events (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _occurrenceIdMeta = const VerificationMeta(
    'occurrenceId',
  );
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
    'occurrence_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalDateMeta = const VerificationMeta(
    'originalDate',
  );
  @override
  late final GeneratedColumn<String> originalDate = GeneratedColumn<String>(
    'original_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveDateMeta = const VerificationMeta(
    'effectiveDate',
  );
  @override
  late final GeneratedColumn<String> effectiveDate = GeneratedColumn<String>(
    'effective_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timingMeta = const VerificationMeta('timing');
  @override
  late final GeneratedColumn<String> timing = GeneratedColumn<String>(
    'timing',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMinuteMeta = const VerificationMeta(
    'startMinute',
  );
  @override
  late final GeneratedColumn<int> startMinute = GeneratedColumn<int>(
    'start_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endMinuteMeta = const VerificationMeta(
    'endMinute',
  );
  @override
  late final GeneratedColumn<int> endMinute = GeneratedColumn<int>(
    'end_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeZoneIdMeta = const VerificationMeta(
    'timeZoneId',
  );
  @override
  late final GeneratedColumn<String> timeZoneId = GeneratedColumn<String>(
    'time_zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationTextMeta = const VerificationMeta(
    'locationText',
  );
  @override
  late final GeneratedColumn<String> locationText = GeneratedColumn<String>(
    'location_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiresReportMeta = const VerificationMeta(
    'requiresReport',
  );
  @override
  late final GeneratedColumn<bool> requiresReport = GeneratedColumn<bool>(
    'requires_report',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("requires_report" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contributionRuleKeyMeta =
      const VerificationMeta('contributionRuleKey');
  @override
  late final GeneratedColumn<String> contributionRuleKey =
      GeneratedColumn<String>(
        'contribution_rule_key',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _replacementEventIdMeta =
      const VerificationMeta('replacementEventId');
  @override
  late final GeneratedColumn<String> replacementEventId =
      GeneratedColumn<String>(
        'replacement_event_id',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    eventId,
    occurrenceId,
    originalDate,
    effectiveDate,
    title,
    notes,
    timing,
    startMinute,
    endMinute,
    timeZoneId,
    locationText,
    requiresReport,
    contributionRuleKey,
    status,
    replacementEventId,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_event_exceptions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEventExceptionRow> instance, {
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
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
        _occurrenceIdMeta,
        occurrenceId.isAcceptableOrUnknown(
          data['occurrence_id']!,
          _occurrenceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurrenceIdMeta);
    }
    if (data.containsKey('original_date')) {
      context.handle(
        _originalDateMeta,
        originalDate.isAcceptableOrUnknown(
          data['original_date']!,
          _originalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalDateMeta);
    }
    if (data.containsKey('effective_date')) {
      context.handle(
        _effectiveDateMeta,
        effectiveDate.isAcceptableOrUnknown(
          data['effective_date']!,
          _effectiveDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveDateMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('timing')) {
      context.handle(
        _timingMeta,
        timing.isAcceptableOrUnknown(data['timing']!, _timingMeta),
      );
    } else if (isInserting) {
      context.missing(_timingMeta);
    }
    if (data.containsKey('start_minute')) {
      context.handle(
        _startMinuteMeta,
        startMinute.isAcceptableOrUnknown(
          data['start_minute']!,
          _startMinuteMeta,
        ),
      );
    }
    if (data.containsKey('end_minute')) {
      context.handle(
        _endMinuteMeta,
        endMinute.isAcceptableOrUnknown(data['end_minute']!, _endMinuteMeta),
      );
    }
    if (data.containsKey('time_zone_id')) {
      context.handle(
        _timeZoneIdMeta,
        timeZoneId.isAcceptableOrUnknown(
          data['time_zone_id']!,
          _timeZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('location_text')) {
      context.handle(
        _locationTextMeta,
        locationText.isAcceptableOrUnknown(
          data['location_text']!,
          _locationTextMeta,
        ),
      );
    }
    if (data.containsKey('requires_report')) {
      context.handle(
        _requiresReportMeta,
        requiresReport.isAcceptableOrUnknown(
          data['requires_report']!,
          _requiresReportMeta,
        ),
      );
    }
    if (data.containsKey('contribution_rule_key')) {
      context.handle(
        _contributionRuleKeyMeta,
        contributionRuleKey.isAcceptableOrUnknown(
          data['contribution_rule_key']!,
          _contributionRuleKeyMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('replacement_event_id')) {
      context.handle(
        _replacementEventIdMeta,
        replacementEventId.isAcceptableOrUnknown(
          data['replacement_event_id']!,
          _replacementEventIdMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEventExceptionRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventExceptionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      occurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_id'],
      )!,
      originalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_date'],
      )!,
      effectiveDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_date'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      timing: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timing'],
      )!,
      startMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_minute'],
      ),
      endMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_minute'],
      ),
      timeZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_zone_id'],
      ),
      locationText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_text'],
      ),
      requiresReport: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_report'],
      )!,
      contributionRuleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contribution_rule_key'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      replacementEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}replacement_event_id'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $CalendarEventExceptionsTable createAlias(String alias) {
    return $CalendarEventExceptionsTable(attachedDatabase, alias);
  }
}

class CalendarEventExceptionRow extends DataClass
    implements Insertable<CalendarEventExceptionRow> {
  final String id;
  final String profileId;
  final String eventId;
  final String occurrenceId;
  final String originalDate;
  final String effectiveDate;
  final String title;
  final String? notes;
  final String timing;
  final int? startMinute;
  final int? endMinute;
  final String? timeZoneId;
  final String? locationText;
  final bool requiresReport;
  final String? contributionRuleKey;
  final String status;
  final String? replacementEventId;
  final DateTime createdAtUtc;
  const CalendarEventExceptionRow({
    required this.id,
    required this.profileId,
    required this.eventId,
    required this.occurrenceId,
    required this.originalDate,
    required this.effectiveDate,
    required this.title,
    this.notes,
    required this.timing,
    this.startMinute,
    this.endMinute,
    this.timeZoneId,
    this.locationText,
    required this.requiresReport,
    this.contributionRuleKey,
    required this.status,
    this.replacementEventId,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['event_id'] = Variable<String>(eventId);
    map['occurrence_id'] = Variable<String>(occurrenceId);
    map['original_date'] = Variable<String>(originalDate);
    map['effective_date'] = Variable<String>(effectiveDate);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['timing'] = Variable<String>(timing);
    if (!nullToAbsent || startMinute != null) {
      map['start_minute'] = Variable<int>(startMinute);
    }
    if (!nullToAbsent || endMinute != null) {
      map['end_minute'] = Variable<int>(endMinute);
    }
    if (!nullToAbsent || timeZoneId != null) {
      map['time_zone_id'] = Variable<String>(timeZoneId);
    }
    if (!nullToAbsent || locationText != null) {
      map['location_text'] = Variable<String>(locationText);
    }
    map['requires_report'] = Variable<bool>(requiresReport);
    if (!nullToAbsent || contributionRuleKey != null) {
      map['contribution_rule_key'] = Variable<String>(contributionRuleKey);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || replacementEventId != null) {
      map['replacement_event_id'] = Variable<String>(replacementEventId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  CalendarEventExceptionsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventExceptionsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      eventId: Value(eventId),
      occurrenceId: Value(occurrenceId),
      originalDate: Value(originalDate),
      effectiveDate: Value(effectiveDate),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      timing: Value(timing),
      startMinute: startMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(startMinute),
      endMinute: endMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(endMinute),
      timeZoneId: timeZoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(timeZoneId),
      locationText: locationText == null && nullToAbsent
          ? const Value.absent()
          : Value(locationText),
      requiresReport: Value(requiresReport),
      contributionRuleKey: contributionRuleKey == null && nullToAbsent
          ? const Value.absent()
          : Value(contributionRuleKey),
      status: Value(status),
      replacementEventId: replacementEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(replacementEventId),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory CalendarEventExceptionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventExceptionRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      occurrenceId: serializer.fromJson<String>(json['occurrenceId']),
      originalDate: serializer.fromJson<String>(json['originalDate']),
      effectiveDate: serializer.fromJson<String>(json['effectiveDate']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      timing: serializer.fromJson<String>(json['timing']),
      startMinute: serializer.fromJson<int?>(json['startMinute']),
      endMinute: serializer.fromJson<int?>(json['endMinute']),
      timeZoneId: serializer.fromJson<String?>(json['timeZoneId']),
      locationText: serializer.fromJson<String?>(json['locationText']),
      requiresReport: serializer.fromJson<bool>(json['requiresReport']),
      contributionRuleKey: serializer.fromJson<String?>(
        json['contributionRuleKey'],
      ),
      status: serializer.fromJson<String>(json['status']),
      replacementEventId: serializer.fromJson<String?>(
        json['replacementEventId'],
      ),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'eventId': serializer.toJson<String>(eventId),
      'occurrenceId': serializer.toJson<String>(occurrenceId),
      'originalDate': serializer.toJson<String>(originalDate),
      'effectiveDate': serializer.toJson<String>(effectiveDate),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'timing': serializer.toJson<String>(timing),
      'startMinute': serializer.toJson<int?>(startMinute),
      'endMinute': serializer.toJson<int?>(endMinute),
      'timeZoneId': serializer.toJson<String?>(timeZoneId),
      'locationText': serializer.toJson<String?>(locationText),
      'requiresReport': serializer.toJson<bool>(requiresReport),
      'contributionRuleKey': serializer.toJson<String?>(contributionRuleKey),
      'status': serializer.toJson<String>(status),
      'replacementEventId': serializer.toJson<String?>(replacementEventId),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  CalendarEventExceptionRow copyWith({
    String? id,
    String? profileId,
    String? eventId,
    String? occurrenceId,
    String? originalDate,
    String? effectiveDate,
    String? title,
    Value<String?> notes = const Value.absent(),
    String? timing,
    Value<int?> startMinute = const Value.absent(),
    Value<int?> endMinute = const Value.absent(),
    Value<String?> timeZoneId = const Value.absent(),
    Value<String?> locationText = const Value.absent(),
    bool? requiresReport,
    Value<String?> contributionRuleKey = const Value.absent(),
    String? status,
    Value<String?> replacementEventId = const Value.absent(),
    DateTime? createdAtUtc,
  }) => CalendarEventExceptionRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    eventId: eventId ?? this.eventId,
    occurrenceId: occurrenceId ?? this.occurrenceId,
    originalDate: originalDate ?? this.originalDate,
    effectiveDate: effectiveDate ?? this.effectiveDate,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    timing: timing ?? this.timing,
    startMinute: startMinute.present ? startMinute.value : this.startMinute,
    endMinute: endMinute.present ? endMinute.value : this.endMinute,
    timeZoneId: timeZoneId.present ? timeZoneId.value : this.timeZoneId,
    locationText: locationText.present ? locationText.value : this.locationText,
    requiresReport: requiresReport ?? this.requiresReport,
    contributionRuleKey: contributionRuleKey.present
        ? contributionRuleKey.value
        : this.contributionRuleKey,
    status: status ?? this.status,
    replacementEventId: replacementEventId.present
        ? replacementEventId.value
        : this.replacementEventId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  CalendarEventExceptionRow copyWithCompanion(
    CalendarEventExceptionsCompanion data,
  ) {
    return CalendarEventExceptionRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      effectiveDate: data.effectiveDate.present
          ? data.effectiveDate.value
          : this.effectiveDate,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      timing: data.timing.present ? data.timing.value : this.timing,
      startMinute: data.startMinute.present
          ? data.startMinute.value
          : this.startMinute,
      endMinute: data.endMinute.present ? data.endMinute.value : this.endMinute,
      timeZoneId: data.timeZoneId.present
          ? data.timeZoneId.value
          : this.timeZoneId,
      locationText: data.locationText.present
          ? data.locationText.value
          : this.locationText,
      requiresReport: data.requiresReport.present
          ? data.requiresReport.value
          : this.requiresReport,
      contributionRuleKey: data.contributionRuleKey.present
          ? data.contributionRuleKey.value
          : this.contributionRuleKey,
      status: data.status.present ? data.status.value : this.status,
      replacementEventId: data.replacementEventId.present
          ? data.replacementEventId.value
          : this.replacementEventId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventExceptionRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('eventId: $eventId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('originalDate: $originalDate, ')
          ..write('effectiveDate: $effectiveDate, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('locationText: $locationText, ')
          ..write('requiresReport: $requiresReport, ')
          ..write('contributionRuleKey: $contributionRuleKey, ')
          ..write('status: $status, ')
          ..write('replacementEventId: $replacementEventId, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    eventId,
    occurrenceId,
    originalDate,
    effectiveDate,
    title,
    notes,
    timing,
    startMinute,
    endMinute,
    timeZoneId,
    locationText,
    requiresReport,
    contributionRuleKey,
    status,
    replacementEventId,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventExceptionRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.eventId == this.eventId &&
          other.occurrenceId == this.occurrenceId &&
          other.originalDate == this.originalDate &&
          other.effectiveDate == this.effectiveDate &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.timing == this.timing &&
          other.startMinute == this.startMinute &&
          other.endMinute == this.endMinute &&
          other.timeZoneId == this.timeZoneId &&
          other.locationText == this.locationText &&
          other.requiresReport == this.requiresReport &&
          other.contributionRuleKey == this.contributionRuleKey &&
          other.status == this.status &&
          other.replacementEventId == this.replacementEventId &&
          other.createdAtUtc == this.createdAtUtc);
}

class CalendarEventExceptionsCompanion
    extends UpdateCompanion<CalendarEventExceptionRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> eventId;
  final Value<String> occurrenceId;
  final Value<String> originalDate;
  final Value<String> effectiveDate;
  final Value<String> title;
  final Value<String?> notes;
  final Value<String> timing;
  final Value<int?> startMinute;
  final Value<int?> endMinute;
  final Value<String?> timeZoneId;
  final Value<String?> locationText;
  final Value<bool> requiresReport;
  final Value<String?> contributionRuleKey;
  final Value<String> status;
  final Value<String?> replacementEventId;
  final Value<DateTime> createdAtUtc;
  final Value<int> rowid;
  const CalendarEventExceptionsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.effectiveDate = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.timing = const Value.absent(),
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.locationText = const Value.absent(),
    this.requiresReport = const Value.absent(),
    this.contributionRuleKey = const Value.absent(),
    this.status = const Value.absent(),
    this.replacementEventId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventExceptionsCompanion.insert({
    required String id,
    required String profileId,
    required String eventId,
    required String occurrenceId,
    required String originalDate,
    required String effectiveDate,
    required String title,
    this.notes = const Value.absent(),
    required String timing,
    this.startMinute = const Value.absent(),
    this.endMinute = const Value.absent(),
    this.timeZoneId = const Value.absent(),
    this.locationText = const Value.absent(),
    this.requiresReport = const Value.absent(),
    this.contributionRuleKey = const Value.absent(),
    required String status,
    this.replacementEventId = const Value.absent(),
    required DateTime createdAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       eventId = Value(eventId),
       occurrenceId = Value(occurrenceId),
       originalDate = Value(originalDate),
       effectiveDate = Value(effectiveDate),
       title = Value(title),
       timing = Value(timing),
       status = Value(status),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<CalendarEventExceptionRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? eventId,
    Expression<String>? occurrenceId,
    Expression<String>? originalDate,
    Expression<String>? effectiveDate,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<String>? timing,
    Expression<int>? startMinute,
    Expression<int>? endMinute,
    Expression<String>? timeZoneId,
    Expression<String>? locationText,
    Expression<bool>? requiresReport,
    Expression<String>? contributionRuleKey,
    Expression<String>? status,
    Expression<String>? replacementEventId,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (eventId != null) 'event_id': eventId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (originalDate != null) 'original_date': originalDate,
      if (effectiveDate != null) 'effective_date': effectiveDate,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (timing != null) 'timing': timing,
      if (startMinute != null) 'start_minute': startMinute,
      if (endMinute != null) 'end_minute': endMinute,
      if (timeZoneId != null) 'time_zone_id': timeZoneId,
      if (locationText != null) 'location_text': locationText,
      if (requiresReport != null) 'requires_report': requiresReport,
      if (contributionRuleKey != null)
        'contribution_rule_key': contributionRuleKey,
      if (status != null) 'status': status,
      if (replacementEventId != null)
        'replacement_event_id': replacementEventId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventExceptionsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? eventId,
    Value<String>? occurrenceId,
    Value<String>? originalDate,
    Value<String>? effectiveDate,
    Value<String>? title,
    Value<String?>? notes,
    Value<String>? timing,
    Value<int?>? startMinute,
    Value<int?>? endMinute,
    Value<String?>? timeZoneId,
    Value<String?>? locationText,
    Value<bool>? requiresReport,
    Value<String?>? contributionRuleKey,
    Value<String>? status,
    Value<String?>? replacementEventId,
    Value<DateTime>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return CalendarEventExceptionsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      eventId: eventId ?? this.eventId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      originalDate: originalDate ?? this.originalDate,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      timing: timing ?? this.timing,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      timeZoneId: timeZoneId ?? this.timeZoneId,
      locationText: locationText ?? this.locationText,
      requiresReport: requiresReport ?? this.requiresReport,
      contributionRuleKey: contributionRuleKey ?? this.contributionRuleKey,
      status: status ?? this.status,
      replacementEventId: replacementEventId ?? this.replacementEventId,
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
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<String>(originalDate.value);
    }
    if (effectiveDate.present) {
      map['effective_date'] = Variable<String>(effectiveDate.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (timing.present) {
      map['timing'] = Variable<String>(timing.value);
    }
    if (startMinute.present) {
      map['start_minute'] = Variable<int>(startMinute.value);
    }
    if (endMinute.present) {
      map['end_minute'] = Variable<int>(endMinute.value);
    }
    if (timeZoneId.present) {
      map['time_zone_id'] = Variable<String>(timeZoneId.value);
    }
    if (locationText.present) {
      map['location_text'] = Variable<String>(locationText.value);
    }
    if (requiresReport.present) {
      map['requires_report'] = Variable<bool>(requiresReport.value);
    }
    if (contributionRuleKey.present) {
      map['contribution_rule_key'] = Variable<String>(
        contributionRuleKey.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (replacementEventId.present) {
      map['replacement_event_id'] = Variable<String>(replacementEventId.value);
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
    return (StringBuffer('CalendarEventExceptionsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('eventId: $eventId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('originalDate: $originalDate, ')
          ..write('effectiveDate: $effectiveDate, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('timing: $timing, ')
          ..write('startMinute: $startMinute, ')
          ..write('endMinute: $endMinute, ')
          ..write('timeZoneId: $timeZoneId, ')
          ..write('locationText: $locationText, ')
          ..write('requiresReport: $requiresReport, ')
          ..write('contributionRuleKey: $contributionRuleKey, ')
          ..write('status: $status, ')
          ..write('replacementEventId: $replacementEventId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventOperationsTable extends CalendarEventOperations
    with TableInfo<$CalendarEventOperationsTable, CalendarEventOperationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
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
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceIdMeta = const VerificationMeta(
    'occurrenceId',
  );
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
    'occurrence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commandMeta = const VerificationMeta(
    'command',
  );
  @override
  late final GeneratedColumn<String> command = GeneratedColumn<String>(
    'command',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
    operationId,
    profileId,
    eventId,
    occurrenceId,
    command,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_event_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalendarEventOperationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
        _occurrenceIdMeta,
        occurrenceId.isAcceptableOrUnknown(
          data['occurrence_id']!,
          _occurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('command')) {
      context.handle(
        _commandMeta,
        command.isAcceptableOrUnknown(data['command']!, _commandMeta),
      );
    } else if (isInserting) {
      context.missing(_commandMeta);
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
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  CalendarEventOperationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventOperationRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      occurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_id'],
      ),
      command: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $CalendarEventOperationsTable createAlias(String alias) {
    return $CalendarEventOperationsTable(attachedDatabase, alias);
  }
}

class CalendarEventOperationRow extends DataClass
    implements Insertable<CalendarEventOperationRow> {
  final String operationId;
  final String profileId;
  final String eventId;
  final String? occurrenceId;
  final String command;
  final DateTime createdAtUtc;
  const CalendarEventOperationRow({
    required this.operationId,
    required this.profileId,
    required this.eventId,
    this.occurrenceId,
    required this.command,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['profile_id'] = Variable<String>(profileId);
    map['event_id'] = Variable<String>(eventId);
    if (!nullToAbsent || occurrenceId != null) {
      map['occurrence_id'] = Variable<String>(occurrenceId);
    }
    map['command'] = Variable<String>(command);
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  CalendarEventOperationsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventOperationsCompanion(
      operationId: Value(operationId),
      profileId: Value(profileId),
      eventId: Value(eventId),
      occurrenceId: occurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceId),
      command: Value(command),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory CalendarEventOperationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventOperationRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      occurrenceId: serializer.fromJson<String?>(json['occurrenceId']),
      command: serializer.fromJson<String>(json['command']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'profileId': serializer.toJson<String>(profileId),
      'eventId': serializer.toJson<String>(eventId),
      'occurrenceId': serializer.toJson<String?>(occurrenceId),
      'command': serializer.toJson<String>(command),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  CalendarEventOperationRow copyWith({
    String? operationId,
    String? profileId,
    String? eventId,
    Value<String?> occurrenceId = const Value.absent(),
    String? command,
    DateTime? createdAtUtc,
  }) => CalendarEventOperationRow(
    operationId: operationId ?? this.operationId,
    profileId: profileId ?? this.profileId,
    eventId: eventId ?? this.eventId,
    occurrenceId: occurrenceId.present ? occurrenceId.value : this.occurrenceId,
    command: command ?? this.command,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  CalendarEventOperationRow copyWithCompanion(
    CalendarEventOperationsCompanion data,
  ) {
    return CalendarEventOperationRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      command: data.command.present ? data.command.value : this.command,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventOperationRow(')
          ..write('operationId: $operationId, ')
          ..write('profileId: $profileId, ')
          ..write('eventId: $eventId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('command: $command, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    profileId,
    eventId,
    occurrenceId,
    command,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventOperationRow &&
          other.operationId == this.operationId &&
          other.profileId == this.profileId &&
          other.eventId == this.eventId &&
          other.occurrenceId == this.occurrenceId &&
          other.command == this.command &&
          other.createdAtUtc == this.createdAtUtc);
}

class CalendarEventOperationsCompanion
    extends UpdateCompanion<CalendarEventOperationRow> {
  final Value<String> operationId;
  final Value<String> profileId;
  final Value<String> eventId;
  final Value<String?> occurrenceId;
  final Value<String> command;
  final Value<DateTime> createdAtUtc;
  final Value<int> rowid;
  const CalendarEventOperationsCompanion({
    this.operationId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.command = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventOperationsCompanion.insert({
    required String operationId,
    required String profileId,
    required String eventId,
    this.occurrenceId = const Value.absent(),
    required String command,
    required DateTime createdAtUtc,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       profileId = Value(profileId),
       eventId = Value(eventId),
       command = Value(command),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<CalendarEventOperationRow> custom({
    Expression<String>? operationId,
    Expression<String>? profileId,
    Expression<String>? eventId,
    Expression<String>? occurrenceId,
    Expression<String>? command,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (profileId != null) 'profile_id': profileId,
      if (eventId != null) 'event_id': eventId,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (command != null) 'command': command,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventOperationsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? profileId,
    Value<String>? eventId,
    Value<String?>? occurrenceId,
    Value<String>? command,
    Value<DateTime>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return CalendarEventOperationsCompanion(
      operationId: operationId ?? this.operationId,
      profileId: profileId ?? this.profileId,
      eventId: eventId ?? this.eventId,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      command: command ?? this.command,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (command.present) {
      map['command'] = Variable<String>(command.value);
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
    return (StringBuffer('CalendarEventOperationsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('profileId: $profileId, ')
          ..write('eventId: $eventId, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('command: $command, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskEventLinksTable extends TaskEventLinks
    with TableInfo<$TaskEventLinksTable, TaskEventLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskEventLinksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetKeyMeta = const VerificationMeta(
    'targetKey',
  );
  @override
  late final GeneratedColumn<String> targetKey = GeneratedColumn<String>(
    'target_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceIdMeta = const VerificationMeta(
    'occurrenceId',
  );
  @override
  late final GeneratedColumn<String> occurrenceId = GeneratedColumn<String>(
    'occurrence_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalDateMeta = const VerificationMeta(
    'originalDate',
  );
  @override
  late final GeneratedColumn<String> originalDate = GeneratedColumn<String>(
    'original_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _canonicalSourceMeta = const VerificationMeta(
    'canonicalSource',
  );
  @override
  late final GeneratedColumn<String> canonicalSource = GeneratedColumn<String>(
    'canonical_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transferredFromLinkIdMeta =
      const VerificationMeta('transferredFromLinkId');
  @override
  late final GeneratedColumn<String> transferredFromLinkId =
      GeneratedColumn<String>(
        'transferred_from_link_id',
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
    profileId,
    taskId,
    eventId,
    scope,
    targetKey,
    occurrenceId,
    originalDate,
    status,
    canonicalSource,
    transferredFromLinkId,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_event_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskEventLinkRow> instance, {
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
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('target_key')) {
      context.handle(
        _targetKeyMeta,
        targetKey.isAcceptableOrUnknown(data['target_key']!, _targetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKeyMeta);
    }
    if (data.containsKey('occurrence_id')) {
      context.handle(
        _occurrenceIdMeta,
        occurrenceId.isAcceptableOrUnknown(
          data['occurrence_id']!,
          _occurrenceIdMeta,
        ),
      );
    }
    if (data.containsKey('original_date')) {
      context.handle(
        _originalDateMeta,
        originalDate.isAcceptableOrUnknown(
          data['original_date']!,
          _originalDateMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('canonical_source')) {
      context.handle(
        _canonicalSourceMeta,
        canonicalSource.isAcceptableOrUnknown(
          data['canonical_source']!,
          _canonicalSourceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalSourceMeta);
    }
    if (data.containsKey('transferred_from_link_id')) {
      context.handle(
        _transferredFromLinkIdMeta,
        transferredFromLinkId.isAcceptableOrUnknown(
          data['transferred_from_link_id']!,
          _transferredFromLinkIdMeta,
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
  TaskEventLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskEventLinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      targetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_key'],
      )!,
      occurrenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}occurrence_id'],
      ),
      originalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      canonicalSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_source'],
      )!,
      transferredFromLinkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transferred_from_link_id'],
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
  $TaskEventLinksTable createAlias(String alias) {
    return $TaskEventLinksTable(attachedDatabase, alias);
  }
}

class TaskEventLinkRow extends DataClass
    implements Insertable<TaskEventLinkRow> {
  final String id;
  final String profileId;
  final String taskId;
  final String eventId;
  final String scope;
  final String targetKey;
  final String? occurrenceId;
  final String? originalDate;
  final String status;
  final String canonicalSource;
  final String? transferredFromLinkId;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  const TaskEventLinkRow({
    required this.id,
    required this.profileId,
    required this.taskId,
    required this.eventId,
    required this.scope,
    required this.targetKey,
    this.occurrenceId,
    this.originalDate,
    required this.status,
    required this.canonicalSource,
    this.transferredFromLinkId,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['task_id'] = Variable<String>(taskId);
    map['event_id'] = Variable<String>(eventId);
    map['scope'] = Variable<String>(scope);
    map['target_key'] = Variable<String>(targetKey);
    if (!nullToAbsent || occurrenceId != null) {
      map['occurrence_id'] = Variable<String>(occurrenceId);
    }
    if (!nullToAbsent || originalDate != null) {
      map['original_date'] = Variable<String>(originalDate);
    }
    map['status'] = Variable<String>(status);
    map['canonical_source'] = Variable<String>(canonicalSource);
    if (!nullToAbsent || transferredFromLinkId != null) {
      map['transferred_from_link_id'] = Variable<String>(transferredFromLinkId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    map['updated_at_utc'] = Variable<DateTime>(updatedAtUtc);
    return map;
  }

  TaskEventLinksCompanion toCompanion(bool nullToAbsent) {
    return TaskEventLinksCompanion(
      id: Value(id),
      profileId: Value(profileId),
      taskId: Value(taskId),
      eventId: Value(eventId),
      scope: Value(scope),
      targetKey: Value(targetKey),
      occurrenceId: occurrenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(occurrenceId),
      originalDate: originalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(originalDate),
      status: Value(status),
      canonicalSource: Value(canonicalSource),
      transferredFromLinkId: transferredFromLinkId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferredFromLinkId),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory TaskEventLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskEventLinkRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      taskId: serializer.fromJson<String>(json['taskId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      scope: serializer.fromJson<String>(json['scope']),
      targetKey: serializer.fromJson<String>(json['targetKey']),
      occurrenceId: serializer.fromJson<String?>(json['occurrenceId']),
      originalDate: serializer.fromJson<String?>(json['originalDate']),
      status: serializer.fromJson<String>(json['status']),
      canonicalSource: serializer.fromJson<String>(json['canonicalSource']),
      transferredFromLinkId: serializer.fromJson<String?>(
        json['transferredFromLinkId'],
      ),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<DateTime>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'taskId': serializer.toJson<String>(taskId),
      'eventId': serializer.toJson<String>(eventId),
      'scope': serializer.toJson<String>(scope),
      'targetKey': serializer.toJson<String>(targetKey),
      'occurrenceId': serializer.toJson<String?>(occurrenceId),
      'originalDate': serializer.toJson<String?>(originalDate),
      'status': serializer.toJson<String>(status),
      'canonicalSource': serializer.toJson<String>(canonicalSource),
      'transferredFromLinkId': serializer.toJson<String?>(
        transferredFromLinkId,
      ),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<DateTime>(updatedAtUtc),
    };
  }

  TaskEventLinkRow copyWith({
    String? id,
    String? profileId,
    String? taskId,
    String? eventId,
    String? scope,
    String? targetKey,
    Value<String?> occurrenceId = const Value.absent(),
    Value<String?> originalDate = const Value.absent(),
    String? status,
    String? canonicalSource,
    Value<String?> transferredFromLinkId = const Value.absent(),
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
  }) => TaskEventLinkRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    taskId: taskId ?? this.taskId,
    eventId: eventId ?? this.eventId,
    scope: scope ?? this.scope,
    targetKey: targetKey ?? this.targetKey,
    occurrenceId: occurrenceId.present ? occurrenceId.value : this.occurrenceId,
    originalDate: originalDate.present ? originalDate.value : this.originalDate,
    status: status ?? this.status,
    canonicalSource: canonicalSource ?? this.canonicalSource,
    transferredFromLinkId: transferredFromLinkId.present
        ? transferredFromLinkId.value
        : this.transferredFromLinkId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  TaskEventLinkRow copyWithCompanion(TaskEventLinksCompanion data) {
    return TaskEventLinkRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      scope: data.scope.present ? data.scope.value : this.scope,
      targetKey: data.targetKey.present ? data.targetKey.value : this.targetKey,
      occurrenceId: data.occurrenceId.present
          ? data.occurrenceId.value
          : this.occurrenceId,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      status: data.status.present ? data.status.value : this.status,
      canonicalSource: data.canonicalSource.present
          ? data.canonicalSource.value
          : this.canonicalSource,
      transferredFromLinkId: data.transferredFromLinkId.present
          ? data.transferredFromLinkId.value
          : this.transferredFromLinkId,
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
    return (StringBuffer('TaskEventLinkRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('taskId: $taskId, ')
          ..write('eventId: $eventId, ')
          ..write('scope: $scope, ')
          ..write('targetKey: $targetKey, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('originalDate: $originalDate, ')
          ..write('status: $status, ')
          ..write('canonicalSource: $canonicalSource, ')
          ..write('transferredFromLinkId: $transferredFromLinkId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    taskId,
    eventId,
    scope,
    targetKey,
    occurrenceId,
    originalDate,
    status,
    canonicalSource,
    transferredFromLinkId,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskEventLinkRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.taskId == this.taskId &&
          other.eventId == this.eventId &&
          other.scope == this.scope &&
          other.targetKey == this.targetKey &&
          other.occurrenceId == this.occurrenceId &&
          other.originalDate == this.originalDate &&
          other.status == this.status &&
          other.canonicalSource == this.canonicalSource &&
          other.transferredFromLinkId == this.transferredFromLinkId &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class TaskEventLinksCompanion extends UpdateCompanion<TaskEventLinkRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> taskId;
  final Value<String> eventId;
  final Value<String> scope;
  final Value<String> targetKey;
  final Value<String?> occurrenceId;
  final Value<String?> originalDate;
  final Value<String> status;
  final Value<String> canonicalSource;
  final Value<String?> transferredFromLinkId;
  final Value<DateTime> createdAtUtc;
  final Value<DateTime> updatedAtUtc;
  final Value<int> rowid;
  const TaskEventLinksCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.taskId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.scope = const Value.absent(),
    this.targetKey = const Value.absent(),
    this.occurrenceId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.status = const Value.absent(),
    this.canonicalSource = const Value.absent(),
    this.transferredFromLinkId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskEventLinksCompanion.insert({
    required String id,
    required String profileId,
    required String taskId,
    required String eventId,
    required String scope,
    required String targetKey,
    this.occurrenceId = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.status = const Value.absent(),
    required String canonicalSource,
    this.transferredFromLinkId = const Value.absent(),
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       taskId = Value(taskId),
       eventId = Value(eventId),
       scope = Value(scope),
       targetKey = Value(targetKey),
       canonicalSource = Value(canonicalSource),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<TaskEventLinkRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? taskId,
    Expression<String>? eventId,
    Expression<String>? scope,
    Expression<String>? targetKey,
    Expression<String>? occurrenceId,
    Expression<String>? originalDate,
    Expression<String>? status,
    Expression<String>? canonicalSource,
    Expression<String>? transferredFromLinkId,
    Expression<DateTime>? createdAtUtc,
    Expression<DateTime>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (taskId != null) 'task_id': taskId,
      if (eventId != null) 'event_id': eventId,
      if (scope != null) 'scope': scope,
      if (targetKey != null) 'target_key': targetKey,
      if (occurrenceId != null) 'occurrence_id': occurrenceId,
      if (originalDate != null) 'original_date': originalDate,
      if (status != null) 'status': status,
      if (canonicalSource != null) 'canonical_source': canonicalSource,
      if (transferredFromLinkId != null)
        'transferred_from_link_id': transferredFromLinkId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskEventLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? taskId,
    Value<String>? eventId,
    Value<String>? scope,
    Value<String>? targetKey,
    Value<String?>? occurrenceId,
    Value<String?>? originalDate,
    Value<String>? status,
    Value<String>? canonicalSource,
    Value<String?>? transferredFromLinkId,
    Value<DateTime>? createdAtUtc,
    Value<DateTime>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return TaskEventLinksCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      taskId: taskId ?? this.taskId,
      eventId: eventId ?? this.eventId,
      scope: scope ?? this.scope,
      targetKey: targetKey ?? this.targetKey,
      occurrenceId: occurrenceId ?? this.occurrenceId,
      originalDate: originalDate ?? this.originalDate,
      status: status ?? this.status,
      canonicalSource: canonicalSource ?? this.canonicalSource,
      transferredFromLinkId:
          transferredFromLinkId ?? this.transferredFromLinkId,
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
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (targetKey.present) {
      map['target_key'] = Variable<String>(targetKey.value);
    }
    if (occurrenceId.present) {
      map['occurrence_id'] = Variable<String>(occurrenceId.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<String>(originalDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (canonicalSource.present) {
      map['canonical_source'] = Variable<String>(canonicalSource.value);
    }
    if (transferredFromLinkId.present) {
      map['transferred_from_link_id'] = Variable<String>(
        transferredFromLinkId.value,
      );
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
    return (StringBuffer('TaskEventLinksCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('taskId: $taskId, ')
          ..write('eventId: $eventId, ')
          ..write('scope: $scope, ')
          ..write('targetKey: $targetKey, ')
          ..write('occurrenceId: $occurrenceId, ')
          ..write('originalDate: $originalDate, ')
          ..write('status: $status, ')
          ..write('canonicalSource: $canonicalSource, ')
          ..write('transferredFromLinkId: $transferredFromLinkId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskEventLinkHistoryTable extends TaskEventLinkHistory
    with TableInfo<$TaskEventLinkHistoryTable, TaskEventLinkHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskEventLinkHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _linkIdMeta = const VerificationMeta('linkId');
  @override
  late final GeneratedColumn<String> linkId = GeneratedColumn<String>(
    'link_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromStatusMeta = const VerificationMeta(
    'fromStatus',
  );
  @override
  late final GeneratedColumn<String> fromStatus = GeneratedColumn<String>(
    'from_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toStatusMeta = const VerificationMeta(
    'toStatus',
  );
  @override
  late final GeneratedColumn<String> toStatus = GeneratedColumn<String>(
    'to_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relatedLinkIdMeta = const VerificationMeta(
    'relatedLinkId',
  );
  @override
  late final GeneratedColumn<String> relatedLinkId = GeneratedColumn<String>(
    'related_link_id',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    linkId,
    operationId,
    action,
    fromStatus,
    toStatus,
    relatedLinkId,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_event_link_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskEventLinkHistoryRow> instance, {
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
    if (data.containsKey('link_id')) {
      context.handle(
        _linkIdMeta,
        linkId.isAcceptableOrUnknown(data['link_id']!, _linkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_linkIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('from_status')) {
      context.handle(
        _fromStatusMeta,
        fromStatus.isAcceptableOrUnknown(data['from_status']!, _fromStatusMeta),
      );
    }
    if (data.containsKey('to_status')) {
      context.handle(
        _toStatusMeta,
        toStatus.isAcceptableOrUnknown(data['to_status']!, _toStatusMeta),
      );
    } else if (isInserting) {
      context.missing(_toStatusMeta);
    }
    if (data.containsKey('related_link_id')) {
      context.handle(
        _relatedLinkIdMeta,
        relatedLinkId.isAcceptableOrUnknown(
          data['related_link_id']!,
          _relatedLinkIdMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskEventLinkHistoryRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskEventLinkHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      linkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}link_id'],
      )!,
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      fromStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_status'],
      ),
      toStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_status'],
      )!,
      relatedLinkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_link_id'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $TaskEventLinkHistoryTable createAlias(String alias) {
    return $TaskEventLinkHistoryTable(attachedDatabase, alias);
  }
}

class TaskEventLinkHistoryRow extends DataClass
    implements Insertable<TaskEventLinkHistoryRow> {
  final String id;
  final String profileId;
  final String linkId;
  final String operationId;
  final String action;
  final String? fromStatus;
  final String toStatus;
  final String? relatedLinkId;
  final DateTime createdAtUtc;
  const TaskEventLinkHistoryRow({
    required this.id,
    required this.profileId,
    required this.linkId,
    required this.operationId,
    required this.action,
    this.fromStatus,
    required this.toStatus,
    this.relatedLinkId,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['link_id'] = Variable<String>(linkId);
    map['operation_id'] = Variable<String>(operationId);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || fromStatus != null) {
      map['from_status'] = Variable<String>(fromStatus);
    }
    map['to_status'] = Variable<String>(toStatus);
    if (!nullToAbsent || relatedLinkId != null) {
      map['related_link_id'] = Variable<String>(relatedLinkId);
    }
    map['created_at_utc'] = Variable<DateTime>(createdAtUtc);
    return map;
  }

  TaskEventLinkHistoryCompanion toCompanion(bool nullToAbsent) {
    return TaskEventLinkHistoryCompanion(
      id: Value(id),
      profileId: Value(profileId),
      linkId: Value(linkId),
      operationId: Value(operationId),
      action: Value(action),
      fromStatus: fromStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(fromStatus),
      toStatus: Value(toStatus),
      relatedLinkId: relatedLinkId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedLinkId),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory TaskEventLinkHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskEventLinkHistoryRow(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      linkId: serializer.fromJson<String>(json['linkId']),
      operationId: serializer.fromJson<String>(json['operationId']),
      action: serializer.fromJson<String>(json['action']),
      fromStatus: serializer.fromJson<String?>(json['fromStatus']),
      toStatus: serializer.fromJson<String>(json['toStatus']),
      relatedLinkId: serializer.fromJson<String?>(json['relatedLinkId']),
      createdAtUtc: serializer.fromJson<DateTime>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'linkId': serializer.toJson<String>(linkId),
      'operationId': serializer.toJson<String>(operationId),
      'action': serializer.toJson<String>(action),
      'fromStatus': serializer.toJson<String?>(fromStatus),
      'toStatus': serializer.toJson<String>(toStatus),
      'relatedLinkId': serializer.toJson<String?>(relatedLinkId),
      'createdAtUtc': serializer.toJson<DateTime>(createdAtUtc),
    };
  }

  TaskEventLinkHistoryRow copyWith({
    String? id,
    String? profileId,
    String? linkId,
    String? operationId,
    String? action,
    Value<String?> fromStatus = const Value.absent(),
    String? toStatus,
    Value<String?> relatedLinkId = const Value.absent(),
    DateTime? createdAtUtc,
  }) => TaskEventLinkHistoryRow(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    linkId: linkId ?? this.linkId,
    operationId: operationId ?? this.operationId,
    action: action ?? this.action,
    fromStatus: fromStatus.present ? fromStatus.value : this.fromStatus,
    toStatus: toStatus ?? this.toStatus,
    relatedLinkId: relatedLinkId.present
        ? relatedLinkId.value
        : this.relatedLinkId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  TaskEventLinkHistoryRow copyWithCompanion(
    TaskEventLinkHistoryCompanion data,
  ) {
    return TaskEventLinkHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      linkId: data.linkId.present ? data.linkId.value : this.linkId,
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      action: data.action.present ? data.action.value : this.action,
      fromStatus: data.fromStatus.present
          ? data.fromStatus.value
          : this.fromStatus,
      toStatus: data.toStatus.present ? data.toStatus.value : this.toStatus,
      relatedLinkId: data.relatedLinkId.present
          ? data.relatedLinkId.value
          : this.relatedLinkId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskEventLinkHistoryRow(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('linkId: $linkId, ')
          ..write('operationId: $operationId, ')
          ..write('action: $action, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('relatedLinkId: $relatedLinkId, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    linkId,
    operationId,
    action,
    fromStatus,
    toStatus,
    relatedLinkId,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskEventLinkHistoryRow &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.linkId == this.linkId &&
          other.operationId == this.operationId &&
          other.action == this.action &&
          other.fromStatus == this.fromStatus &&
          other.toStatus == this.toStatus &&
          other.relatedLinkId == this.relatedLinkId &&
          other.createdAtUtc == this.createdAtUtc);
}

class TaskEventLinkHistoryCompanion
    extends UpdateCompanion<TaskEventLinkHistoryRow> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> linkId;
  final Value<String> operationId;
  final Value<String> action;
  final Value<String?> fromStatus;
  final Value<String> toStatus;
  final Value<String?> relatedLinkId;
  final Value<DateTime> createdAtUtc;
  final Value<int> rowid;
  const TaskEventLinkHistoryCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.linkId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.action = const Value.absent(),
    this.fromStatus = const Value.absent(),
    this.toStatus = const Value.absent(),
    this.relatedLinkId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskEventLinkHistoryCompanion.insert({
    required String id,
    required String profileId,
    required String linkId,
    required String operationId,
    required String action,
    this.fromStatus = const Value.absent(),
    required String toStatus,
    this.relatedLinkId = const Value.absent(),
    required DateTime createdAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       linkId = Value(linkId),
       operationId = Value(operationId),
       action = Value(action),
       toStatus = Value(toStatus),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<TaskEventLinkHistoryRow> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? linkId,
    Expression<String>? operationId,
    Expression<String>? action,
    Expression<String>? fromStatus,
    Expression<String>? toStatus,
    Expression<String>? relatedLinkId,
    Expression<DateTime>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (linkId != null) 'link_id': linkId,
      if (operationId != null) 'operation_id': operationId,
      if (action != null) 'action': action,
      if (fromStatus != null) 'from_status': fromStatus,
      if (toStatus != null) 'to_status': toStatus,
      if (relatedLinkId != null) 'related_link_id': relatedLinkId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskEventLinkHistoryCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? linkId,
    Value<String>? operationId,
    Value<String>? action,
    Value<String?>? fromStatus,
    Value<String>? toStatus,
    Value<String?>? relatedLinkId,
    Value<DateTime>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return TaskEventLinkHistoryCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      linkId: linkId ?? this.linkId,
      operationId: operationId ?? this.operationId,
      action: action ?? this.action,
      fromStatus: fromStatus ?? this.fromStatus,
      toStatus: toStatus ?? this.toStatus,
      relatedLinkId: relatedLinkId ?? this.relatedLinkId,
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
    if (linkId.present) {
      map['link_id'] = Variable<String>(linkId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (fromStatus.present) {
      map['from_status'] = Variable<String>(fromStatus.value);
    }
    if (toStatus.present) {
      map['to_status'] = Variable<String>(toStatus.value);
    }
    if (relatedLinkId.present) {
      map['related_link_id'] = Variable<String>(relatedLinkId.value);
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
    return (StringBuffer('TaskEventLinkHistoryCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('linkId: $linkId, ')
          ..write('operationId: $operationId, ')
          ..write('action: $action, ')
          ..write('fromStatus: $fromStatus, ')
          ..write('toStatus: $toStatus, ')
          ..write('relatedLinkId: $relatedLinkId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
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
  late final $PlannerTasksTable plannerTasks = $PlannerTasksTable(this);
  late final $TaskStatusChangesTable taskStatusChanges =
      $TaskStatusChangesTable(this);
  late final $CalendarEventsTable calendarEvents = $CalendarEventsTable(this);
  late final $CalendarEventExceptionsTable calendarEventExceptions =
      $CalendarEventExceptionsTable(this);
  late final $CalendarEventOperationsTable calendarEventOperations =
      $CalendarEventOperationsTable(this);
  late final $TaskEventLinksTable taskEventLinks = $TaskEventLinksTable(this);
  late final $TaskEventLinkHistoryTable taskEventLinkHistory =
      $TaskEventLinkHistoryTable(this);
  late final Index lifeIndicatorProfileKeyUnique = Index(
    'life_indicator_profile_key_unique',
    'CREATE UNIQUE INDEX life_indicator_profile_key_unique ON life_indicator_definitions (profile_id, indicator_key)',
  );
  late final Index plannerTaskProfileDueDate = Index(
    'planner_task_profile_due_date',
    'CREATE INDEX planner_task_profile_due_date ON planner_tasks (profile_id, due_date)',
  );
  late final Index taskStatusChangeOperationUnique = Index(
    'task_status_change_operation_unique',
    'CREATE UNIQUE INDEX task_status_change_operation_unique ON task_status_changes (operation_id)',
  );
  late final Index taskStatusChangeTaskTime = Index(
    'task_status_change_task_time',
    'CREATE INDEX task_status_change_task_time ON task_status_changes (task_id, changed_at_utc)',
  );
  late final Index calendarEventProfileStartDate = Index(
    'calendar_event_profile_start_date',
    'CREATE INDEX calendar_event_profile_start_date ON calendar_events (profile_id, start_date)',
  );
  late final Index calendarEventExceptionOccurrenceTime = Index(
    'calendar_event_exception_occurrence_time',
    'CREATE INDEX calendar_event_exception_occurrence_time ON calendar_event_exceptions (event_id, occurrence_id, created_at_utc)',
  );
  late final Index taskEventLinkEquivalentUnique = Index(
    'task_event_link_equivalent_unique',
    'CREATE UNIQUE INDEX task_event_link_equivalent_unique ON task_event_links (profile_id, task_id, event_id, target_key)',
  );
  late final Index taskEventLinkTaskStatus = Index(
    'task_event_link_task_status',
    'CREATE INDEX task_event_link_task_status ON task_event_links (task_id, status)',
  );
  late final Index taskEventLinkEventStatus = Index(
    'task_event_link_event_status',
    'CREATE INDEX task_event_link_event_status ON task_event_links (event_id, status)',
  );
  late final Index taskEventLinkHistoryOperationUnique = Index(
    'task_event_link_history_operation_unique',
    'CREATE UNIQUE INDEX task_event_link_history_operation_unique ON task_event_link_history (operation_id)',
  );
  late final Index taskEventLinkHistoryLinkTime = Index(
    'task_event_link_history_link_time',
    'CREATE INDEX task_event_link_history_link_time ON task_event_link_history (link_id, created_at_utc)',
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
    plannerTasks,
    taskStatusChanges,
    calendarEvents,
    calendarEventExceptions,
    calendarEventOperations,
    taskEventLinks,
    taskEventLinkHistory,
    lifeIndicatorProfileKeyUnique,
    plannerTaskProfileDueDate,
    taskStatusChangeOperationUnique,
    taskStatusChangeTaskTime,
    calendarEventProfileStartDate,
    calendarEventExceptionOccurrenceTime,
    taskEventLinkEquivalentUnique,
    taskEventLinkTaskStatus,
    taskEventLinkEventStatus,
    taskEventLinkHistoryOperationUnique,
    taskEventLinkHistoryLinkTime,
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

  static MultiTypedResultKey<$PlannerTasksTable, List<PlannerTaskRow>>
  _plannerTasksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.plannerTasks,
    aliasName: 'local_profiles__id__planner_tasks__profile_id',
  );

  $$PlannerTasksTableProcessedTableManager get plannerTasksRefs {
    final manager = $$PlannerTasksTableTableManager(
      $_db,
      $_db.plannerTasks,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_plannerTasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskStatusChangesTable, List<TaskStatusChangeRow>>
  _taskStatusChangesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskStatusChanges,
        aliasName: 'local_profiles__id__task_status_changes__profile_id',
      );

  $$TaskStatusChangesTableProcessedTableManager get taskStatusChangesRefs {
    final manager = $$TaskStatusChangesTableTableManager(
      $_db,
      $_db.taskStatusChanges,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskStatusChangesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CalendarEventsTable, List<CalendarEventRow>>
  _calendarEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.calendarEvents,
    aliasName: 'local_profiles__id__calendar_events__profile_id',
  );

  $$CalendarEventsTableProcessedTableManager get calendarEventsRefs {
    final manager = $$CalendarEventsTableTableManager(
      $_db,
      $_db.calendarEvents,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_calendarEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CalendarEventExceptionsTable,
    List<CalendarEventExceptionRow>
  >
  _calendarEventExceptionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarEventExceptions,
        aliasName: 'local_profiles__id__calendar_event_exceptions__profile_id',
      );

  $$CalendarEventExceptionsTableProcessedTableManager
  get calendarEventExceptionsRefs {
    final manager = $$CalendarEventExceptionsTableTableManager(
      $_db,
      $_db.calendarEventExceptions,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calendarEventExceptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CalendarEventOperationsTable,
    List<CalendarEventOperationRow>
  >
  _calendarEventOperationsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarEventOperations,
        aliasName: 'local_profiles__id__calendar_event_operations__profile_id',
      );

  $$CalendarEventOperationsTableProcessedTableManager
  get calendarEventOperationsRefs {
    final manager = $$CalendarEventOperationsTableTableManager(
      $_db,
      $_db.calendarEventOperations,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calendarEventOperationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskEventLinksTable, List<TaskEventLinkRow>>
  _taskEventLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.taskEventLinks,
    aliasName: 'local_profiles__id__task_event_links__profile_id',
  );

  $$TaskEventLinksTableProcessedTableManager get taskEventLinksRefs {
    final manager = $$TaskEventLinksTableTableManager(
      $_db,
      $_db.taskEventLinks,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskEventLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TaskEventLinkHistoryTable,
    List<TaskEventLinkHistoryRow>
  >
  _taskEventLinkHistoryRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskEventLinkHistory,
        aliasName: 'local_profiles__id__task_event_link_history__profile_id',
      );

  $$TaskEventLinkHistoryTableProcessedTableManager
  get taskEventLinkHistoryRefs {
    final manager = $$TaskEventLinkHistoryTableTableManager(
      $_db,
      $_db.taskEventLinkHistory,
    ).filter((f) => f.profileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskEventLinkHistoryRefsTable($_db),
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

  Expression<bool> plannerTasksRefs(
    Expression<bool> Function($$PlannerTasksTableFilterComposer f) f,
  ) {
    final $$PlannerTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.plannerTasks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlannerTasksTableFilterComposer(
            $db: $db,
            $table: $db.plannerTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskStatusChangesRefs(
    Expression<bool> Function($$TaskStatusChangesTableFilterComposer f) f,
  ) {
    final $$TaskStatusChangesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskStatusChanges,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskStatusChangesTableFilterComposer(
            $db: $db,
            $table: $db.taskStatusChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> calendarEventsRefs(
    Expression<bool> Function($$CalendarEventsTableFilterComposer f) f,
  ) {
    final $$CalendarEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableFilterComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> calendarEventExceptionsRefs(
    Expression<bool> Function($$CalendarEventExceptionsTableFilterComposer f) f,
  ) {
    final $$CalendarEventExceptionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventExceptions,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventExceptionsTableFilterComposer(
                $db: $db,
                $table: $db.calendarEventExceptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> calendarEventOperationsRefs(
    Expression<bool> Function($$CalendarEventOperationsTableFilterComposer f) f,
  ) {
    final $$CalendarEventOperationsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventOperations,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventOperationsTableFilterComposer(
                $db: $db,
                $table: $db.calendarEventOperations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> taskEventLinksRefs(
    Expression<bool> Function($$TaskEventLinksTableFilterComposer f) f,
  ) {
    final $$TaskEventLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskEventLinks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskEventLinksTableFilterComposer(
            $db: $db,
            $table: $db.taskEventLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskEventLinkHistoryRefs(
    Expression<bool> Function($$TaskEventLinkHistoryTableFilterComposer f) f,
  ) {
    final $$TaskEventLinkHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskEventLinkHistory,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskEventLinkHistoryTableFilterComposer(
            $db: $db,
            $table: $db.taskEventLinkHistory,
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

  Expression<T> plannerTasksRefs<T extends Object>(
    Expression<T> Function($$PlannerTasksTableAnnotationComposer a) f,
  ) {
    final $$PlannerTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.plannerTasks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlannerTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.plannerTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskStatusChangesRefs<T extends Object>(
    Expression<T> Function($$TaskStatusChangesTableAnnotationComposer a) f,
  ) {
    final $$TaskStatusChangesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.taskStatusChanges,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskStatusChangesTableAnnotationComposer(
                $db: $db,
                $table: $db.taskStatusChanges,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> calendarEventsRefs<T extends Object>(
    Expression<T> Function($$CalendarEventsTableAnnotationComposer a) f,
  ) {
    final $$CalendarEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> calendarEventExceptionsRefs<T extends Object>(
    Expression<T> Function($$CalendarEventExceptionsTableAnnotationComposer a)
    f,
  ) {
    final $$CalendarEventExceptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventExceptions,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventExceptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarEventExceptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> calendarEventOperationsRefs<T extends Object>(
    Expression<T> Function($$CalendarEventOperationsTableAnnotationComposer a)
    f,
  ) {
    final $$CalendarEventOperationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventOperations,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventOperationsTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarEventOperations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> taskEventLinksRefs<T extends Object>(
    Expression<T> Function($$TaskEventLinksTableAnnotationComposer a) f,
  ) {
    final $$TaskEventLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskEventLinks,
      getReferencedColumn: (t) => t.profileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskEventLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.taskEventLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskEventLinkHistoryRefs<T extends Object>(
    Expression<T> Function($$TaskEventLinkHistoryTableAnnotationComposer a) f,
  ) {
    final $$TaskEventLinkHistoryTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.taskEventLinkHistory,
          getReferencedColumn: (t) => t.profileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskEventLinkHistoryTableAnnotationComposer(
                $db: $db,
                $table: $db.taskEventLinkHistory,
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
          PrefetchHooks Function({
            bool lifeIndicatorDefinitionsRefs,
            bool plannerTasksRefs,
            bool taskStatusChangesRefs,
            bool calendarEventsRefs,
            bool calendarEventExceptionsRefs,
            bool calendarEventOperationsRefs,
            bool taskEventLinksRefs,
            bool taskEventLinkHistoryRefs,
          })
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
          prefetchHooksCallback:
              ({
                lifeIndicatorDefinitionsRefs = false,
                plannerTasksRefs = false,
                taskStatusChangesRefs = false,
                calendarEventsRefs = false,
                calendarEventExceptionsRefs = false,
                calendarEventOperationsRefs = false,
                taskEventLinksRefs = false,
                taskEventLinkHistoryRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (lifeIndicatorDefinitionsRefs)
                      db.lifeIndicatorDefinitions,
                    if (plannerTasksRefs) db.plannerTasks,
                    if (taskStatusChangesRefs) db.taskStatusChanges,
                    if (calendarEventsRefs) db.calendarEvents,
                    if (calendarEventExceptionsRefs) db.calendarEventExceptions,
                    if (calendarEventOperationsRefs) db.calendarEventOperations,
                    if (taskEventLinksRefs) db.taskEventLinks,
                    if (taskEventLinkHistoryRefs) db.taskEventLinkHistory,
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
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (plannerTasksRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          PlannerTaskRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._plannerTasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).plannerTasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskStatusChangesRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          TaskStatusChangeRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._taskStatusChangesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).taskStatusChangesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarEventsRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          CalendarEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._calendarEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarEventExceptionsRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          CalendarEventExceptionRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._calendarEventExceptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventExceptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (calendarEventOperationsRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          CalendarEventOperationRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._calendarEventOperationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventOperationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskEventLinksRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          TaskEventLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._taskEventLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).taskEventLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskEventLinkHistoryRefs)
                        await $_getPrefetchedData<
                          LocalProfileRow,
                          $LocalProfilesTable,
                          TaskEventLinkHistoryRow
                        >(
                          currentTable: table,
                          referencedTable: $$LocalProfilesTableReferences
                              ._taskEventLinkHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LocalProfilesTableReferences(
                                db,
                                table,
                                p0,
                              ).taskEventLinkHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.profileId == item.id,
                              ),
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
      PrefetchHooks Function({
        bool lifeIndicatorDefinitionsRefs,
        bool plannerTasksRefs,
        bool taskStatusChangesRefs,
        bool calendarEventsRefs,
        bool calendarEventExceptionsRefs,
        bool calendarEventOperationsRefs,
        bool taskEventLinksRefs,
        bool taskEventLinkHistoryRefs,
      })
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
typedef $$PlannerTasksTableCreateCompanionBuilder =
    PlannerTasksCompanion Function({
      required String id,
      required String profileId,
      required String title,
      Value<String?> notes,
      Value<String?> dueDate,
      Value<String> status,
      Value<bool> requiresReport,
      Value<String?> contributionRuleKey,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PlannerTasksTableUpdateCompanionBuilder =
    PlannerTasksCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> title,
      Value<String?> notes,
      Value<String?> dueDate,
      Value<String> status,
      Value<bool> requiresReport,
      Value<String?> contributionRuleKey,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$PlannerTasksTableReferences
    extends BaseReferences<_$AppDatabase, $PlannerTasksTable, PlannerTaskRow> {
  $$PlannerTasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('planner_tasks__profile_id__local_profiles__id');

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

  static MultiTypedResultKey<$TaskStatusChangesTable, List<TaskStatusChangeRow>>
  _taskStatusChangesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.taskStatusChanges,
        aliasName: 'planner_tasks__id__task_status_changes__task_id',
      );

  $$TaskStatusChangesTableProcessedTableManager get taskStatusChangesRefs {
    final manager = $$TaskStatusChangesTableTableManager(
      $_db,
      $_db.taskStatusChanges,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _taskStatusChangesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlannerTasksTableFilterComposer
    extends Composer<_$AppDatabase, $PlannerTasksTable> {
  $$PlannerTasksTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
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

  Expression<bool> taskStatusChangesRefs(
    Expression<bool> Function($$TaskStatusChangesTableFilterComposer f) f,
  ) {
    final $$TaskStatusChangesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskStatusChanges,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskStatusChangesTableFilterComposer(
            $db: $db,
            $table: $db.taskStatusChanges,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlannerTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlannerTasksTable> {
  $$PlannerTasksTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
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

class $$PlannerTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlannerTasksTable> {
  $$PlannerTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
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

  Expression<T> taskStatusChangesRefs<T extends Object>(
    Expression<T> Function($$TaskStatusChangesTableAnnotationComposer a) f,
  ) {
    final $$TaskStatusChangesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.taskStatusChanges,
          getReferencedColumn: (t) => t.taskId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TaskStatusChangesTableAnnotationComposer(
                $db: $db,
                $table: $db.taskStatusChanges,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlannerTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlannerTasksTable,
          PlannerTaskRow,
          $$PlannerTasksTableFilterComposer,
          $$PlannerTasksTableOrderingComposer,
          $$PlannerTasksTableAnnotationComposer,
          $$PlannerTasksTableCreateCompanionBuilder,
          $$PlannerTasksTableUpdateCompanionBuilder,
          (PlannerTaskRow, $$PlannerTasksTableReferences),
          PlannerTaskRow,
          PrefetchHooks Function({bool profileId, bool taskStatusChangesRefs})
        > {
  $$PlannerTasksTableTableManager(_$AppDatabase db, $PlannerTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlannerTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlannerTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlannerTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> requiresReport = const Value.absent(),
                Value<String?> contributionRuleKey = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlannerTasksCompanion(
                id: id,
                profileId: profileId,
                title: title,
                notes: notes,
                dueDate: dueDate,
                status: status,
                requiresReport: requiresReport,
                contributionRuleKey: contributionRuleKey,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<String?> dueDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> requiresReport = const Value.absent(),
                Value<String?> contributionRuleKey = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PlannerTasksCompanion.insert(
                id: id,
                profileId: profileId,
                title: title,
                notes: notes,
                dueDate: dueDate,
                status: status,
                requiresReport: requiresReport,
                contributionRuleKey: contributionRuleKey,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlannerTasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({profileId = false, taskStatusChangesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskStatusChangesRefs) db.taskStatusChanges,
                  ],
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
                                        $$PlannerTasksTableReferences
                                            ._profileIdTable(db),
                                    referencedColumn:
                                        $$PlannerTasksTableReferences
                                            ._profileIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskStatusChangesRefs)
                        await $_getPrefetchedData<
                          PlannerTaskRow,
                          $PlannerTasksTable,
                          TaskStatusChangeRow
                        >(
                          currentTable: table,
                          referencedTable: $$PlannerTasksTableReferences
                              ._taskStatusChangesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlannerTasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskStatusChangesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlannerTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlannerTasksTable,
      PlannerTaskRow,
      $$PlannerTasksTableFilterComposer,
      $$PlannerTasksTableOrderingComposer,
      $$PlannerTasksTableAnnotationComposer,
      $$PlannerTasksTableCreateCompanionBuilder,
      $$PlannerTasksTableUpdateCompanionBuilder,
      (PlannerTaskRow, $$PlannerTasksTableReferences),
      PlannerTaskRow,
      PrefetchHooks Function({bool profileId, bool taskStatusChangesRefs})
    >;
typedef $$TaskStatusChangesTableCreateCompanionBuilder =
    TaskStatusChangesCompanion Function({
      required String id,
      required String profileId,
      required String taskId,
      required String operationId,
      required String fromStatus,
      required String toStatus,
      Value<String?> reason,
      required DateTime changedAtUtc,
      Value<int> rowid,
    });
typedef $$TaskStatusChangesTableUpdateCompanionBuilder =
    TaskStatusChangesCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> taskId,
      Value<String> operationId,
      Value<String> fromStatus,
      Value<String> toStatus,
      Value<String?> reason,
      Value<DateTime> changedAtUtc,
      Value<int> rowid,
    });

final class $$TaskStatusChangesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TaskStatusChangesTable,
          TaskStatusChangeRow
        > {
  $$TaskStatusChangesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('task_status_changes__profile_id__local_profiles__id');

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

  static $PlannerTasksTable _taskIdTable(_$AppDatabase db) => db.plannerTasks
      .createAlias('task_status_changes__task_id__planner_tasks__id');

  $$PlannerTasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$PlannerTasksTableTableManager(
      $_db,
      $_db.plannerTasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskStatusChangesTableFilterComposer
    extends Composer<_$AppDatabase, $TaskStatusChangesTable> {
  $$TaskStatusChangesTableFilterComposer({
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

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAtUtc => $composableBuilder(
    column: $table.changedAtUtc,
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

  $$PlannerTasksTableFilterComposer get taskId {
    final $$PlannerTasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.plannerTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlannerTasksTableFilterComposer(
            $db: $db,
            $table: $db.plannerTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskStatusChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskStatusChangesTable> {
  $$TaskStatusChangesTableOrderingComposer({
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

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAtUtc => $composableBuilder(
    column: $table.changedAtUtc,
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

  $$PlannerTasksTableOrderingComposer get taskId {
    final $$PlannerTasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.plannerTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlannerTasksTableOrderingComposer(
            $db: $db,
            $table: $db.plannerTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskStatusChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskStatusChangesTable> {
  $$TaskStatusChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toStatus =>
      $composableBuilder(column: $table.toStatus, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAtUtc => $composableBuilder(
    column: $table.changedAtUtc,
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

  $$PlannerTasksTableAnnotationComposer get taskId {
    final $$PlannerTasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.plannerTasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlannerTasksTableAnnotationComposer(
            $db: $db,
            $table: $db.plannerTasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskStatusChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskStatusChangesTable,
          TaskStatusChangeRow,
          $$TaskStatusChangesTableFilterComposer,
          $$TaskStatusChangesTableOrderingComposer,
          $$TaskStatusChangesTableAnnotationComposer,
          $$TaskStatusChangesTableCreateCompanionBuilder,
          $$TaskStatusChangesTableUpdateCompanionBuilder,
          (TaskStatusChangeRow, $$TaskStatusChangesTableReferences),
          TaskStatusChangeRow,
          PrefetchHooks Function({bool profileId, bool taskId})
        > {
  $$TaskStatusChangesTableTableManager(
    _$AppDatabase db,
    $TaskStatusChangesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskStatusChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskStatusChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskStatusChangesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> fromStatus = const Value.absent(),
                Value<String> toStatus = const Value.absent(),
                Value<String?> reason = const Value.absent(),
                Value<DateTime> changedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskStatusChangesCompanion(
                id: id,
                profileId: profileId,
                taskId: taskId,
                operationId: operationId,
                fromStatus: fromStatus,
                toStatus: toStatus,
                reason: reason,
                changedAtUtc: changedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String taskId,
                required String operationId,
                required String fromStatus,
                required String toStatus,
                Value<String?> reason = const Value.absent(),
                required DateTime changedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => TaskStatusChangesCompanion.insert(
                id: id,
                profileId: profileId,
                taskId: taskId,
                operationId: operationId,
                fromStatus: fromStatus,
                toStatus: toStatus,
                reason: reason,
                changedAtUtc: changedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskStatusChangesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, taskId = false}) {
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
                                    $$TaskStatusChangesTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$TaskStatusChangesTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable:
                                    $$TaskStatusChangesTableReferences
                                        ._taskIdTable(db),
                                referencedColumn:
                                    $$TaskStatusChangesTableReferences
                                        ._taskIdTable(db)
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

typedef $$TaskStatusChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskStatusChangesTable,
      TaskStatusChangeRow,
      $$TaskStatusChangesTableFilterComposer,
      $$TaskStatusChangesTableOrderingComposer,
      $$TaskStatusChangesTableAnnotationComposer,
      $$TaskStatusChangesTableCreateCompanionBuilder,
      $$TaskStatusChangesTableUpdateCompanionBuilder,
      (TaskStatusChangeRow, $$TaskStatusChangesTableReferences),
      TaskStatusChangeRow,
      PrefetchHooks Function({bool profileId, bool taskId})
    >;
typedef $$CalendarEventsTableCreateCompanionBuilder =
    CalendarEventsCompanion Function({
      required String id,
      required String profileId,
      required String title,
      Value<String?> notes,
      required String timing,
      required String startDate,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<String?> timeZoneId,
      Value<String?> locationText,
      Value<bool> requiresReport,
      Value<String?> contributionRuleKey,
      Value<String> recurrenceFrequency,
      Value<String> recurrenceEndMode,
      Value<String?> recurrenceEndDate,
      Value<int?> recurrenceCount,
      Value<String> status,
      Value<String?> parentEventId,
      Value<String?> replacementEventId,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$CalendarEventsTableUpdateCompanionBuilder =
    CalendarEventsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> title,
      Value<String?> notes,
      Value<String> timing,
      Value<String> startDate,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<String?> timeZoneId,
      Value<String?> locationText,
      Value<bool> requiresReport,
      Value<String?> contributionRuleKey,
      Value<String> recurrenceFrequency,
      Value<String> recurrenceEndMode,
      Value<String?> recurrenceEndDate,
      Value<int?> recurrenceCount,
      Value<String> status,
      Value<String?> parentEventId,
      Value<String?> replacementEventId,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$CalendarEventsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CalendarEventsTable, CalendarEventRow> {
  $$CalendarEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('calendar_events__profile_id__local_profiles__id');

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

  static MultiTypedResultKey<
    $CalendarEventExceptionsTable,
    List<CalendarEventExceptionRow>
  >
  _calendarEventExceptionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calendarEventExceptions,
        aliasName: 'calendar_events__id__calendar_event_exceptions__event_id',
      );

  $$CalendarEventExceptionsTableProcessedTableManager
  get calendarEventExceptionsRefs {
    final manager = $$CalendarEventExceptionsTableTableManager(
      $_db,
      $_db.calendarEventExceptions,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calendarEventExceptionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CalendarEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationText => $composableBuilder(
    column: $table.locationText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceFrequency => $composableBuilder(
    column: $table.recurrenceFrequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceEndMode => $composableBuilder(
    column: $table.recurrenceEndMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentEventId => $composableBuilder(
    column: $table.parentEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replacementEventId => $composableBuilder(
    column: $table.replacementEventId,
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

  Expression<bool> calendarEventExceptionsRefs(
    Expression<bool> Function($$CalendarEventExceptionsTableFilterComposer f) f,
  ) {
    final $$CalendarEventExceptionsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventExceptions,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventExceptionsTableFilterComposer(
                $db: $db,
                $table: $db.calendarEventExceptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CalendarEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationText => $composableBuilder(
    column: $table.locationText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceFrequency => $composableBuilder(
    column: $table.recurrenceFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceEndMode => $composableBuilder(
    column: $table.recurrenceEndMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentEventId => $composableBuilder(
    column: $table.parentEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replacementEventId => $composableBuilder(
    column: $table.replacementEventId,
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

class $$CalendarEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get timing =>
      $composableBuilder(column: $table.timing, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationText => $composableBuilder(
    column: $table.locationText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceFrequency => $composableBuilder(
    column: $table.recurrenceFrequency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceEndMode => $composableBuilder(
    column: $table.recurrenceEndMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recurrenceEndDate => $composableBuilder(
    column: $table.recurrenceEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get recurrenceCount => $composableBuilder(
    column: $table.recurrenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get parentEventId => $composableBuilder(
    column: $table.parentEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get replacementEventId => $composableBuilder(
    column: $table.replacementEventId,
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

  Expression<T> calendarEventExceptionsRefs<T extends Object>(
    Expression<T> Function($$CalendarEventExceptionsTableAnnotationComposer a)
    f,
  ) {
    final $$CalendarEventExceptionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calendarEventExceptions,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalendarEventExceptionsTableAnnotationComposer(
                $db: $db,
                $table: $db.calendarEventExceptions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CalendarEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventsTable,
          CalendarEventRow,
          $$CalendarEventsTableFilterComposer,
          $$CalendarEventsTableOrderingComposer,
          $$CalendarEventsTableAnnotationComposer,
          $$CalendarEventsTableCreateCompanionBuilder,
          $$CalendarEventsTableUpdateCompanionBuilder,
          (CalendarEventRow, $$CalendarEventsTableReferences),
          CalendarEventRow,
          PrefetchHooks Function({
            bool profileId,
            bool calendarEventExceptionsRefs,
          })
        > {
  $$CalendarEventsTableTableManager(
    _$AppDatabase db,
    $CalendarEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> timing = const Value.absent(),
                Value<String> startDate = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String?> timeZoneId = const Value.absent(),
                Value<String?> locationText = const Value.absent(),
                Value<bool> requiresReport = const Value.absent(),
                Value<String?> contributionRuleKey = const Value.absent(),
                Value<String> recurrenceFrequency = const Value.absent(),
                Value<String> recurrenceEndMode = const Value.absent(),
                Value<String?> recurrenceEndDate = const Value.absent(),
                Value<int?> recurrenceCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> parentEventId = const Value.absent(),
                Value<String?> replacementEventId = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventsCompanion(
                id: id,
                profileId: profileId,
                title: title,
                notes: notes,
                timing: timing,
                startDate: startDate,
                startMinute: startMinute,
                endMinute: endMinute,
                timeZoneId: timeZoneId,
                locationText: locationText,
                requiresReport: requiresReport,
                contributionRuleKey: contributionRuleKey,
                recurrenceFrequency: recurrenceFrequency,
                recurrenceEndMode: recurrenceEndMode,
                recurrenceEndDate: recurrenceEndDate,
                recurrenceCount: recurrenceCount,
                status: status,
                parentEventId: parentEventId,
                replacementEventId: replacementEventId,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String title,
                Value<String?> notes = const Value.absent(),
                required String timing,
                required String startDate,
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String?> timeZoneId = const Value.absent(),
                Value<String?> locationText = const Value.absent(),
                Value<bool> requiresReport = const Value.absent(),
                Value<String?> contributionRuleKey = const Value.absent(),
                Value<String> recurrenceFrequency = const Value.absent(),
                Value<String> recurrenceEndMode = const Value.absent(),
                Value<String?> recurrenceEndDate = const Value.absent(),
                Value<int?> recurrenceCount = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> parentEventId = const Value.absent(),
                Value<String?> replacementEventId = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventsCompanion.insert(
                id: id,
                profileId: profileId,
                title: title,
                notes: notes,
                timing: timing,
                startDate: startDate,
                startMinute: startMinute,
                endMinute: endMinute,
                timeZoneId: timeZoneId,
                locationText: locationText,
                requiresReport: requiresReport,
                contributionRuleKey: contributionRuleKey,
                recurrenceFrequency: recurrenceFrequency,
                recurrenceEndMode: recurrenceEndMode,
                recurrenceEndDate: recurrenceEndDate,
                recurrenceCount: recurrenceCount,
                status: status,
                parentEventId: parentEventId,
                replacementEventId: replacementEventId,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({profileId = false, calendarEventExceptionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (calendarEventExceptionsRefs) db.calendarEventExceptions,
                  ],
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
                                        $$CalendarEventsTableReferences
                                            ._profileIdTable(db),
                                    referencedColumn:
                                        $$CalendarEventsTableReferences
                                            ._profileIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (calendarEventExceptionsRefs)
                        await $_getPrefetchedData<
                          CalendarEventRow,
                          $CalendarEventsTable,
                          CalendarEventExceptionRow
                        >(
                          currentTable: table,
                          referencedTable: $$CalendarEventsTableReferences
                              ._calendarEventExceptionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CalendarEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).calendarEventExceptionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CalendarEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventsTable,
      CalendarEventRow,
      $$CalendarEventsTableFilterComposer,
      $$CalendarEventsTableOrderingComposer,
      $$CalendarEventsTableAnnotationComposer,
      $$CalendarEventsTableCreateCompanionBuilder,
      $$CalendarEventsTableUpdateCompanionBuilder,
      (CalendarEventRow, $$CalendarEventsTableReferences),
      CalendarEventRow,
      PrefetchHooks Function({bool profileId, bool calendarEventExceptionsRefs})
    >;
typedef $$CalendarEventExceptionsTableCreateCompanionBuilder =
    CalendarEventExceptionsCompanion Function({
      required String id,
      required String profileId,
      required String eventId,
      required String occurrenceId,
      required String originalDate,
      required String effectiveDate,
      required String title,
      Value<String?> notes,
      required String timing,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<String?> timeZoneId,
      Value<String?> locationText,
      Value<bool> requiresReport,
      Value<String?> contributionRuleKey,
      required String status,
      Value<String?> replacementEventId,
      required DateTime createdAtUtc,
      Value<int> rowid,
    });
typedef $$CalendarEventExceptionsTableUpdateCompanionBuilder =
    CalendarEventExceptionsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> eventId,
      Value<String> occurrenceId,
      Value<String> originalDate,
      Value<String> effectiveDate,
      Value<String> title,
      Value<String?> notes,
      Value<String> timing,
      Value<int?> startMinute,
      Value<int?> endMinute,
      Value<String?> timeZoneId,
      Value<String?> locationText,
      Value<bool> requiresReport,
      Value<String?> contributionRuleKey,
      Value<String> status,
      Value<String?> replacementEventId,
      Value<DateTime> createdAtUtc,
      Value<int> rowid,
    });

final class $$CalendarEventExceptionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalendarEventExceptionsTable,
          CalendarEventExceptionRow
        > {
  $$CalendarEventExceptionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('calendar_event_exceptions__profile_id__local_profiles__id');

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

  static $CalendarEventsTable _eventIdTable(_$AppDatabase db) => db
      .calendarEvents
      .createAlias('calendar_event_exceptions__event_id__calendar_events__id');

  $$CalendarEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$CalendarEventsTableTableManager(
      $_db,
      $_db.calendarEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CalendarEventExceptionsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventExceptionsTable> {
  $$CalendarEventExceptionsTableFilterComposer({
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

  ColumnFilters<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveDate => $composableBuilder(
    column: $table.effectiveDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationText => $composableBuilder(
    column: $table.locationText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get replacementEventId => $composableBuilder(
    column: $table.replacementEventId,
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

  $$CalendarEventsTableFilterComposer get eventId {
    final $$CalendarEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableFilterComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventExceptionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventExceptionsTable> {
  $$CalendarEventExceptionsTableOrderingComposer({
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

  ColumnOrderings<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveDate => $composableBuilder(
    column: $table.effectiveDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timing => $composableBuilder(
    column: $table.timing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMinute => $composableBuilder(
    column: $table.endMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationText => $composableBuilder(
    column: $table.locationText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get replacementEventId => $composableBuilder(
    column: $table.replacementEventId,
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

  $$CalendarEventsTableOrderingComposer get eventId {
    final $$CalendarEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableOrderingComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventExceptionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventExceptionsTable> {
  $$CalendarEventExceptionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveDate => $composableBuilder(
    column: $table.effectiveDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get timing =>
      $composableBuilder(column: $table.timing, builder: (column) => column);

  GeneratedColumn<int> get startMinute => $composableBuilder(
    column: $table.startMinute,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMinute =>
      $composableBuilder(column: $table.endMinute, builder: (column) => column);

  GeneratedColumn<String> get timeZoneId => $composableBuilder(
    column: $table.timeZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locationText => $composableBuilder(
    column: $table.locationText,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresReport => $composableBuilder(
    column: $table.requiresReport,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contributionRuleKey => $composableBuilder(
    column: $table.contributionRuleKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get replacementEventId => $composableBuilder(
    column: $table.replacementEventId,
    builder: (column) => column,
  );

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

  $$CalendarEventsTableAnnotationComposer get eventId {
    final $$CalendarEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.calendarEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalendarEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.calendarEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalendarEventExceptionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventExceptionsTable,
          CalendarEventExceptionRow,
          $$CalendarEventExceptionsTableFilterComposer,
          $$CalendarEventExceptionsTableOrderingComposer,
          $$CalendarEventExceptionsTableAnnotationComposer,
          $$CalendarEventExceptionsTableCreateCompanionBuilder,
          $$CalendarEventExceptionsTableUpdateCompanionBuilder,
          (CalendarEventExceptionRow, $$CalendarEventExceptionsTableReferences),
          CalendarEventExceptionRow,
          PrefetchHooks Function({bool profileId, bool eventId})
        > {
  $$CalendarEventExceptionsTableTableManager(
    _$AppDatabase db,
    $CalendarEventExceptionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventExceptionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CalendarEventExceptionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarEventExceptionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> occurrenceId = const Value.absent(),
                Value<String> originalDate = const Value.absent(),
                Value<String> effectiveDate = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> timing = const Value.absent(),
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String?> timeZoneId = const Value.absent(),
                Value<String?> locationText = const Value.absent(),
                Value<bool> requiresReport = const Value.absent(),
                Value<String?> contributionRuleKey = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> replacementEventId = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventExceptionsCompanion(
                id: id,
                profileId: profileId,
                eventId: eventId,
                occurrenceId: occurrenceId,
                originalDate: originalDate,
                effectiveDate: effectiveDate,
                title: title,
                notes: notes,
                timing: timing,
                startMinute: startMinute,
                endMinute: endMinute,
                timeZoneId: timeZoneId,
                locationText: locationText,
                requiresReport: requiresReport,
                contributionRuleKey: contributionRuleKey,
                status: status,
                replacementEventId: replacementEventId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String eventId,
                required String occurrenceId,
                required String originalDate,
                required String effectiveDate,
                required String title,
                Value<String?> notes = const Value.absent(),
                required String timing,
                Value<int?> startMinute = const Value.absent(),
                Value<int?> endMinute = const Value.absent(),
                Value<String?> timeZoneId = const Value.absent(),
                Value<String?> locationText = const Value.absent(),
                Value<bool> requiresReport = const Value.absent(),
                Value<String?> contributionRuleKey = const Value.absent(),
                required String status,
                Value<String?> replacementEventId = const Value.absent(),
                required DateTime createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventExceptionsCompanion.insert(
                id: id,
                profileId: profileId,
                eventId: eventId,
                occurrenceId: occurrenceId,
                originalDate: originalDate,
                effectiveDate: effectiveDate,
                title: title,
                notes: notes,
                timing: timing,
                startMinute: startMinute,
                endMinute: endMinute,
                timeZoneId: timeZoneId,
                locationText: locationText,
                requiresReport: requiresReport,
                contributionRuleKey: contributionRuleKey,
                status: status,
                replacementEventId: replacementEventId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarEventExceptionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({profileId = false, eventId = false}) {
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
                                    $$CalendarEventExceptionsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$CalendarEventExceptionsTableReferences
                                        ._profileIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable:
                                    $$CalendarEventExceptionsTableReferences
                                        ._eventIdTable(db),
                                referencedColumn:
                                    $$CalendarEventExceptionsTableReferences
                                        ._eventIdTable(db)
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

typedef $$CalendarEventExceptionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventExceptionsTable,
      CalendarEventExceptionRow,
      $$CalendarEventExceptionsTableFilterComposer,
      $$CalendarEventExceptionsTableOrderingComposer,
      $$CalendarEventExceptionsTableAnnotationComposer,
      $$CalendarEventExceptionsTableCreateCompanionBuilder,
      $$CalendarEventExceptionsTableUpdateCompanionBuilder,
      (CalendarEventExceptionRow, $$CalendarEventExceptionsTableReferences),
      CalendarEventExceptionRow,
      PrefetchHooks Function({bool profileId, bool eventId})
    >;
typedef $$CalendarEventOperationsTableCreateCompanionBuilder =
    CalendarEventOperationsCompanion Function({
      required String operationId,
      required String profileId,
      required String eventId,
      Value<String?> occurrenceId,
      required String command,
      required DateTime createdAtUtc,
      Value<int> rowid,
    });
typedef $$CalendarEventOperationsTableUpdateCompanionBuilder =
    CalendarEventOperationsCompanion Function({
      Value<String> operationId,
      Value<String> profileId,
      Value<String> eventId,
      Value<String?> occurrenceId,
      Value<String> command,
      Value<DateTime> createdAtUtc,
      Value<int> rowid,
    });

final class $$CalendarEventOperationsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalendarEventOperationsTable,
          CalendarEventOperationRow
        > {
  $$CalendarEventOperationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('calendar_event_operations__profile_id__local_profiles__id');

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

class $$CalendarEventOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventOperationsTable> {
  $$CalendarEventOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get command => $composableBuilder(
    column: $table.command,
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

class $$CalendarEventOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventOperationsTable> {
  $$CalendarEventOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get command => $composableBuilder(
    column: $table.command,
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

class $$CalendarEventOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventOperationsTable> {
  $$CalendarEventOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get command =>
      $composableBuilder(column: $table.command, builder: (column) => column);

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

class $$CalendarEventOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalendarEventOperationsTable,
          CalendarEventOperationRow,
          $$CalendarEventOperationsTableFilterComposer,
          $$CalendarEventOperationsTableOrderingComposer,
          $$CalendarEventOperationsTableAnnotationComposer,
          $$CalendarEventOperationsTableCreateCompanionBuilder,
          $$CalendarEventOperationsTableUpdateCompanionBuilder,
          (CalendarEventOperationRow, $$CalendarEventOperationsTableReferences),
          CalendarEventOperationRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$CalendarEventOperationsTableTableManager(
    _$AppDatabase db,
    $CalendarEventOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventOperationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CalendarEventOperationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalendarEventOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String?> occurrenceId = const Value.absent(),
                Value<String> command = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventOperationsCompanion(
                operationId: operationId,
                profileId: profileId,
                eventId: eventId,
                occurrenceId: occurrenceId,
                command: command,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String profileId,
                required String eventId,
                Value<String?> occurrenceId = const Value.absent(),
                required String command,
                required DateTime createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => CalendarEventOperationsCompanion.insert(
                operationId: operationId,
                profileId: profileId,
                eventId: eventId,
                occurrenceId: occurrenceId,
                command: command,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CalendarEventOperationsTableReferences(db, table, e),
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
                                    $$CalendarEventOperationsTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$CalendarEventOperationsTableReferences
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

typedef $$CalendarEventOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalendarEventOperationsTable,
      CalendarEventOperationRow,
      $$CalendarEventOperationsTableFilterComposer,
      $$CalendarEventOperationsTableOrderingComposer,
      $$CalendarEventOperationsTableAnnotationComposer,
      $$CalendarEventOperationsTableCreateCompanionBuilder,
      $$CalendarEventOperationsTableUpdateCompanionBuilder,
      (CalendarEventOperationRow, $$CalendarEventOperationsTableReferences),
      CalendarEventOperationRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$TaskEventLinksTableCreateCompanionBuilder =
    TaskEventLinksCompanion Function({
      required String id,
      required String profileId,
      required String taskId,
      required String eventId,
      required String scope,
      required String targetKey,
      Value<String?> occurrenceId,
      Value<String?> originalDate,
      Value<String> status,
      required String canonicalSource,
      Value<String?> transferredFromLinkId,
      required DateTime createdAtUtc,
      required DateTime updatedAtUtc,
      Value<int> rowid,
    });
typedef $$TaskEventLinksTableUpdateCompanionBuilder =
    TaskEventLinksCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> taskId,
      Value<String> eventId,
      Value<String> scope,
      Value<String> targetKey,
      Value<String?> occurrenceId,
      Value<String?> originalDate,
      Value<String> status,
      Value<String> canonicalSource,
      Value<String?> transferredFromLinkId,
      Value<DateTime> createdAtUtc,
      Value<DateTime> updatedAtUtc,
      Value<int> rowid,
    });

final class $$TaskEventLinksTableReferences
    extends
        BaseReferences<_$AppDatabase, $TaskEventLinksTable, TaskEventLinkRow> {
  $$TaskEventLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('task_event_links__profile_id__local_profiles__id');

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

class $$TaskEventLinksTableFilterComposer
    extends Composer<_$AppDatabase, $TaskEventLinksTable> {
  $$TaskEventLinksTableFilterComposer({
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

  ColumnFilters<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalSource => $composableBuilder(
    column: $table.canonicalSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferredFromLinkId => $composableBuilder(
    column: $table.transferredFromLinkId,
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

class $$TaskEventLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskEventLinksTable> {
  $$TaskEventLinksTableOrderingComposer({
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

  ColumnOrderings<String> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalSource => $composableBuilder(
    column: $table.canonicalSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferredFromLinkId => $composableBuilder(
    column: $table.transferredFromLinkId,
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

class $$TaskEventLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskEventLinksTable> {
  $$TaskEventLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get targetKey =>
      $composableBuilder(column: $table.targetKey, builder: (column) => column);

  GeneratedColumn<String> get occurrenceId => $composableBuilder(
    column: $table.occurrenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalDate => $composableBuilder(
    column: $table.originalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get canonicalSource => $composableBuilder(
    column: $table.canonicalSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transferredFromLinkId => $composableBuilder(
    column: $table.transferredFromLinkId,
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

class $$TaskEventLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskEventLinksTable,
          TaskEventLinkRow,
          $$TaskEventLinksTableFilterComposer,
          $$TaskEventLinksTableOrderingComposer,
          $$TaskEventLinksTableAnnotationComposer,
          $$TaskEventLinksTableCreateCompanionBuilder,
          $$TaskEventLinksTableUpdateCompanionBuilder,
          (TaskEventLinkRow, $$TaskEventLinksTableReferences),
          TaskEventLinkRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$TaskEventLinksTableTableManager(
    _$AppDatabase db,
    $TaskEventLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskEventLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskEventLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskEventLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> targetKey = const Value.absent(),
                Value<String?> occurrenceId = const Value.absent(),
                Value<String?> originalDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> canonicalSource = const Value.absent(),
                Value<String?> transferredFromLinkId = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<DateTime> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskEventLinksCompanion(
                id: id,
                profileId: profileId,
                taskId: taskId,
                eventId: eventId,
                scope: scope,
                targetKey: targetKey,
                occurrenceId: occurrenceId,
                originalDate: originalDate,
                status: status,
                canonicalSource: canonicalSource,
                transferredFromLinkId: transferredFromLinkId,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String taskId,
                required String eventId,
                required String scope,
                required String targetKey,
                Value<String?> occurrenceId = const Value.absent(),
                Value<String?> originalDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String canonicalSource,
                Value<String?> transferredFromLinkId = const Value.absent(),
                required DateTime createdAtUtc,
                required DateTime updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => TaskEventLinksCompanion.insert(
                id: id,
                profileId: profileId,
                taskId: taskId,
                eventId: eventId,
                scope: scope,
                targetKey: targetKey,
                occurrenceId: occurrenceId,
                originalDate: originalDate,
                status: status,
                canonicalSource: canonicalSource,
                transferredFromLinkId: transferredFromLinkId,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskEventLinksTableReferences(db, table, e),
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
                                referencedTable: $$TaskEventLinksTableReferences
                                    ._profileIdTable(db),
                                referencedColumn:
                                    $$TaskEventLinksTableReferences
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

typedef $$TaskEventLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskEventLinksTable,
      TaskEventLinkRow,
      $$TaskEventLinksTableFilterComposer,
      $$TaskEventLinksTableOrderingComposer,
      $$TaskEventLinksTableAnnotationComposer,
      $$TaskEventLinksTableCreateCompanionBuilder,
      $$TaskEventLinksTableUpdateCompanionBuilder,
      (TaskEventLinkRow, $$TaskEventLinksTableReferences),
      TaskEventLinkRow,
      PrefetchHooks Function({bool profileId})
    >;
typedef $$TaskEventLinkHistoryTableCreateCompanionBuilder =
    TaskEventLinkHistoryCompanion Function({
      required String id,
      required String profileId,
      required String linkId,
      required String operationId,
      required String action,
      Value<String?> fromStatus,
      required String toStatus,
      Value<String?> relatedLinkId,
      required DateTime createdAtUtc,
      Value<int> rowid,
    });
typedef $$TaskEventLinkHistoryTableUpdateCompanionBuilder =
    TaskEventLinkHistoryCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> linkId,
      Value<String> operationId,
      Value<String> action,
      Value<String?> fromStatus,
      Value<String> toStatus,
      Value<String?> relatedLinkId,
      Value<DateTime> createdAtUtc,
      Value<int> rowid,
    });

final class $$TaskEventLinkHistoryTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TaskEventLinkHistoryTable,
          TaskEventLinkHistoryRow
        > {
  $$TaskEventLinkHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LocalProfilesTable _profileIdTable(_$AppDatabase db) => db
      .localProfiles
      .createAlias('task_event_link_history__profile_id__local_profiles__id');

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

class $$TaskEventLinkHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $TaskEventLinkHistoryTable> {
  $$TaskEventLinkHistoryTableFilterComposer({
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

  ColumnFilters<String> get linkId => $composableBuilder(
    column: $table.linkId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedLinkId => $composableBuilder(
    column: $table.relatedLinkId,
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

class $$TaskEventLinkHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskEventLinkHistoryTable> {
  $$TaskEventLinkHistoryTableOrderingComposer({
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

  ColumnOrderings<String> get linkId => $composableBuilder(
    column: $table.linkId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStatus => $composableBuilder(
    column: $table.toStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedLinkId => $composableBuilder(
    column: $table.relatedLinkId,
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

class $$TaskEventLinkHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskEventLinkHistoryTable> {
  $$TaskEventLinkHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get linkId =>
      $composableBuilder(column: $table.linkId, builder: (column) => column);

  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get fromStatus => $composableBuilder(
    column: $table.fromStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toStatus =>
      $composableBuilder(column: $table.toStatus, builder: (column) => column);

  GeneratedColumn<String> get relatedLinkId => $composableBuilder(
    column: $table.relatedLinkId,
    builder: (column) => column,
  );

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

class $$TaskEventLinkHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskEventLinkHistoryTable,
          TaskEventLinkHistoryRow,
          $$TaskEventLinkHistoryTableFilterComposer,
          $$TaskEventLinkHistoryTableOrderingComposer,
          $$TaskEventLinkHistoryTableAnnotationComposer,
          $$TaskEventLinkHistoryTableCreateCompanionBuilder,
          $$TaskEventLinkHistoryTableUpdateCompanionBuilder,
          (TaskEventLinkHistoryRow, $$TaskEventLinkHistoryTableReferences),
          TaskEventLinkHistoryRow,
          PrefetchHooks Function({bool profileId})
        > {
  $$TaskEventLinkHistoryTableTableManager(
    _$AppDatabase db,
    $TaskEventLinkHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskEventLinkHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskEventLinkHistoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TaskEventLinkHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> linkId = const Value.absent(),
                Value<String> operationId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> fromStatus = const Value.absent(),
                Value<String> toStatus = const Value.absent(),
                Value<String?> relatedLinkId = const Value.absent(),
                Value<DateTime> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskEventLinkHistoryCompanion(
                id: id,
                profileId: profileId,
                linkId: linkId,
                operationId: operationId,
                action: action,
                fromStatus: fromStatus,
                toStatus: toStatus,
                relatedLinkId: relatedLinkId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String linkId,
                required String operationId,
                required String action,
                Value<String?> fromStatus = const Value.absent(),
                required String toStatus,
                Value<String?> relatedLinkId = const Value.absent(),
                required DateTime createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => TaskEventLinkHistoryCompanion.insert(
                id: id,
                profileId: profileId,
                linkId: linkId,
                operationId: operationId,
                action: action,
                fromStatus: fromStatus,
                toStatus: toStatus,
                relatedLinkId: relatedLinkId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskEventLinkHistoryTableReferences(db, table, e),
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
                                    $$TaskEventLinkHistoryTableReferences
                                        ._profileIdTable(db),
                                referencedColumn:
                                    $$TaskEventLinkHistoryTableReferences
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

typedef $$TaskEventLinkHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskEventLinkHistoryTable,
      TaskEventLinkHistoryRow,
      $$TaskEventLinkHistoryTableFilterComposer,
      $$TaskEventLinkHistoryTableOrderingComposer,
      $$TaskEventLinkHistoryTableAnnotationComposer,
      $$TaskEventLinkHistoryTableCreateCompanionBuilder,
      $$TaskEventLinkHistoryTableUpdateCompanionBuilder,
      (TaskEventLinkHistoryRow, $$TaskEventLinkHistoryTableReferences),
      TaskEventLinkHistoryRow,
      PrefetchHooks Function({bool profileId})
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
  $$PlannerTasksTableTableManager get plannerTasks =>
      $$PlannerTasksTableTableManager(_db, _db.plannerTasks);
  $$TaskStatusChangesTableTableManager get taskStatusChanges =>
      $$TaskStatusChangesTableTableManager(_db, _db.taskStatusChanges);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(_db, _db.calendarEvents);
  $$CalendarEventExceptionsTableTableManager get calendarEventExceptions =>
      $$CalendarEventExceptionsTableTableManager(
        _db,
        _db.calendarEventExceptions,
      );
  $$CalendarEventOperationsTableTableManager get calendarEventOperations =>
      $$CalendarEventOperationsTableTableManager(
        _db,
        _db.calendarEventOperations,
      );
  $$TaskEventLinksTableTableManager get taskEventLinks =>
      $$TaskEventLinksTableTableManager(_db, _db.taskEventLinks);
  $$TaskEventLinkHistoryTableTableManager get taskEventLinkHistory =>
      $$TaskEventLinkHistoryTableTableManager(_db, _db.taskEventLinkHistory);
}
