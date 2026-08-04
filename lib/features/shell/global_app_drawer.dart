import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/local_profile.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

/// Catalog of global app destinations surfaced in the global drawer.
///
/// The catalog maps user-facing names onto real, currently implemented
/// routes. Destinations whose destinations are not yet wired (for
/// example the Contacts slice or Resources panes) are intentionally
/// omitted or rendered as unavailable entries so that the drawer never
/// exposes internal slice names like "VS-08" or "authorized build".
@immutable
final class GlobalDrawerEntry {
  const GlobalDrawerEntry._({
    required this.id,
    required this.label,
    required this.icon,
    this.routePath,
    this.subtitle,
    this.group = GlobalDrawerGroup.account,
    this.availability = GlobalDrawerEntryAvailability.available,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? routePath;
  final String? subtitle;
  final GlobalDrawerGroup group;
  final GlobalDrawerEntryAvailability availability;

  bool get isAvailable => availability == GlobalDrawerEntryAvailability.available;
}

enum GlobalDrawerGroup { profile, planning, programs, account }

enum GlobalDrawerEntryAvailability { available, unavailable }

abstract final class GlobalDrawerCatalog {
  static const List<GlobalDrawerEntry> entries = <GlobalDrawerEntry>[
    // Profile section is rendered separately because the data is
    // provider-driven rather than static.
    GlobalDrawerEntry._(
      id: 'drawer-planner',
      label: 'Planner',
      icon: Icons.calendar_month_outlined,
      routePath: RoutePaths.planner,
      group: GlobalDrawerGroup.planning,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-planner-settings',
      label: 'Planner and Calendar',
      icon: Icons.tune_outlined,
      routePath: RoutePaths.plannerSettings,
      subtitle: 'Timeline, Event Types, snapping, zoom, display',
      group: GlobalDrawerGroup.planning,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-event-types',
      label: 'Event Types',
      icon: Icons.category_outlined,
      routePath: RoutePaths.eventTypes,
      subtitle: 'Color, indicator, report-required, backup mapping',
      group: GlobalDrawerGroup.planning,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-weekly-planning',
      label: 'Weekly Planning',
      icon: Icons.calendar_view_week_outlined,
      routePath: RoutePaths.weeklyPlanning,
      subtitle: 'Targets and weekly review',
      group: GlobalDrawerGroup.planning,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-weekly-planning-history',
      label: 'Weekly Plan History',
      icon: Icons.history_outlined,
      routePath: RoutePaths.weeklyPlanningHistory,
      group: GlobalDrawerGroup.planning,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-activity-history',
      label: 'Activity History',
      icon: Icons.fact_check_outlined,
      routePath: RoutePaths.activityHistory,
      subtitle: 'Outcome Reports and corrections',
      group: GlobalDrawerGroup.planning,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-indicators',
      label: 'Life Indicators',
      icon: Icons.insights_outlined,
      routePath: RoutePaths.progress,
      subtitle: 'Indicators and their progress',
      group: GlobalDrawerGroup.planning,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-program-pathway',
      label: 'BYU-Pathway Worldwide',
      icon: Icons.school_outlined,
      group: GlobalDrawerGroup.programs,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-program-myplan',
      label: 'My Plan',
      icon: Icons.assignment_outlined,
      group: GlobalDrawerGroup.programs,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-program-myplan-conf',
      label: 'My Plan Conference',
      icon: Icons.groups_outlined,
      group: GlobalDrawerGroup.programs,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-program-self-reliance',
      label: 'Self-Reliance Resources',
      icon: Icons.menu_book_outlined,
      group: GlobalDrawerGroup.programs,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-program-country',
      label: 'Country Requirements',
      icon: Icons.public_outlined,
      group: GlobalDrawerGroup.programs,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-program-links',
      label: 'Official Links',
      icon: Icons.link_outlined,
      group: GlobalDrawerGroup.programs,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      routePath: RoutePaths.settings,
      subtitle: 'Planner and Calendar, Privacy and Data, app preferences',
      group: GlobalDrawerGroup.account,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-privacy',
      label: 'Privacy and Data',
      icon: Icons.shield_outlined,
      routePath: RoutePaths.privacyCenter,
      subtitle: 'Privacy Lock, permissions, local data, diagnostics',
      group: GlobalDrawerGroup.account,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-permissions',
      label: 'Permissions',
      icon: Icons.lock_outline,
      routePath: RoutePaths.permissions,
      group: GlobalDrawerGroup.account,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-appearance',
      label: 'Appearance',
      icon: Icons.palette_outlined,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-accessibility',
      label: 'Accessibility',
      icon: Icons.accessibility_new_outlined,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-sync',
      label: 'Sync and Backup',
      icon: Icons.cloud_sync_outlined,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-export',
      label: 'Export Data',
      icon: Icons.ios_share_outlined,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-help',
      label: 'Help and Support',
      icon: Icons.help_outline,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-about',
      label: 'About',
      icon: Icons.info_outline,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-country-language',
      label: 'Country and Language',
      icon: Icons.translate_outlined,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
    GlobalDrawerEntry._(
      id: 'drawer-account-notifications',
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      group: GlobalDrawerGroup.account,
      availability: GlobalDrawerEntryAvailability.unavailable,
    ),
  ];

  /// The drawer groups in the order they appear in the drawer.
  static const List<GlobalDrawerGroup> groupOrder = <GlobalDrawerGroup>[
    GlobalDrawerGroup.planning,
    GlobalDrawerGroup.programs,
    GlobalDrawerGroup.account,
  ];

  static String labelFor(GlobalDrawerGroup group) {
    return switch (group) {
      GlobalDrawerGroup.profile => 'Profile',
      GlobalDrawerGroup.planning => 'Planning and Records',
      GlobalDrawerGroup.programs => 'Programs and Resources',
      GlobalDrawerGroup.account => 'Account and App',
    };
  }
}

/// The global app drawer opened from the hamburger on every permanent
/// screen.
///
/// The drawer slides from the left, respects the status bar and the
/// bottom safe area, supports Android Back dismissal, highlights the
/// current destination using the pink accent, and remains vertically
/// scrollable. It is wired into the shared shell so Home, Planner,
/// Pathways, and Contacts all open the same drawer.
class GlobalAppDrawer extends ConsumerWidget {
  const GlobalAppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(startupControllerProvider);
    final currentLocation =
        GoRouterState.of(context).matchedLocation;
    final LocalProfile? profile = switch (profileState) {
      StartupReady(:final profile) => profile,
      _ => null,
    };
    return Drawer(
      key: const Key('global-app-drawer'),
      backgroundColor: AppTheme.surface,
      surfaceTintColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _DrawerHeader(profile: profile),
            Expanded(
              child: ListView(
                key: const Key('global-app-drawer-list'),
                padding: const EdgeInsets.only(bottom: 16),
                children: <Widget>[
                  for (final group in GlobalDrawerCatalog.groupOrder) ...<Widget>[
                    _DrawerGroupHeader(label: GlobalDrawerCatalog.labelFor(group)),
                    for (final entry in GlobalDrawerCatalog.entries.where(
                      (e) => e.group == group,
                    ))
                      _DrawerEntryTile(
                        entry: entry,
                        isCurrent: entry.routePath != null &&
                            currentLocation.startsWith(entry.routePath!),
                      ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.profile});

  final LocalProfile? profile;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName?.trim();
    final fallback = profile?.localName;
    final resolvedName = (name == null || name.isEmpty) ? fallback : name;
    final colorScheme = Theme.of(context).colorScheme;
    final initialSource = resolvedName == null || resolvedName.isEmpty
        ? 'N'
        : resolvedName.characters.first.toUpperCase();
    return Container(
      key: const Key('global-app-drawer-header'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(color: AppTheme.outline),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.rose.withValues(alpha: 0.18),
            child: Text(
              initialSource,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  resolvedName == null || resolvedName.isEmpty
                      ? 'Your profile'
                      : resolvedName,
                  key: const Key('global-app-drawer-name'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile == null
                      ? 'Local profile'
                      : 'Local profile · ready',
                  key: const Key('global-app-drawer-state'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerGroupHeader extends StatelessWidget {
  const _DrawerGroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        label,
        key: Key('drawer-group-${label.toLowerCase().replaceAll(" ", "-")}'),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.rose,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _DrawerEntryTile extends StatelessWidget {
  const _DrawerEntryTile({required this.entry, required this.isCurrent});

  final GlobalDrawerEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = isCurrent ? colorScheme.primary : colorScheme.onSurface;
    final iconColor = isCurrent ? colorScheme.primary : colorScheme.onSurface;
    final Widget leadingIcon = Icon(
      entry.icon,
      color: iconColor,
      size: 22,
    );
    final Widget trailing = isCurrent
        ? Icon(Icons.circle, color: colorScheme.primary, size: 10)
        : const Icon(Icons.chevron_right, size: 18);
    final onTap = entry.isAvailable && entry.routePath != null
        ? () {
            Navigator.of(context).pop();
            GoRouter.of(context).go(entry.routePath!);
          }
        : () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    '${entry.label} will open when its slice is delivered.',
                  ),
                ),
              );
          };
    return ListTile(
      key: Key(entry.id),
      leading: leadingIcon,
      title: Text(
        entry.label,
        style: TextStyle(
          color: titleColor,
          fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: entry.subtitle == null
          ? null
          : Text(
              entry.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
