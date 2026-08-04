import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/presentation/goal_icon_picker_screen.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon_choice_row.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';

final class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({required this.goalId, super.key});

  final String goalId;

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

final class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  Goal? _goal;
  GoalProgress? _progress;
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
      final today = ref.read(plannerDateSourceProvider).today();
      final progress = goal == null
          ? null
          : await repository.readProgress(
              profileId: profileId,
              goalId: widget.goalId,
              today: today,
            );
      if (!mounted) {
        return;
      }
      if (goal == null || !goal.isActive) {
        setState(() {
          _loading = false;
          _error = 'This Goal is no longer active.';
        });
        return;
      }
      _titleController.text = goal.title;
      setState(() {
        _goal = goal;
        _progress = progress;
        _daily = progress?.dailyTarget.value?.scaledValue;
        _weekly = progress?.weeklyTarget.value?.scaledValue;
        _monthly = progress?.monthlyTarget.value?.scaledValue;
        _iconId = goal.iconId;
        _loading = false;
      });
    } on Object catch (error) {
      if (mounted) {
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
        appBar: const _GoalEditAppBar(),
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
        appBar: AppBar(
          leading: IconButton(
            key: const Key('goal-edit-back'),
            tooltip: 'Back',
            onPressed: _saving ? null : () => unawaited(_handleBackAndPop()),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Edit Goal'),
          actions: <Widget>[
            TextButton(
              key: const Key('goal-edit-save'),
              onPressed: _saving || !_draftIsValid ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: <Widget>[
                Text(goal.title, style: AppTypography.pageTitle),
                const SizedBox(height: 4),
                Text(goal.role.title, style: AppTypography.secondary),
                const SizedBox(height: 20),
                TextFormField(
                  key: const Key('goal-title'),
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Goal Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a Goal name.'
                      : null,
                ),
                const SizedBox(height: 20),
                Text('Icon', style: AppTypography.cardTitle),
                const SizedBox(height: 3),
                const Text(
                  'Choose an icon that represents your goal.',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: 8),
                GoalIconChoiceRow(
                  goalTitle: _titleController.text.trim(),
                  iconId: _iconId,
                  fallbackIcon: goalIconFallbackForRole(goal.role),
                  onTap: _openIconPicker,
                ),
                const SizedBox(height: 20),
                if (goal.role == GoalRole.dailyWeekly) ...<Widget>[
                  _EditTarget(
                    key: const Key('goal-period-daily'),
                    label: 'Daily Target',
                    value: _daily,
                    onChanged: (value) => setState(() => _daily = value),
                  ),
                  const SizedBox(height: 14),
                ],
                _EditTarget(
                  key: const Key('goal-period-weekly'),
                  label: 'Weekly Target',
                  value: _weekly,
                  onChanged: (value) => setState(() => _weekly = value),
                ),
                if (goal.role == GoalRole.weeklyMonthly) ...<Widget>[
                  const SizedBox(height: 14),
                  _EditTarget(
                    key: const Key('goal-period-monthly'),
                    label: 'Monthly Target',
                    value: _monthly,
                    onChanged: (value) => setState(() => _monthly = value),
                  ),
                ],
                const SizedBox(height: 24),
                _ProgressSummary(progress: _progress),
                const SizedBox(height: 24),
                const Text(
                  'Changes are saved only when you tap Save.',
                  style: AppTypography.secondary,
                ),
              ],
            ),
          ),
        ),
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

final class _GoalEditAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _GoalEditAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Edit Goal'));
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
            decoration: InputDecoration(labelText: label),
            child: Text(value?.toString() ?? '-', style: AppTypography.body),
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
          color: AppTheme.rose,
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Current Progress', style: AppTypography.sectionTitle),
            const SizedBox(height: 8),
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
