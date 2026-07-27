import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';

final class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(permissionSummariesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Permissions')),
      body: SafeArea(
        child: summaries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _PermissionError(
            onRetry: () => ref.invalidate(permissionSummariesProvider),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              const Text(
                'Permissions are requested only when you start the feature '
                'that needs them. Denying all optional permissions keeps core '
                'local planning available.',
              ),
              const SizedBox(height: 20),
              for (final item in items)
                Card(
                  child: ListTile(
                    leading: Icon(_icon(item.permission)),
                    title: Text(item.title),
                    subtitle: Text(item.purpose),
                    trailing: Semantics(
                      label: '${item.title} status ${_stateLabel(item.state)}',
                      child: Chip(label: Text(_stateLabel(item.state))),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('open-system-settings-button'),
                onPressed: () async {
                  final opened = await ref
                      .read(permissionGatewayProvider)
                      .openSystemSettings();
                  if (!context.mounted) {
                    return;
                  }
                  if (!opened) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Android app settings could not be opened.',
                        ),
                      ),
                    );
                  }
                  ref.invalidate(permissionSummariesProvider);
                },
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Android app settings'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Opening Settings does not delete internal records. If a '
                'permission is revoked, existing planner data remains intact.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(OptionalPermission permission) {
    return switch (permission) {
      OptionalPermission.contacts => Icons.contacts_outlined,
      OptionalPermission.notifications => Icons.notifications_outlined,
      OptionalPermission.foregroundLocation => Icons.location_on_outlined,
      OptionalPermission.calendar => Icons.calendar_month_outlined,
    };
  }

  static String _stateLabel(PermissionState state) {
    return switch (state) {
      PermissionState.notRequested => 'Not requested',
      PermissionState.granted => 'Granted',
      PermissionState.denied => 'Denied',
      PermissionState.revoked => 'Revoked',
      PermissionState.unavailable => 'Unavailable',
    };
  }
}

final class _PermissionError extends StatelessWidget {
  const _PermissionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Permission status could not be read. No permission was requested.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
