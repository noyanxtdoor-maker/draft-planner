import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';

final class GoalArchiveScreen extends ConsumerStatefulWidget {
  const GoalArchiveScreen({super.key});

  @override
  ConsumerState<GoalArchiveScreen> createState() => _GoalArchiveScreenState();
}

final class _GoalArchiveScreenState extends ConsumerState<GoalArchiveScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  Timer? _searchDebounce;
  var _loadGeneration = 0;
  var _tab = 0;
  var _loading = true;
  var _restoring = <String>{};
  List<Goal> _goals = const <Goal>[];
  List<GoalActivityHistoryItem> _history = const <GoalActivityHistoryItem>[];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_tabChanged);
    _searchController.addListener(_searchChanged);
    unawaited(_load());
  }

  void _tabChanged() {
    if (_tabController.indexIsChanging || !mounted) {
      return;
    }
    if (_tab != _tabController.index) {
      setState(() => _tab = _tabController.index);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController
      ..removeListener(_tabChanged)
      ..dispose();
    _searchController
      ..removeListener(_searchChanged)
      ..dispose();
    super.dispose();
  }

  void _searchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 220),
      () => unawaited(_load()),
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final profileId = ref.read(goalProfileIdProvider);
      final repository = ref.read(goalRepositoryProvider);
      final results = await Future.wait<Object>(<Future<Object>>[
        repository.readArchivedGoals(
          profileId: profileId,
          query: _searchController.text,
        ),
        repository.readActivityHistory(profileId),
      ]);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _goals = results[0] as List<Goal>;
        _history = results[1] as List<GoalActivityHistoryItem>;
        _loading = false;
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileId = ref.read(goalProfileIdProvider);
    ref.watch(goalChangesProvider(profileId));
    ref.listen<AsyncValue<void>>(goalChangesProvider(profileId), (_, _) {
      unawaited(_load());
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('goal-archive-back'),
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Goal Archive'),
        actions: <Widget>[
          IconButton(
            key: const Key('goal-archive-info'),
            tooltip: 'Goal Archive information',
            onPressed: () => unawaited(_showInfo(context)),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'View and restore your archived goals.\n'
                  'Your past goals and activity history are safe here.',
                  style: AppTypography.secondary,
                ),
              ),
            ),
            TabBar(
              onTap: (value) => setState(() => _tab = value),
              tabs: const <Widget>[
                Tab(key: Key('goal-archive-tab'), text: 'Archived Goals'),
                Tab(key: Key('goal-history-tab'), text: 'Activity History'),
              ],
              controller: _tabController,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('Archive unavailable: $_error'))
                  : _tab == 0
                  ? _buildArchivedGoals()
                  : _buildHistory(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedGoals() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: 50,
                child: TextField(
                  key: const Key('goal-archive-search'),
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search archived goals',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                key: const Key('goal-archive-all-time'),
                onPressed: () => unawaited(_showTimeFilter(context)),
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('All Time'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('Archived Goals', style: AppTypography.sectionTitle),
            ),
            Text('${_goals.length} goals', style: AppTypography.secondary),
          ],
        ),
        const SizedBox(height: 8),
        if (_goals.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No archived goals.', style: AppTypography.secondary),
          )
        else
          for (final goal in _goals) ...<Widget>[
            _ArchivedGoalRow(
              goal: goal,
              restoring: _restoring.contains(goal.id),
              onRestore: () => _restore(goal),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        Card(
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Restoring a goal adds it back to your current goals.\n'
              'Your goal data and history remain intact.',
              style: AppTypography.secondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: <Widget>[
        const Text('Activity History', style: AppTypography.sectionTitle),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No Goal activity yet.',
              style: AppTypography.secondary,
            ),
          )
        else
          for (final item in _history) _HistoryRow(item: item),
      ],
    );
  }

  Future<void> _restore(Goal goal) async {
    if (_restoring.contains(goal.id)) {
      return;
    }
    setState(() => _restoring = <String>{..._restoring, goal.id});
    try {
      await ref
          .read(goalRepositoryProvider)
          .restoreGoal(
            profileId: ref.read(goalProfileIdProvider),
            goalId: goal.id,
          );
      ref.invalidate(activeGoalsProvider);
      ref.invalidate(goalCapacityProvider);
      ref.invalidate(goalPlanningProvider);
      await _load();
    } on GoalCapacityException {
      if (mounted) {
        await _showRestoreWarning(context, goal.role);
      }
    } on GoalValidationException catch (error) {
      _showError(error.message);
    } on Object {
      _showError('The Goal could not be restored.');
    } finally {
      if (mounted) {
        setState(() {
          final next = <String>{..._restoring}..remove(goal.id);
          _restoring = next;
        });
      }
    }
  }

  Future<void> _showTimeFilter(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.check),
          title: const Text('All Time'),
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _showRestoreWarning(BuildContext context, GoalRole role) async {
    final roleName = role == GoalRole.weekly
        ? 'Weekly Goal'
        : role == GoalRole.dailyWeekly
        ? 'Daily Progress Goal'
        : 'Monthly Progress Goal';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No compatible slot available'),
        content: Text(
          'Archive an active $roleName before restoring this goal.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showInfo(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Goal Archive'),
        content: const Text(
          'Archived goals retain their targets, results, relationships, and '
          'activity history. Restore returns a goal to a compatible open slot.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

final class _ArchivedGoalRow extends StatelessWidget {
  const _ArchivedGoalRow({
    required this.goal,
    required this.restoring,
    required this.onRestore,
  });

  final Goal goal;
  final bool restoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final archivedAt = goal.archivedAtUtc;
    final date = archivedAt == null
        ? 'Archived'
        : MaterialLocalizations.of(
            context,
          ).formatMediumDate(archivedAt.toLocal());
    return Card(
      key: Key('goal-archive-row-${goal.id}'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: compact
                ? _buildCompactRow(context, date)
                : SizedBox(height: 72, child: _buildWideRow(context, date)),
          );
        },
      ),
    );
  }

  Widget _buildIcon() {
    return SizedBox.square(
      dimension: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: GoalIcon(
          iconId: goal.iconId,
          size: 32,
          semanticLabel: '${goal.title} goal icon',
          fallbackIcon: goalIconFallbackForRole(goal.role),
        ),
      ),
    );
  }

  Widget _buildCompactRow(BuildContext context, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _buildIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
              Text(
                '${goal.role.title} • Archived $date',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.secondary,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: Key('goal-restore-${goal.id}'),
          tooltip: 'Restore ${goal.title}',
          onPressed: restoring ? null : onRestore,
          icon: restoring
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.restore),
        ),
      ],
    );
  }

  Widget _buildWideRow(BuildContext context, String date) {
    return Row(
      children: <Widget>[
        _buildIcon(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle,
              ),
              Text(goal.role.title, style: AppTypography.secondary),
              Text('Archived on $date', style: AppTypography.micro),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: TextButton.icon(
            key: Key('goal-restore-${goal.id}'),
            onPressed: restoring ? null : onRestore,
            icon: restoring
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore, size: 18),
            label: const Text('Restore'),
          ),
        ),
      ],
    );
  }
}

final class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});

  final GoalActivityHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final activity = item.activity;
    final title = switch (activity.action) {
      GoalActivityAction.created =>
        'Created \u201c${activity.newValue ?? item.goalTitle}\u201d',
      GoalActivityAction.renamed =>
        'Renamed \u201c${activity.previousValue ?? ''}\u201d to '
            '\u201c${activity.newValue ?? item.goalTitle}\u201d',
      GoalActivityAction.archived =>
        'Archived \u201c${activity.newValue ?? item.goalTitle}\u201d',
      GoalActivityAction.restored => 'Restored \u201c${item.goalTitle}\u201d',
    };
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(activity.occurredAtUtc.toLocal());
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(activity.occurredAtUtc.toLocal()));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_activityIcon(activity.action), color: AppTheme.rose),
      title: Text(title, style: AppTypography.cardTitle),
      subtitle: Text('$date \u00b7 $time \u00b7 ${item.role.title}'),
    );
  }
}

IconData _activityIcon(GoalActivityAction action) => switch (action) {
  GoalActivityAction.created => Icons.add_circle_outline,
  GoalActivityAction.renamed => Icons.edit_outlined,
  GoalActivityAction.archived => Icons.archive_outlined,
  GoalActivityAction.restored => Icons.restore,
};
