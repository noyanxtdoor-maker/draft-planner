import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/presentation/goal_archive_screen.dart';
import 'package:rmplanner/features/goals/presentation/goal_icon_picker_screen.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon_choice_row.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/event_type_form_screen.dart';
import 'package:rmplanner/features/settings/application/start_of_week_providers.dart';

final class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({required this.goalId, this.initialGoal, super.key});

  final String goalId;
  final Goal? initialGoal;

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

final class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  Goal? _goal;
  GoalProgress? _progress;
  List<GoalActivityHistoryItem> _history = const <GoalActivityHistoryItem>[];
  int? _daily;
  int? _weekly;
  int? _monthly;
  String? _iconId;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _showIconPicker = false;

  @override
  void initState() {
    super.initState();
    final initialGoal = widget.initialGoal;
    if (initialGoal != null) {
      _goal = initialGoal;
      _iconId = initialGoal.iconId;
      _titleController.text = initialGoal.title;
      _loading = false;
    }
    _titleController.addListener(_draftChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _titleController.removeListener(_draftChanged);
    _titleController.dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    try {
      final profileId = ref.read(goalProfileIdProvider);
      final repository = ref.read(goalRepositoryProvider);
      final goal = await repository.readGoal(
        profileId: profileId,
        goalId: widget.goalId,
      );
      if (!mounted) {
        return;
      }
      if (goal == null ||
          goal.isDeleted ||
          goal.status == GoalStatus.archived) {
        if (_goal == null) {
          setState(() {
            _loading = false;
            _error = 'This Goal is no longer active.';
          });
        }
        return;
      }
      _titleController.text = goal.title;
      setState(() {
        _goal = goal;
        _iconId = goal.iconId;
        _loading = false;
      });

      // The Goal identity and manually selected icon are the first-order edit
      // surface. Render them as soon as the Goal row is available instead of
      // making the user wait for the progress/history queries to finish.
      // This also prevents a slow local database read from presenting an
      // apparently empty Edit Goal screen after navigation.
      try {
        final today = ref.read(plannerDateSourceProvider).today();
        final progress = await repository.readProgress(
          profileId: profileId,
          goalId: widget.goalId,
          today: today,
          startDay: ref.read(startOfWeekProvider),
        );
        final history = await repository.readActivityHistory(
          profileId,
          goalId: widget.goalId,
        );
        if (mounted) {
          setState(() {
            _progress = progress;
            _history = history;
            _daily = progress?.dailyTarget.value?.scaledValue;
            _weekly = progress?.weeklyTarget.value?.scaledValue;
            _monthly = progress?.monthlyTarget.value?.scaledValue;
          });
        }
      } on Object catch (error) {
        if (mounted) {
          setState(() => _error = error.toString());
        }
      }
    } on Object catch (error) {
      if (mounted && _goal == null) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _GoalEditAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_goal == null) {
      return Scaffold(
        appBar: _GoalEditAppBar(),
        body: Center(child: Text(_error ?? 'Goal unavailable.')),
      );
    }
    final goal = _goal!;
    if (_showIconPicker) {
      return GoalIconPickerScreen(
        args: GoalIconPickerArgs(
          goalTitle: _titleController.text.trim(),
          currentIconId: _iconId,
        ),
        onSelected: (iconId) {
          setState(() {
            _iconId = iconId;
            _showIconPicker = false;
          });
        },
        onCancel: () => setState(() => _showIconPicker = false),
      );
    }
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) {
          unawaited(_handleBackAndPop());
        }
      },
      child: Scaffold(
        appBar: InternalAppBar(
          backgroundColor: AppTheme.surfaceOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            key: const Key('goal-edit-back'),
            tooltip: 'Back',
            color: Theme.of(context).colorScheme.primary,
            onPressed: _saving ? null : () => unawaited(_handleBackAndPop()),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Edit Goal'),
          actions: <Widget>[
            IconButton(
              key: const Key('goal-edit-save'),
              tooltip: 'Save',
              color: Theme.of(context).colorScheme.primary,
              onPressed: _saving || !_draftIsValid ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: GestureDetector(
          key: const Key('goal-edit-blank-space-dismiss'),
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                key: const Key('goal-edit-scroll'),
                padding: InternalScreen.pagePadding,
                children: <Widget>[
                  Text(goal.title, style: InternalScreen.sectionHeading),
                  const SizedBox(height: 2),
                  Text(goal.role.title, style: InternalScreen.label),
                  const SizedBox(height: InternalScreen.sectionGap),
                  _buildAssignedEventTypeSection(goal),
                  const SizedBox(height: InternalScreen.sectionGap),
                  TextFormField(
                    key: const Key('goal-title'),
                    controller: _titleController,
                    style: InternalScreen.body,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      labelStyle: InternalScreen.fieldLabel,
                      isDense: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a Goal name.'
                        : null,
                  ),
                  const SizedBox(height: InternalScreen.sectionGap),
                  Text('Icon', style: InternalScreen.sectionHeading),
                  Divider(color: AppTheme.sectionDividerOf(context)),
                  const Text(
                    'Choose an icon that represents your goal.',
                    style: InternalScreen.label,
                  ),
                  const SizedBox(height: InternalScreen.labelToControlGap),
                  GoalIconChoiceRow(
                    goalTitle: _titleController.text.trim(),
                    iconId: _iconId,
                    fallbackIcon: goalIconFallbackForRole(goal.role),
                    onTap: _openIconPicker,
                  ),
                  const SizedBox(height: InternalScreen.sectionGap),
                  if (goal.role == GoalRole.dailyWeekly) ...<Widget>[
                    _EditTarget(
                      key: const Key('goal-period-daily'),
                      label: 'Daily Target',
                      value: _daily,
                      onChanged: (value) => setState(() => _daily = value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _EditTarget(
                    key: const Key('goal-period-weekly'),
                    label: 'Weekly Target',
                    value: _weekly,
                    onChanged: (value) => setState(() => _weekly = value),
                  ),
                  if (goal.role == GoalRole.weeklyMonthly) ...<Widget>[
                    const SizedBox(height: 12),
                    _EditTarget(
                      key: const Key('goal-period-monthly'),
                      label: 'Monthly Target',
                      value: _monthly,
                      onChanged: (value) => setState(() => _monthly = value),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _ProgressSummary(progress: _progress),
                  const SizedBox(height: 18),
                  _GoalHistoryPreview(
                    items: _history,
                    onViewAll: () => _openGoalHistory(goal.id),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Changes are saved only when you tap Save.',
                    style: AppTypography.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedEventTypeSection(Goal goal) {
    final stableKey =
        goal.assignedEventTypeStableKey ??
        CanonicalGoalSlot.tryByIndicatorKey(
          goal.indicatorKey,
        )?.eventTypeStableKey;
    final eventTypeState = ref.watch(eventTypeControllerProvider);
    EventType? assignedType;
    for (final candidate in eventTypeState.eventTypes) {
      if (candidate.stableKey == stableKey) {
        assignedType = candidate;
        break;
      }
    }
    final type = assignedType;
    final preference = type == null
        ? null
        : eventTypeState.eventColors[type.stableKey] ??
              PlannerEventColorDefaults.forEventType(type);
    return Card(
      key: const Key('goal-assigned-event-type'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Assigned Event Type',
              style: InternalScreen.sectionHeading,
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(
                    preference?.accentArgb ?? AppTheme.rose.toARGB32(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    assignedType?.label ?? 'Not assigned',
                    style: AppTypography.cardTitle,
                  ),
                ),
                TextButton(
                  key: const Key('goal-edit-event-type'),
                  onPressed: type == null
                      ? null
                      : () => _editAssignedEventType(type),
                  child: const Text('Edit Event Type'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Events of this type contribute toward this Goal. '
              'The assignment is fixed.',
              style: AppTypography.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAssignedEventType(EventType eventType) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EventTypeFormScreen.edit(
          eventTypeId: eventType.id,
          initialEventType: eventType,
          fixedAssignmentLabel: _goal?.title ?? 'this Goal',
        ),
      ),
    );
    if (mounted) {
      // The Event Type screen reloads its own provider after saving. Do not
      // reload the Goal here: the user may have an unsaved Goal title, target,
      // or icon edit that must survive this nested route.
      setState(() {});
    }
  }

  Future<void> _openGoalHistory(String goalId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GoalArchiveScreen(initialTab: 1, historyGoalId: goalId),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!_formKey.currentState!.validate() || _goal == null) {
      return;
    }
    if ([
      _daily,
      _weekly,
      _monthly,
    ].any((value) => value != null && value < 0)) {
      _showError('Targets must be zero or greater.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(goalRepositoryProvider)
          .saveGoal(
            profileId: ref.read(goalProfileIdProvider),
            goalId: _goal!.id,
            title: _titleController.text.trim(),
            targets: GoalTargets(
              daily: _amount(_daily),
              weekly: _amount(_weekly),
              monthly: _amount(_monthly),
            ),
            iconId: _iconId,
            startDay: ref.read(startOfWeekProvider),
          );
      ref.invalidate(activeGoalsProvider);
      ref.invalidate(goalCapacityProvider);
      ref.invalidate(goalPlanningProvider);
      if (mounted) {
        setState(() {
          _goal = saved;
          _saving = false;
        });
        Navigator.of(context).pop(true);
      }
    } on GoalValidationException catch (error) {
      _showError(error.message);
      if (mounted) {
        setState(() => _saving = false);
      }
    } on Object {
      _showError('The Goal could not be saved.');
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<bool> _handleBack() async {
    if (!_hasChanges()) {
      return true;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Your changes have not been saved.'),
        actions: <Widget>[
          TextButton(
            key: const Key('goal-discard-changes'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard Changes'),
          ),
          FilledButton(
            key: const Key('goal-continue-editing'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Editing'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleBackAndPop() async {
    if (await _handleBack() && mounted) {
      Navigator.of(context).pop();
    }
  }

  bool _hasChanges() {
    final goal = _goal;
    if (goal == null) {
      return false;
    }
    return goal.title != _titleController.text.trim() ||
        _daily != _progress?.dailyTarget.value?.scaledValue ||
        _weekly != _progress?.weeklyTarget.value?.scaledValue ||
        _monthly != _progress?.monthlyTarget.value?.scaledValue ||
        _iconId != goal.iconId;
  }

  bool get _draftIsValid =>
      _titleController.text.trim().isNotEmpty &&
      <int?>[
        _daily,
        _weekly,
        _monthly,
      ].every((value) => value == null || value >= 0);

  IndicatorAmount? _amount(int? value) {
    if (value == null) {
      return null;
    }
    return IndicatorAmount(scaledValue: value, scale: 0, unit: 'count');
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openIconPicker() {
    if (mounted) {
      setState(() => _showIconPicker = true);
    }
  }
}

final class _GoalHistoryPreview extends StatelessWidget {
  const _GoalHistoryPreview({required this.items, required this.onViewAll});

  final List<GoalActivityHistoryItem> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final visible = items.take(4).toList(growable: false);
    return Card(
      key: const Key('goal-activity-history-preview'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Activity History',
                    style: InternalScreen.sectionHeading,
                  ),
                ),
                TextButton(
                  key: const Key('goal-view-all-history'),
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No Goal activity yet.',
                  style: AppTypography.secondary,
                ),
              )
            else
              for (final item in visible) _GoalHistoryRow(item: item),
          ],
        ),
      ),
    );
  }
}

final class _GoalHistoryRow extends StatelessWidget {
  const _GoalHistoryRow({required this.item});

  final GoalActivityHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final activity = item.activity;
    final title = switch (activity.action) {
      GoalActivityAction.created =>
        'Created “${activity.newValue ?? item.goalTitle}”',
      GoalActivityAction.renamed =>
        'Renamed “${activity.previousValue ?? ''}” to '
            '“${activity.newValue ?? item.goalTitle}”',
      GoalActivityAction.paused => 'Paused “${item.goalTitle}”',
      GoalActivityAction.resumed => 'Resumed “${item.goalTitle}”',
      GoalActivityAction.completed => 'Completed “${item.goalTitle}”',
      GoalActivityAction.reopened => 'Reopened “${item.goalTitle}”',
      GoalActivityAction.archived =>
        'Archived “${activity.newValue ?? item.goalTitle}”',
      GoalActivityAction.restored => 'Restored “${item.goalTitle}”',
      GoalActivityAction.deleted =>
        'Deleted “${activity.newValue ?? item.goalTitle}”',
    };
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(activity.occurredAtUtc.toLocal());
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(activity.occurredAtUtc.toLocal()));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      // B3.1: theme-owned generic action icon — resolves through the active
      // Theme Color semantic primary (Blue in Blue mode, canonical Rose in
      // Rose Dark).  Goal Icon artwork is NOT affected (separate renderer).
      leading: Icon(
        _goalActivityIcon(activity.action),
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(title, style: AppTypography.secondary),
      subtitle: Text('$date · $time'),
    );
  }
}

IconData _goalActivityIcon(GoalActivityAction action) => switch (action) {
  GoalActivityAction.created => Icons.add_circle_outline,
  GoalActivityAction.renamed => Icons.edit_outlined,
  GoalActivityAction.paused => Icons.pause_circle_outline,
  GoalActivityAction.resumed => Icons.play_circle_outline,
  GoalActivityAction.completed => Icons.celebration_outlined,
  GoalActivityAction.reopened => Icons.replay_outlined,
  GoalActivityAction.archived => Icons.archive_outlined,
  GoalActivityAction.restored => Icons.restore,
  GoalActivityAction.deleted => Icons.delete_outline,
};

final class _GoalEditAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _GoalEditAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(InternalScreen.appBarHeight);

  @override
  Widget build(BuildContext context) {
    return const InternalAppBar(title: Text('Edit Goal'));
  }
}

final class _EditTarget extends StatelessWidget {
  const _EditTarget({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              labelStyle: InternalScreen.fieldLabel,
              isDense: true,
            ),
            child: Text(value?.toString() ?? '-', style: InternalScreen.body),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: Key('${key}_minus'),
          tooltip: 'Decrease $label',
          onPressed: value != null && value! > 0
              ? () => onChanged(value! - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          key: Key('${key}_plus'),
          tooltip: 'Increase $label',
          onPressed: () => onChanged((value ?? 0) + 1),
          icon: const Icon(Icons.add_circle),
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

final class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.progress});

  final GoalProgress? progress;

  @override
  Widget build(BuildContext context) {
    if (progress == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Current Progress',
              style: InternalScreen.sectionHeading,
            ),
            const SizedBox(height: 6),
            Text(
              'Daily: ${progress!.dailyActual.display}   '
              'Weekly: ${progress!.weeklyActual.display}   '
              'Monthly: ${progress!.monthlyActual.display}',
              style: AppTypography.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
