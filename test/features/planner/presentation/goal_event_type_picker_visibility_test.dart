import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/theme_color_mode.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/data/drift_event_type_repository.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/event_type_picker_dialog.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/application/startup_repository.dart';

import '../../../support/test_dependencies.dart';

const _profileId = '357caa4f-5383-4cb0-947e-69dc3ef06936';
const _slotOneGoalId = '13c00925-3c47-4fc6-8374-cb6ee5d73d8a';
const _slotTwoGoalId = '7517a22c-5357-43dc-8704-3759ae727203';

final class _FixtureRepositories {
  const _FixtureRepositories({
    required this.database,
    required this.types,
    required this.goals,
    required this.startup,
  });

  final AppDatabase database;
  final DriftEventTypeRepository types;
  final DriftGoalRepository goals;
  final StartupRepository startup;
}

final class _PickerResult {
  EventTypePickerSelection? fullSelection;
  EventType? dropdownSelection;
}

Future<_FixtureRepositories> _copyFixture(String fixture) async {
  final directory = Directory.systemTemp.createTempSync('goal-picker-t06-');
  final copied = File(fixture).copySync('${directory.path}/picker.sqlite');
  final database = AppDatabase.forTesting(NativeDatabase(copied));
  addTearDown(() async {
    await database.close();
    directory.deleteSync(recursive: true);
  });
  final clock = FixedClock(DateTime.utc(2026, 9, 9, 12));
  return _FixtureRepositories(
    database: database,
    types: DriftEventTypeRepository(database: database, clock: clock),
    goals: DriftGoalRepository(
      database: database,
      clock: clock,
      identifiers: const UuidIdentifierSource(),
    ),
    startup: buildTestRepository(database: database),
  );
}

