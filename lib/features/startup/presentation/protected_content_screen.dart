import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

final class ProtectedContentScreen extends ConsumerWidget {
  const ProtectedContentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.lock_outline, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Next Transfer is locked',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use Android biometrics or your device credential to open '
                  'your private local planner.',
                  textAlign: TextAlign.center,
                ),
                if (privacy.message != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      privacy.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('unlock-button'),
                  onPressed: privacy.isBusy
                      ? null
                      : () async {
                          final unlocked = await ref
                              .read(privacyControllerProvider.notifier)
                              .authenticate();
                          if (unlocked) {
                            await ref
                                .read(startupControllerProvider.notifier)
                                .initialize();
                          }
                        },
                  icon: privacy.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Authentication failure never deletes, resets, or changes '
                  'your planner data.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
