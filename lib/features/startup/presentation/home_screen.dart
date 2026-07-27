import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/next_transfer_app.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_snapshot.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startupControllerProvider);
    if (state is! StartupReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final environment = ref.watch(appEnvironmentProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Privacy and Data',
            onPressed: () => context.push(RoutePaths.privacyCenter),
            icon: const Icon(Icons.shield_outlined),
          ),
          if (environment.showDebugBanner)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  environment.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Welcome, ${state.profile.effectiveName}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Your private local planner is ready.'),
            const SizedBox(height: 24),
            _StatusCard(
              icon: Icons.offline_bolt_outlined,
              title: 'Local data',
              value: 'Ready offline',
              detail: 'The local database is the immediate source.',
            ),
            const SizedBox(height: 12),
            _StatusCard(
              icon: Icons.account_circle_outlined,
              title: 'Account',
              value: _accountLabel(state.accountSessionState),
              detail: 'Account setup is optional and remains available later.',
            ),
            const SizedBox(height: 12),
            _StatusCard(
              icon: Icons.sync_disabled,
              title: 'Synchronization',
              value: _syncLabel(state.syncState),
              detail: 'Remote services do not block local navigation.',
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Weekly targets are not set',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The six approved Life Indicator definitions are ready '
                      'without any Actual contributions. Target setup remains '
                      'optional and will live in Weekly Planning.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _editDisplayName(context, ref, state),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit display name'),
            ),
          ],
        ),
      ),
    );
  }

  static String _accountLabel(AccountSessionState state) {
    return switch (state) {
      AccountSessionState.localOnly => 'Not connected — optional',
      AccountSessionState.signedIn => 'Connected — local use remains available',
      AccountSessionState.expired =>
        'Session expired — local use remains available',
    };
  }

  static String _syncLabel(LocalSyncState state) {
    return switch (state) {
      LocalSyncState.notConfigured => 'Not enabled in VS-01',
      LocalSyncState.idle => 'Idle',
    };
  }

  Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    StartupReady state,
  ) async {
    final controller = TextEditingController(text: state.profile.displayName);
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit display name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Display name (optional)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result != null && context.mounted) {
      await ref
          .read(startupControllerProvider.notifier)
          .updateDisplayName(result);
    }
  }
}

final class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
