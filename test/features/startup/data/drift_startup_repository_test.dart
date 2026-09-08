import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/startup/domain/life_indicator_seed.dart';
import 'package:rmplanner/features/startup/domain/onboarding_checkpoint.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = openMemoryDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  test('AC-A-001..008,010,014,020: offline onboarding creates one '
      'idempotent Local Profile and six definition-only indicators', () async {
    final repository = buildTestRepository(database: database);

    final checkpoint = await repository.beginOrResumeOnboarding();
    expect(checkpoint.pendingProfileId, '11111111-1111-4111-8111-111111111111');
    await repository.saveOnboardingDraft('  RM Planner  ');

    final firstProfile = await repository.completeOnboarding();
    final secondProfile = await repository.completeOnboarding();
    final profiles = await database.select(database.localProfiles).get();
    final indicators =
        await (database.select(database.lifeIndicatorDefinitions)
              ..orderBy(<OrderingTerm Function(LifeIndicatorDefinitions)>[
                (table) => OrderingTerm(expression: table.position),
              ]))
            .get();

    expect(secondProfile.id, firstProfile.id);
    expect(firstProfile.displayName, 'RM Planner');
    expect(profiles, hasLength(1));
    expect(indicators, hasLength(6));
    expect(
      indicators.map((row) => row.indicatorKey),
      approvedLifeIndicatorSeeds.map((seed) => seed.key),
    );

    final tableRows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
        )
        .get();
    final schemaNames = tableRows.map((row) => row.read<String>('name'));
    expect(schemaNames, isNot(contains('actual_contributions')));
    expect(schemaNames, isNot(contains('ledger_entries')));
  });

  test(
    'AC-A-011..013,016: interrupted onboarding resumes the same stable draft',
    () async {
      final firstRepository = buildTestRepository(database: database);
      final started = await firstRepository.beginOrResumeOnboarding();
      await firstRepository.saveOnboardingDraft('Saved draft');

      final relaunchedRepository = buildTestRepository(
        database: database,
        identifierSource: SequenceIdentifierSource(<String>[
          '22222222-2222-4222-8222-222222222222',
        ]),
      );
      final snapshot = await relaunchedRepository.resolveStartup();
      final resumed = await relaunchedRepository.beginOrResumeOnboarding();

      expect(snapshot.profile, isNull);
      expect(
        snapshot.onboardingCheckpoint?.stage,
        OnboardingStage.profileDraft,
      );
      expect(resumed.pendingProfileId, started.pendingProfileId);
      expect(resumed.draftDisplayName, 'Saved draft');
    },
  );

  test(
    'AC-A-017: optional account and sync state never block valid local data',
    () async {
      final repository = buildTestRepository(database: database);
      await repository.completeOnboarding();

      final snapshot = await repository.resolveStartup();

      expect(snapshot.profile, isNotNull);
      expect(snapshot.accountSessionState, AccountSessionState.localOnly);
      expect(snapshot.syncState, LocalSyncState.notConfigured);
    },
  );

  test(
    'AC-A-015: a blank display name retains the generated local name',
    () async {
      final repository = buildTestRepository(database: database);
      await repository.saveOnboardingDraft('  ');

      final profile = await repository.completeOnboarding();

      expect(profile.displayName, isNull);
      expect(profile.effectiveName, startsWith('Local Profile '));
    },
  );
}
