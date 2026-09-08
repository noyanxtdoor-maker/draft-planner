import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/colors/vs11_color_system.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';

import '../../../support/test_dependencies.dart';

void main() {
  late AppDatabase database;
  late DriftEventTypeRepository repository;
  late String profileId;

  setUp(() async {
    database = openMemoryDatabase();
    profileId = (await buildTestRepository(database: database)
            .completeOnboarding())
        .id;
    repository = DriftEventTypeRepository(
      database: database,
      clock: FixedClock(DateTime.utc(2026, 8, 26, 12)),
    );
  });

  tearDown(() => database.close());

  EventTypeDraft draft(String id, String label, int color) => EventTypeDraft(
    id: id,
    label: label,
    icon: EventTypeIcon.calendar,
    colorValue: color,
    reportRequiredDefault: false,
    defaultDurationMinutes: 60,
    indicatorKeys: const <String>{},
  );

  test('active Event Types reject new opaque-RGB duplicates but keep their own current color', () async {
    final first = await repository.saveCustomType(
      profileId: profileId,
      draft: draft('custom-one', 'Custom one', Vs11ColorSystem.p01RoseEmber),
    );
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: first.stableKey,
      preference: const EventColorPreference(
        accentArgb: Vs11ColorSystem.p01RoseEmber,
        surfaceArgb: 0xFF42343B,
      ),
    );

    // Keeping this type's own existing color is compatibility-safe.
    await repository.saveEventColorPreference(
      profileId: profileId,
      eventTypeStableKey: first.stableKey,
      preference: const EventColorPreference(
        accentArgb: Vs11ColorSystem.p01RoseEmber,
        surfaceArgb: 0xFF42343B,
      ),
    );

    await expectLater(
      repository.saveCustomType(
        profileId: profileId,
        draft: draft(
          'custom-two',
          'Custom two',
          0x7F000000 | (Vs11ColorSystem.p01RoseEmber & 0x00FFFFFF),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('Groups do not consume the Event Type color pool', () async {
    final saved = await repository.saveCustomType(
      profileId: profileId,
      draft: draft('custom-event', 'Event color', Vs11ColorSystem.p02DustyCrimson),
    );
    expect(saved.colorValue, Vs11ColorSystem.p02DustyCrimson);
  });
}
