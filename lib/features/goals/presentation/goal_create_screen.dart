import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';
import 'package:rmplanner/features/goals/presentation/goal_icon_picker_screen.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon_choice_row.dart';
import 'package:rmplanner/features/indicators/domain/life_indicator.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/presentation/event_type_form_screen.dart';

final class GoalCreateScreen extends ConsumerStatefulWidget {
  const GoalCreateScreen({super.key});

  @override
  ConsumerState<GoalCreateScreen> createState() => _GoalCreateScreenState();
}

final class _GoalCreateScreenState extends ConsumerState<GoalCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  GoalRole _role = GoalRole.weekly;
  int? _dailyTarget = 1;
  int? _weeklyTarget = 1;
  int? _monthlyTarget = 1;
  String? _iconId;
  bool _iconManuallySelected = false;
  bool _saving = false;

  /// The exact canonical slot that Save will occupy, resolved through the
  /// same allocator used by [GoalRepository.createGoal].
  int? _previewSlot;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_draftChanged);
    unawaited(_refreshPreviewSlot());
  }

  @override
  void dispose() {
    _nameController.removeListener(_draftChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refreshPreviewSlot() async {
    try {
      final slot = await ref
          .read(goalRepositoryProvider)
          .nextAvailableSlot(
            profileId: ref.read(goalProfileIdProvider),
            role: _role,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _previewSlot = slot;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _previewSlot = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final capacity = ref.watch(goalCapacityProvider);
    return Scaffold(
      appBar: InternalAppBar(
        leading: IconButton(
          key: const Key('goal-create-back'),
          tooltip: 'Back',
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Create Goal'),
        actions: <Widget>[
          TextButton(
            key: const Key('goal-create-save'),
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
        child: capacity.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _GoalError(message: error.toString()),
          data: (value) => Form(
            key: _formKey,
            child: ListView(
              padding: InternalScreen.pagePadding,
              children: <Widget>[
                Text('Goal Type', style: InternalScreen.sectionHeading),
                const SizedBox(height: 3),
                const Text(
                  'Choose how this goal will be planned.',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: 10),
                for (final role in GoalRole.values) ...<Widget>[
                  _RoleCard(
                    key: Key('goal-create-role-${role.storageName}'),
                    role: role,
                    selected: _role == role,
                    available: value.isAvailable(role),
                    availability: value.availabilityLabel(role),
                    onTap: value.isAvailable(role)
                        ? () {
                            setState(() => _role = role);
                            unawaited(_refreshPreviewSlot());
                          }
                        : null,
                  ),
                  if (role != GoalRole.values.last) const SizedBox(height: 8),
                ],
                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text('Goal Details', style: InternalScreen.sectionHeading),
                const SizedBox(height: 3),
                const Text(
                  'Enter your goal name and target.',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('goal-name'),
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Goal Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a Goal name.'
                      : null,
                ),
                const SizedBox(height: 14),
                Text('Icon', style: AppTypography.cardTitle),
                const SizedBox(height: 3),
                const Text(
                  'Choose an icon that represents your goal.',
                  style: AppTypography.secondary,
                ),
                const SizedBox(height: 8),
                GoalIconChoiceRow(
                  goalTitle: _nameController.text.trim().isEmpty
                      ? 'this goal'
                      : _nameController.text.trim(),
                  iconId: _draftIconId,
                  fallbackIcon: goalIconFallbackForRole(_role),
                  showSuggestion: _suggestion != null && !_iconManuallySelected,
                  onTap: _openIconPicker,
                ),
                const SizedBox(height: 14),
                if (_role == GoalRole.dailyWeekly) ...<Widget>[
                  _TargetEditor(
                    key: const Key('goal-create-daily-target'),
                    label: 'Daily Target',
                    helper: 'Complete this target each day.',
                    value: _dailyTarget,
                    onChanged: (value) => setState(() => _dailyTarget = value),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_role == GoalRole.dailyWeekly ||
                    _role == GoalRole.weekly ||
                    _role == GoalRole.weeklyMonthly)
                  _TargetEditor(
                    key: const Key('goal-create-weekly-target'),
                    label: 'Weekly Target',
                    helper: 'Complete this target during the week.',
                    value: _weeklyTarget,
                    onChanged: (value) => setState(() => _weeklyTarget = value),
                  ),
                if (_role == GoalRole.weeklyMonthly) ...<Widget>[
                  const SizedBox(height: 12),
                  _TargetEditor(
                    key: const Key('goal-create-monthly-target'),
                    label: 'Monthly Target',
                    helper: 'Complete this target during the month.',
                    value: _monthlyTarget,
                    onChanged: (value) =>
                        setState(() => _monthlyTarget = value),
                  ),
                ],
                const SizedBox(height: 18),
                _buildAssignedEventTypeSection(),
                const SizedBox(height: 18),
                const Text(
                  'A Goal is created only when you tap Save. You can change its '
                  'name and targets later from Edit Goal.',
                  style: AppTypography.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedEventTypeSection() {
    final slot = _previewSlot;
    if (slot == null) {
      return const SizedBox.shrink();
    }
    final stableKey = CanonicalGoalSlot.bySlot(slot).eventTypeStableKey;
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
      key: const Key('goal-create-assigned-event-type'),
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
                    type?.label ?? 'Loading…',
                    style: AppTypography.cardTitle,
                  ),
                ),
                TextButton(
                  key: const Key('goal-create-edit-event-type'),
                  onPressed: type == null
                      ? null
                      : () => unawaited(_editAssignedEventType(type.id)),
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

  Future<void> _editAssignedEventType(String eventTypeId) async {
    // A plain Navigator push keeps this screen's draft (role, name, icon,
    // targets, and predicted slot) alive while Edit Event Type is open.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EventTypeFormScreen.edit(
          eventTypeId: eventTypeId,
          fixedAssignmentLabel: _nameController.text.trim().isEmpty
              ? 'this Goal'
              : _nameController.text.trim(),
        ),
      ),
    );
    if (mounted) {
      // The Event Type controller reloads on save, so the assignment preview
      // (name/color) refreshes here without touching the Goal draft.
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final capacity = await ref.read(goalCapacityProvider.future);
    if (!mounted || _saving) {
      return;
    }
    if (!capacity.isAvailable(_role)) {
      await _showCapacityWarning(context);
      return;
    }
    final previewedSlot = _previewSlot;
    final resolvedSlot = await ref
        .read(goalRepositoryProvider)
        .nextAvailableSlot(
          profileId: ref.read(goalProfileIdProvider),
          role: _role,
        );
    if (!mounted || _saving) {
      return;
    }
    if (previewedSlot == null || resolvedSlot != previewedSlot) {
      await _refreshPreviewSlot();
      _showError(
        'The available Goal slot changed. Review the assigned Event Type '
        'and try again.',
      );
      return;
    }
    final targets = GoalTargets(
      daily: _amount(_dailyTarget),
      weekly: _amount(_weeklyTarget),
      monthly: _amount(_monthlyTarget),
    );
    if (!_targetsAreValid(targets)) {
      _showError('Targets must be zero or greater.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(goalRepositoryProvider)
          .createGoal(
            profileId: ref.read(goalProfileIdProvider),
            role: _role,
            title: _nameController.text.trim(),
            targets: targets,
            iconId: _draftIconId,
            expectedSlotIndex: previewedSlot,
          );
      ref.invalidate(activeGoalsProvider);
      ref.invalidate(goalCapacityProvider);
      ref.invalidate(goalPlanningProvider);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on GoalCapacityException {
      if (mounted) {
        await _showCapacityWarning(context);
      }
    } on GoalValidationException catch (error) {
      _showError(error.message);
    } on Object {
      _showError('The Goal could not be saved.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  IndicatorAmount? _amount(int? value) {
    if (value == null) {
      return null;
    }
    return IndicatorAmount(scaledValue: value, scale: 0, unit: 'count');
  }

  bool _targetsAreValid(GoalTargets targets) {
    final values = <IndicatorAmount?>[
      targets.daily,
      targets.weekly,
      targets.monthly,
    ];
    return values.every((value) => value == null || value.scaledValue >= 0);
  }

  bool get _draftIsValid =>
      _nameController.text.trim().isNotEmpty &&
      <int?>[
        _dailyTarget,
        _weeklyTarget,
        _monthlyTarget,
      ].every((value) => value == null || value >= 0);

  GoalIconSuggestion? get _suggestion => _iconManuallySelected
      ? null
      : GoalIconRegistry.instance.suggestForGoalTitle(
          _nameController.text.trim(),
        );

  String? get _draftIconId =>
      _iconManuallySelected ? _iconId : _suggestion?.iconId;

  Future<void> _openIconPicker() async {
    final selected = await context.push<String?>(
      RoutePaths.goalCreateIconPicker,
      extra: GoalIconPickerArgs(
        goalTitle: _nameController.text.trim().isEmpty
            ? 'this goal'
            : _nameController.text.trim(),
        currentIconId: _draftIconId,
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _iconId = selected;
      _iconManuallySelected = true;
    });
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCapacityWarning(BuildContext context) async {
    final manage = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Goal limit reached'),
        content: const Text(
          'All 6 goal slots are currently in use. Archive at least one goal '
          'before creating another.',
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('goal-create-limit-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('goal-create-limit-manage'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Manage Goals'),
          ),
        ],
      ),
    );
    if (manage == true && context.mounted) {
      context.go(RoutePaths.weeklyPlanning, extra: true);
    }
  }
}

final class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.available,
    required this.availability,
    required this.onTap,
    super.key,
  });

  final GoalRole role;
  final bool selected;
  final bool available;
  final String availability;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppTheme.rose : AppTheme.outline;
    return Semantics(
      button: true,
      enabled: available,
      selected: selected,
      label: role.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppTheme.rose : Colors.white54,
                size: 24,
              ),
              const SizedBox(width: 10),
              Icon(_roleIcon(role), color: const Color(0xFF9EDCE3), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(role.title, style: AppTypography.cardTitle),
                    Text(role.description, style: AppTypography.secondary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  availability,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: available
                        ? (selected ? AppTheme.rose : const Color(0xFF9EDCE3))
                        : Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TargetEditor extends StatelessWidget {
  const _TargetEditor({
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String helper;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTypography.cardTitle),
        const SizedBox(height: 2),
        Text(helper, style: AppTypography.secondary),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppTheme.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  value?.toString() ?? '-',
                  style: AppTypography.metricCompact.copyWith(
                    fontSize: 20,
                    height: 24 / 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _TargetButton(
              key: Key('${key}_minus'),
              icon: Icons.remove,
              enabled: value != null && value! > 0,
              onPressed: () => onChanged((value ?? 1) - 1),
            ),
            const SizedBox(width: 8),
            _TargetButton(
              key: Key('${key}_plus'),
              icon: Icons.add,
              onPressed: () => onChanged((value ?? 0) + 1),
            ),
          ],
        ),
      ],
    );
  }
}

final class _TargetButton extends StatelessWidget {
  const _TargetButton({
    required this.icon,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          foregroundColor: AppTheme.rose,
          side: const BorderSide(color: AppTheme.outline),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

final class _GoalError extends StatelessWidget {
  const _GoalError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Goals are unavailable.\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

IconData _roleIcon(GoalRole role) => switch (role) {
  GoalRole.dailyWeekly => Icons.calendar_month_outlined,
  GoalRole.weekly => Icons.calendar_month_outlined,
  GoalRole.weeklyMonthly => Icons.calendar_month_outlined,
};
