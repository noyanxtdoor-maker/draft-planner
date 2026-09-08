import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/colors/vs11_color_system.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/contacts/data/drift_contact_repository.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late DriftContactRepository repository;
  late String profileId;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(database: database)
            .completeOnboarding())
        .id;
    repository = DriftContactRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 26, 12)),
      identifiers: UuidIdentifierSource(),
    );
  });

  tearDown(() => database.close());

  test('active Group colors use opaque-RGB uniqueness while legacy duplicates remain readable', () async {
    final family = await repository.createGroup(
      profileId: profileId,
      name: 'Family',
      colorValue: Vs11ColorSystem.p01RoseEmber,
    );

    await expectLater(
      repository.createGroup(
        profileId: profileId,
        name: 'Duplicate',
        colorValue: 0x7F000000 | (Vs11ColorSystem.p01RoseEmber & 0x00FFFFFF),
      ),
      throwsA(isA<ContactValidationException>()),
    );

    // A compatibility duplicate already in storage is left intact, and an
    // edit that keeps its exact current RGB remains permitted.
    await database.into(database.contactGroups).insert(
      ContactGroupsCompanion.insert(
        id: 'legacy-duplicate',
        profileId: profileId,
        name: 'Legacy duplicate',
        colorValue: Vs11ColorSystem.p01RoseEmber,
        createdAtUtc: DateTime.utc(2025, 1, 1),
        updatedAtUtc: DateTime.utc(2025, 1, 1),
      ),
    );
    final retained = await repository.updateGroup(
      profileId: profileId,
      groupId: family.id,
      name: 'Family renamed',
      colorValue: family.colorValue,
    );
    expect(retained.colorValue, family.colorValue);
    expect((await repository.readGroups(profileId)).map((group) => group.id), contains('legacy-duplicate'));
  });

  test('next suggested Group color is deterministic and exhaustion never repeats a canonical swatch', () {
    expect(
      Vs11ColorSystem.nextUnused(<int>[Vs11ColorSystem.p01RoseEmber]),
      Vs11ColorSystem.p02DustyCrimson,
    );
    expect(
      Vs11ColorSystem.nextUnused(
        Vs11ColorSystem.colors.map((color) => color.argb),
      ),
      isNull,
    );
  });
}
