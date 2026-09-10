import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/application/goal_providers.dart';
import 'package:rmplanner/features/goals/domain/canonical_goal_slots.dart';
import 'package:rmplanner/features/goals/domain/goal_event_type_policy.dart';
import 'package:rmplanner/features/goals/presentation/assigned_event_type_draft_screen.dart';
import 'package:rmplanner/features/planner/application/event_type_providers.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/event_type_presentation.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_resolver.dart';

final class EventTypesScreen extends ConsumerStatefulWidget {
  const EventTypesScreen({super.key});

  @override
  ConsumerState<EventTypesScreen> createState() => _EventTypesScreenState();
}

final class _EventTypesScreenState extends ConsumerState<EventTypesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(eventTypeControllerProvider.notifier)
            .load(includeArchived: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventTypeControllerProvider);
    final controller = ref.read(eventTypeControllerProvider.notifier);
    // Reactive live presentation labels: watch the profile-scoped overrides
    // AND the live slot bindings so a committed name change or a Goal
    // lifecycle change re-projects the list. Loading/error keeps the
    // prospective labels (display-only fallback; writes always re-validate).
    final profileId = ref.watch(goalProfileIdProvider);
    final overrides = ref
        .watch(goalEventTypeNameOverridesProvider(profileId))
        .value;
    final bindings = ref
        .watch(liveGoalEventTypeBindingsProvider(profileId))
        .value;
    return Scaffold(
      appBar: InternalAppBar(
        title: const Text('Event Types'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Restore system defaults',
            onPressed: () => _restoreDefaults(context, controller),
            icon: const Icon(Icons.restore),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('create-custom-event-type'),
        tooltip: 'Create custom Event Type',
        onPressed: () => context.push(RoutePaths.eventTypeCreate),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
                children: <Widget>[
                  if (state.message != null)
                    MaterialBanner(
                      content: Text(state.message!),
                      actions: <Widget>[
                        TextButton(
                          onPressed: controller.clearMessage,
                          child: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  const _TypeSectionTitle(title: 'Active Event Types'),
                  for (final type in state.eventTypes.where(
                    (type) => type.isCreationVisible,
                  ))
                    _buildTypeCard(
                      context,
                      controller,
                      state,
                      type,
                      bindings,
                      overrides,
                    ),
                  // The six canonical keys NEVER appear under the legacy
                  // heading: hiding a live slot must not expose its row in a
                  // different section.
                  if (state.eventTypes.any(
                    (type) =>
                        !type.isCreationVisible &&
                        CanonicalGoalSlot.tryByEventTypeKey(
                              type.stableKey,
                            ) ==
                            null,
                  ))
                    const _TypeSectionTitle(
                      title: 'Legacy / historical Event Types',
                    ),
                  for (final type in state.eventTypes.where(
                    (type) =>
                        !type.isCreationVisible &&
                        CanonicalGoalSlot.tryByEventTypeKey(
                              type.stableKey,
                            ) ==
                            null,
                  ))
                    _buildTypeCard(
                      context,
                      controller,
                      state,
                      type,
                      bindings,
                      overrides,
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _restoreDefaults(
    BuildContext context,
    EventTypeController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore system defaults?'),
        content: const Text(
          'System Event Type appearance and mappings will be restored. '
          'Existing events, reports, mappings captured on history, and ledger '
          'entries are not changed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.restoreSystemDefaults();
    }
  }

  static String _subtitle(EventType type) {
    final mapping = type.indicatorKeys.isEmpty
        ? 'No Life Goal mapping'
        : type.indicatorKeys.join(', ');
    final kind = type.isSystem ? 'System' : 'Custom';
    final archived = type.isArchived ? ' · Archived' : '';
    return '$kind$archived · $mapping · '
        '${type.defaultDurationMinutes} min default';
  }

  Widget _buildTypeCard(
    BuildContext context,
    EventTypeController controller,
    EventTypeState state,
    EventType type,
    Map<int, LiveGoalEventTypeBinding>? bindings,
    Map<String, GoalEventTypeNameOverride>? overrides,
  ) {
    final accent = PlannerEventColorResolver.accentColorForType(
      type,
      state.resolvedEventColorsByTypeId,
    );
    return Card(
      child: ListTile(
        key: Key('event-type-${type.stableKey}'),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.2),
          child: Icon(_icon(type.icon), color: accent),
        ),
        title: Text(_liveTitle(type, bindings, overrides)),
        subtitle: Text(_subtitle(type)),
        trailing: type.isLockedWliType
            ? IconButton(
                tooltip: 'Edit Event Type',
                onPressed: () => unawaited(
                  showLiveGoalPresentationEditor(
                    context,
                    ref,
                    eventTypeStableKey: type.stableKey,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined),
              )
            : type.isSystem
            ? const Tooltip(
                message: 'Protected system type',
                child: Icon(Icons.lock_outline, size: 19),
              )
            : IconButton(
                tooltip: type.isArchived
                    ? 'Restore Event Type'
                    : 'Archive Event Type',
                onPressed: () => controller.setArchived(type, !type.isArchived),
                icon: Icon(
                  type.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
              ),
        onTap: type.isSystem
            ? null
            : () => context.push('${RoutePaths.eventTypes}/${type.id}/edit'),
      ),
    );
  }

  /// Settings display label for one row: the live Goal's effective name
  /// (MANUAL override, else Goal title) when this canonical row currently
  /// has a valid live occupant; otherwise the pure prospective alias law
  /// (Study & Planning for the exact untouched Study row) over the raw
  /// label. Cached provider state is DISPLAY ONLY — every save freshly
  /// re-resolves and re-validates live occupancy.
  static String _liveTitle(
    EventType type,
    Map<int, LiveGoalEventTypeBinding>? bindings,
    Map<String, GoalEventTypeNameOverride>? overrides,
  ) {
    final slot = CanonicalGoalSlot.tryByEventTypeKey(type.stableKey);
    if (slot == null || bindings == null) {
      return EventTypePresentation.prospectiveLabel(type);
    }
    final binding = bindings[slot.slotIndex];
    if (binding == null) {
      return EventTypePresentation.prospectiveLabel(type);
    }
    final stored = overrides?[binding.goalId];
    if (stored != null && stored.eventTypeStableKey == type.stableKey) {
      return stored.name;
    }
    return binding.title.trim();
  }

  static IconData _icon(EventTypeIcon icon) {
    return switch (icon) {
      EventTypeIcon.calendar => Icons.event_outlined,
      EventTypeIcon.temple => Icons.church_outlined,
      EventTypeIcon.scripture => Icons.menu_book_outlined,
      EventTypeIcon.exercise => Icons.fitness_center,
      EventTypeIcon.budget => Icons.pie_chart_outline,
      EventTypeIcon.job => Icons.work_outline,
      EventTypeIcon.connection => Icons.people_outline,
      EventTypeIcon.appointment => Icons.schedule,
      EventTypeIcon.work => Icons.business_center_outlined,
      EventTypeIcon.personal => Icons.person_outline,
    };
  }
}

final class _TypeSectionTitle extends StatelessWidget {
  const _TypeSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(title, style: InternalScreen.sectionHeading),
    );
  }
}