Future<_PickerResult> _pumpHost(
  WidgetTester tester,
  _FixtureRepositories repositories, {
  Size size = const Size(393, 874),
  double textScale = 1,
  String? recommendedEventTypeId,
  Set<String>? allowedStableKeys,
  bool includeTask = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final result = _PickerResult();
  final anchorKey = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        eventTypeRepositoryProvider.overrideWithValue(repositories.types),
        startupRepositoryProvider.overrideWithValue(repositories.startup),
        diagnosticsProvider.overrideWithValue(SanitizedDiagnostics()),
        goalRepositoryProvider.overrideWithValue(repositories.goals),
      ],
      child: MaterialApp(
        theme: AppTheme.light(ThemeColorMode.blue),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(startupControllerProvider);
              return Scaffold(
                body: Column(
                  children: <Widget>[
                    TextButton(
                      key: const Key('open-full-picker'),
                      onPressed: () {
                        unawaited(
                          showEventTypePicker(
                            context: context,
                            ref: ref,
                            recommendedEventTypeId: recommendedEventTypeId,
                            allowedStableKeys: allowedStableKeys,
                            includeTask: includeTask,
                          ).then((value) => result.fullSelection = value),
                        );
                      },
                      child: const Text('Choose'),
                    ),
                    SizedBox(
                      key: anchorKey,
                      width: 300,
                      height: 48,
                      child: TextButton(
                        key: const Key('open-dropdown'),
                        onPressed: () {
                          unawaited(
                            showEventTypeDropdown(
                              context: context,
                              ref: ref,
                              anchorKey: anchorKey,
                            ).then((value) => result.dropdownSelection = value),
                          );
                        },
                        child: const Text('Dropdown'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

Future<void> _openFullPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-full-picker')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('event-type-picker')), findsOneWidget);
}

void main() {
  final fixture = Platform.environment['LINKAGE_REPAIRED_COPY'];
  final fixtureSkip = fixture == null;

  testWidgets(
    'snapshot exposes only occupied canonical slots and preserves normal/custom order and geometry',
    (tester) async {
      final repositories = await _copyFixture(fixture!);
      await repositories.types.readEventTypes(profileId: _profileId);
      final custom = await repositories.types.saveCustomType(
        profileId: _profileId,
        draft: const EventTypeDraft(
          id: 'a1111111-1111-4111-8111-111111111111',
          label: 'Custom trailing choice',
          icon: EventTypeIcon.personal,
          colorValue: 0xFF010203,
          reportRequiredDefault: false,
          defaultDurationMinutes: 60,
          indicatorKeys: <String>{},
        ),
      );
      await _pumpHost(tester, repositories);
      await _openFullPicker(tester);

      for (final key in <String>[
        'job_application',
        'scripture_study',
        'temple_visit',
      ]) {
        expect(find.byKey(Key('event-type-option-$key')), findsOneWidget);
      }
      for (final key in <String>[
        'exercise',
        'budget_review',
        'meaningful_connection',
      ]) {
        expect(find.byKey(Key('event-type-option-$key')), findsNothing);
      }
      for (final id in <String>[_slotOneGoalId, _slotTwoGoalId]) {
        expect(find.byKey(Key('event-type-option-goal:$id')), findsNothing);
      }

      final raw = await repositories.types.readEventTypes(
        profileId: _profileId,
        includeArchived: true,
      );
      final nonCanonicalCreationKeys = raw
          .where(
            (type) =>
                type.isCreationVisible &&
                CanonicalGoalSlot.tryByEventTypeKey(type.stableKey) == null,
          )
          .map((type) => type.stableKey);
      for (final key in nonCanonicalCreationKeys) {
        expect(find.byKey(Key('event-type-option-$key')), findsOneWidget);
      }
      expect(find.byKey(const Key('event-type-option-education')), findsOneWidget);
      expect(find.byKey(Key('event-type-option-${custom.stableKey}')), findsOneWidget);
      expect(find.byKey(const Key('event-type-option-task')), findsOneWidget);

      final approvedVisible = <String>[
        'job_application',
        'scripture_study',
        'temple_visit',
        'contact',
        'meeting',
        'study_or_plan',
        'education',
        'service',
        'work',
        'travel',
        'meal',
        'other',
      ].where((key) => find.byKey(Key('event-type-option-$key')).evaluate().isNotEmpty);
      final orderedKeys = <String>[...approvedVisible, custom.stableKey, 'task'];
      final positions = orderedKeys
          .map((key) => tester.getTopLeft(find.byKey(Key('event-type-option-$key'))).dy)
          .toList();
      expect(positions, orderedEquals(<double>[...positions]..sort()));

      final pickerSize = tester.getSize(find.byKey(const Key('event-type-picker')));
      expect(pickerSize.width, 347);
      expect(find.byKey(const Key('event-type-picker-scroll')), findsOneWidget);
      final jobRow = tester.getSize(
        find.byKey(const Key('event-type-option-job_application')),
      );
      final jobDot = tester.getSize(
        find.byKey(const Key('event-type-icon-job_application')),
      );
      expect(jobRow.height, 44);
      expect(jobDot, const Size(22, 22));
      expect(find.text('Sample1'), findsOneWidget);
      expect(find.text('sample2'), findsOneWidget);
    },
    skip: fixtureSkip,
  );

  testWidgets(
    'recommendation and allowed keys cannot resurrect an inactive slot',
    (tester) async {
      final repositories = await _copyFixture(fixture!);
      await _pumpHost(
        tester,
        repositories,
        recommendedEventTypeId: CanonicalGoalSlot.bySlot(3).eventTypeId,
        allowedStableKeys: const <String>{
          'job_application',
          'exercise',
          'education',
        },
        includeTask: false,
      );
      await _openFullPicker(tester);
      expect(find.byKey(const Key('event-type-option-job_application')), findsOneWidget);
      expect(find.byKey(const Key('event-type-option-education')), findsOneWidget);
      expect(find.byKey(const Key('event-type-option-exercise')), findsNothing);
      expect(find.byKey(const Key('event-type-recommended-exercise')), findsNothing);
      expect(find.byKey(const Key('event-type-option-scripture_study')), findsNothing);
      expect(find.byKey(const Key('event-type-option-task')), findsNothing);
    },
    skip: fixtureSkip,
  );

  testWidgets(
    'open modal refreshes on archive and reoccupation and returns the new binding',
    (tester) async {
      final repositories = await _copyFixture(fixture!);
      final result = await _pumpHost(tester, repositories);
      await _openFullPicker(tester);
      expect(find.text('Sample1'), findsOneWidget);

      final original = (await repositories.goals.readGoal(
        profileId: _profileId,
        goalId: _slotOneGoalId,
      ))!;
      await repositories.goals.archiveGoal(
        profileId: _profileId,
        goalId: original.id,
        operationId: 't06-archive-slot-one',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-type-picker')), findsOneWidget);
      expect(find.byKey(const Key('event-type-option-job_application')), findsNothing);

      final replacement = await repositories.goals.createGoal(
        profileId: _profileId,
        role: original.role,
        title: 'Replacement application goal',
        targets: const GoalTargets(
          daily: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
          weekly: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
        ),
        expectedSlotIndex: 1,
        operationId: 't06-reoccupy-slot-one',
      );
      await tester.pumpAndSettle();
      expect(find.text('Replacement application goal'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('event-type-option-job_application')),
      );
      await tester.pumpAndSettle();
      final selection = result.fullSelection! as EventTypePickerEvent;
      expect(selection.eventType.id, CanonicalGoalSlot.bySlot(1).eventTypeId);
      expect(selection.binding!.goalId, replacement.id);
      expect(selection.binding!.title, 'Replacement application goal');
    },
    skip: fixtureSkip,
  );

  testWidgets(
    'dropdown refreshes with the same occupancy/alias law and returns the raw ID',
    (tester) async {
      final repositories = await _copyFixture(fixture!);
      final result = await _pumpHost(tester, repositories);
      await tester.tap(find.byKey(const Key('open-dropdown')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('event-type-dropdown-option-job_application')),
        findsOneWidget,
      );
      expect(find.text('Sample1'), findsOneWidget);
      expect(
        find.byKey(const Key('event-type-dropdown-option-exercise')),
        findsNothing,
      );
      final original = (await repositories.goals.readGoal(
        profileId: _profileId,
        goalId: _slotOneGoalId,
      ))!;
      await repositories.goals.archiveGoal(
        profileId: _profileId,
        goalId: original.id,
        operationId: 't06-dropdown-archive',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('event-type-dropdown-scroll')), findsOneWidget);
      expect(
        find.byKey(const Key('event-type-dropdown-option-job_application')),
        findsNothing,
      );
      final replacement = await repositories.goals.createGoal(
        profileId: _profileId,
        role: original.role,
        title: 'Dropdown replacement goal',
        targets: const GoalTargets(
          daily: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
          weekly: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
        ),
        expectedSlotIndex: 1,
        operationId: 't06-dropdown-reoccupy',
      );
      await tester.pumpAndSettle();
      expect(find.text('Dropdown replacement goal'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('event-type-dropdown-option-job_application')),
      );
      await tester.pumpAndSettle();
      expect(result.dropdownSelection!.id, CanonicalGoalSlot.bySlot(1).eventTypeId);
      expect(replacement.activeSlotIndex, 1);
    },
    skip: fixtureSkip,
  );

  testWidgets(
    'long alias keeps one-line ellipsis and full semantics at supported widths and scales',
    (tester) async {
      const longAlias =
          'A deliberately long application Goal title retained in semantics';
      final repositories = await _copyFixture(fixture!);
      final goal = (await repositories.goals.readGoal(
        profileId: _profileId,
        goalId: _slotOneGoalId,
      ))!;
      await repositories.goals.saveGoal(
        profileId: _profileId,
        goalId: goal.id,
        title: longAlias,
        targets: const GoalTargets(
          daily: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
          weekly: IndicatorAmount(scaledValue: 1, scale: 0, unit: 'count'),
        ),
        iconId: goal.iconId,
        operationId: 't06-long-alias',
      );
      for (final variant in <(Size, double)>[
        (const Size(360, 800), 1),
        (const Size(393, 874), 1.15),
        (const Size(411, 890), 1.3),
      ]) {
        await _pumpHost(
          tester,
          repositories,
          size: variant.$1,
          textScale: variant.$2,
        );
        await _openFullPicker(tester);
        final text = tester.widget<Text>(find.text(longAlias));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        final semanticsLabels = tester
            .widgetList<Semantics>(
              find.ancestor(
                of: find.text(longAlias),
                matching: find.byType(Semantics),
              ),
            )
            .map((widget) => widget.properties.label);
        expect(semanticsLabels, contains('$longAlias Event Type'));
        await tester.tap(find.byKey(const Key('event-type-picker-cancel')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    skip: fixtureSkip,
  );
}
