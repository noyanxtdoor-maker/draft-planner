import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';

/// Canonical centralized Settings home (Pack 3, Phase 4).
///
/// Only sections and rows that are real and supported are shown.  Omitted
/// here (with reasons documented in the Pack 3 report):
///   - Appearance: dark-only architecture (hard-coded AppTheme tokens on
///     every screen) cannot safely support a complete Light/System theme or
///     a Rose/Blue accent switch within Pack 3 (locked policy 10).
///   - Notifications: no standalone real notification preference exists
///     beyond the permission status already covered by Permissions.
///   - Accessibility / Country and Language: no functional preferences
///     exist to expose (locked policy 8).
///   - Contacts: the Contacts slice is not an implemented feature yet.
///   - Account and Sync: guest-first; no fake sync status is shown.
///
/// Settings is the only top-level drawer destination for Privacy and Data,
/// Permissions, and the planner/calendar preferences: they are never
/// duplicated as separate drawer rows.
final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: InternalScreen.pagePadding,
          children: <Widget>[
            const _SettingsSectionLabel('PRIVACY AND DEVICE'),
            Card(
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.outline),
              ),
              child: Column(
                children: <Widget>[
                  ListTile(
                    key: const Key('settings-privacy-data'),
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Privacy and Data'),
                    subtitle: const Text(
                      'Privacy Lock, permissions, local data, and diagnostics',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push(RoutePaths.privacyCenter),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('settings-permissions'),
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Permissions'),
                    subtitle: const Text(
                      'Notifications, contacts, and calendar status',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push(RoutePaths.permissions),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SettingsSectionLabel('PLANNER AND CALENDAR'),
            Card(
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppTheme.outline),
              ),
              child: Column(
                children: <Widget>[
                  ListTile(
                    key: const Key('settings-planner-calendar'),
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Planner and Calendar'),
                    subtitle: const Text(
                      'Timeline, Event Types, snapping, zoom, and display',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push(RoutePaths.plannerSettings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('settings-colors'),
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Colors'),
                    subtitle: const Text('Planner Event color preferences'),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => context.push(RoutePaths.colors),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
        child: Text(
          label,
          key: Key(
            'settings-section-${label.toLowerCase().replaceAll(' ', '-')}',
          ),
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12.5,
            height: 16 / 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Color(0xFF9CA0A6),
          ),
        ),
      ),
    );
  }
}
