import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/ids/identifier_source.dart';
import 'package:rmplanner/features/goals/data/drift_goal_repository.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';

import '../../../support/test_dependencies.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 9, 8, 12));

  Future<(AppDatabase, DriftGoalRepository, String, Goal)> arrange() async {
    final database = openMemoryDatabase();
    final profile = await buildTestRepository(
      database: database,
    ).completeOnboarding();
    final goals = DriftGoalRepository(
      database: database,
      clock: clock,
      identifiers: const UuidIdentifierSource(),
    );
    final goal = (await goals.readActiveGoals(profile.id)).first;
    return (database, goals, profile.id, goal);
  }

  test(
    'M6 explicit lifecycle keeps completion independent from progress and archive',
    () async {
      final (database, goals, profileId, goal) = await arrange();
      addTearDown(database.close);

      final paused = await goals.pauseGoal(
        profileId: profileId,
        goalId: goal.id,
      );
      expect(paused.status, GoalStatus.paused);
      final active = await goals.resumeGoal(
        profileId: profileId,
        goalId: goal.id,
      );
      expect(active.status, GoalStatus.active);

      await goals.archiveGoal(profileId: profileId, goalId: goal.id);
      final archived = await goals.readGoal(
        profileId: profileId,
        goalId: goal.id,
      );
      expect(archived?.status, GoalStatus.archived);
      expect(archived?.completedAtUtc, isNull);
    },
  );

  test(
    'M6 completion is explicit, idempotent, and creates one canonical event',
    () async {
      final (database, goals, profileId, goal) = await arrange();
      addTearDown(database.close);

      final completed = await goals.completeGoal(
        profileId: profileId,
        goalId: goal.id,
        operationId: 'm6-complete-once',
      );
      final replay = await goals.completeGoal(
        profileId: profileId,
        goalId: goal.id,
        operationId: 'm6-complete-once',
      );
      expect(completed.status, GoalStatus.completed);
      expect(completed.completedAtUtc, clock.nowUtc());
      expect(completed.completionMethod, GoalCompletionMethod.userConfirmation);
      expect(completed.completionGeneration, 1);
      expect(replay.completionGeneration, 1);
      final events = await database
          .select(database.goalAchievementEvents)
          .get();
      expect(events, hasLength(1));
      expect(events.single.completionGeneration, 1);
      expect(
        events.single.achievementType,
        GoalAchievementType.goalCompleted.name,
      );
    },
  );

  test(
    'M6 reopen preserves history and a re-completion gets a new generation',
    () async {
      final (database, goals, profileId, goal) = await arrange();
      addTearDown(database.close);

      await goals.completeGoal(profileId: profileId, goalId: goal.id);
      final reopened = await goals.reopenGoal(
        profileId: profileId,
        goalId: goal.id,
      );
      expect(reopened.status, GoalStatus.active);
      expect(reopened.completedAtUtc, isNull);
      expect(reopened.completionGeneration, 1);
      final recompleted = await goals.completeGoal(
        profileId: profileId,
        goalId: goal.id,
      );
      expect(recompleted.completionGeneration, 2);
      expect(
        (await database.select(database.goalAchievementEvents).get()).map(
          (event) => event.completionGeneration,
        ),
        <int>[1, 2],
      );
    },
  );

  test(
    'M6 celebration is one-time per generation and only a completion creates it',
    () async {
      final (database, goals, profileId, goal) = await arrange();
      addTearDown(database.close);

      expect(await goals.claimNextGoalCelebration(profileId), isNull);
      await goals.completeGoal(profileId: profileId, goalId: goal.id);
      final claimed = await goals.claimNextGoalCelebration(profileId);
      expect(claimed?.completionGeneration, 1);
      expect(await goals.claimNextGoalCelebration(profileId), isNull);
      await goals.reopenGoal(profileId: profileId, goalId: goal.id);
      expect(await goals.claimNextGoalCelebration(profileId), isNull);
      await goals.completeGoal(profileId: profileId, goalId: goal.id);
      expect(
        (await goals.claimNextGoalCelebration(profileId))?.completionGeneration,
        2,
      );
    },
  );
}
