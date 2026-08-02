import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    key: const Key('settings-planner-calendar'),
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('Planner and Calendar'),
                    subtitle: const Text(
                      'Timeline, Event Types, snapping, zoom, and display',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.plannerSettings),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('settings-colors'),
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Colors'),
                    subtitle: const Text('Planner Event color preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.colors),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('settings-privacy-data'),
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Privacy and Data'),
                    subtitle: const Text(
                      'Privacy Lock, permissions, local data, and diagnostics',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.privacyCenter),
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
