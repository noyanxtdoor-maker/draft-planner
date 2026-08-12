import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';
import 'package:rmplanner/features/startup/domain/startup_state.dart';

final class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startupControllerProvider);
    final reason = state is StartupRecovery
        ? state.reasonCode
        : 'database_open_failed';

    return Scaffold(
      appBar: const InternalAppBar(title: Text('Local data needs attention')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Icon(
              Icons.health_and_safety_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Next Transfer did not erase or recreate your local data.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const Text(
              'The local database could not be opened safely. Retry after '
              'closing other copies of the app or restarting the device.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Do not reset local data unless you understand that a reset '
                  'permanently removes this device’s Local Profile and records. '
                  'VS-01 provides no automatic reset.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Diagnostic code: $reason',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                unawaited(
                  ref.read(startupControllerProvider.notifier).initialize(),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry local startup'),
            ),
          ],
        ),
      ),
    );
  }
}
