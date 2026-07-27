// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('LocalProfileRow')
class LocalProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get slot =>
      text().withDefault(const Constant('primary')).unique()();
  TextColumn get localName => text()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('OnboardingCheckpointRow')
class OnboardingCheckpoints extends Table {
  TextColumn get key => text().withDefault(const Constant('primary'))();
  TextColumn get pendingProfileId => text()();
  TextColumn get stage => text()();
  TextColumn get draftDisplayName => text().nullable()();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

@TableIndex(
  name: 'life_indicator_profile_key_unique',
  columns: <Symbol>{#profileId, #indicatorKey},
  unique: true,
)
@DataClassName('LifeIndicatorDefinitionRow')
class LifeIndicatorDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId =>
      text().references(LocalProfiles, #id, onDelete: KeyAction.restrict)();
  TextColumn get indicatorKey => text()();
  TextColumn get label => text()();
  TextColumn get unit => text()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    LocalProfiles,
    OnboardingCheckpoints,
    LifeIndicatorDefinitions,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase.defaults()
    : _schemaVersionOverride = null,
      _injectMigrationFailure = false,
      super(driftDatabase(name: 'next_transfer'));

  AppDatabase.forTesting(
    super.executor, {
    int? schemaVersionOverride,
    bool injectMigrationFailure = false,
  }) : _schemaVersionOverride = schemaVersionOverride,
       _injectMigrationFailure = injectMigrationFailure;

  final int? _schemaVersionOverride;
  final bool _injectMigrationFailure;

  @override
  int get schemaVersion => _schemaVersionOverride ?? 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
      },
      onUpgrade: (migrator, from, to) async {
        await transaction(() async {
          if (from < 2 && to >= 2) {
            await customStatement(
              'CREATE TABLE migration_probe (id INTEGER PRIMARY KEY)',
            );
            if (_injectMigrationFailure) {
              throw StateError('Injected migration failure');
            }
          }
        });
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
