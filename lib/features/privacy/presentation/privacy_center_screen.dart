import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/features/privacy/application/privacy_providers.dart';
import 'package:rmplanner/features/privacy/domain/deletion_impact.dart';
import 'package:rmplanner/features/privacy/domain/privacy_settings.dart';

final class PrivacyCenterScreen extends ConsumerWidget {
  const PrivacyCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyControllerProvider);
    final controller = ref.read(privacyControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and Data')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              'Privacy controls',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Next Transfer works locally with every optional permission '
              'denied. Account sign-in and Privacy Lock are separate.',
            ),
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    key: const Key('privacy-lock-switch'),
                    value: privacy.settings.lockEnabled,
                    onChanged: privacy.isBusy
                        ? null
                        : (enabled) async {
                            if (enabled) {
                              await controller.enableLock();
                            } else {
                              await controller.disableLock();
                            }
                          },
                    secondary: const Icon(Icons.lock_outline),
                    title: const Text('Privacy Lock'),
                    subtitle: const Text(
                      'Uses Android biometrics or your device credential. '
                      'Next Transfer never stores biometric data or an app PIN.',
                    ),
                  ),
                  if (privacy.isBusy)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (privacy.message != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          privacy.message!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                key: const Key('notification-preview-switch'),
                value:
                    privacy.settings.notificationPreviewMode ==
                    NotificationPreviewMode.showContent,
                onChanged: (showContent) async {
                  await controller.setNotificationPreviewMode(
                    showContent
                        ? NotificationPreviewMode.showContent
                        : NotificationPreviewMode.hidden,
                  );
                },
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Show content in notification previews'),
                subtitle: const Text(
                  'Off by default. This preference will apply when reminder '
                  'notifications are introduced.',
                ),
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Where data lives'),
            const SizedBox(height: 8),
            const _BoundaryTile(
              icon: Icons.smartphone_outlined,
              title: 'Local',
              detail:
                  'Your planner database is stored on this device and remains '
                  'available offline.',
            ),
            const _BoundaryTile(
              icon: Icons.cloud_outlined,
              title: 'Synced',
              detail:
                  'Optional account sync is not active. Future sync will '
                  'identify exactly which eligible records leave the device.',
            ),
            const _BoundaryTile(
              icon: Icons.shield_outlined,
              title: 'Local-only and Extra Private',
              detail:
                  'Raw BetterCalendar imports and private reflections do not '
                  'enter sync, analytics, diagnostics, or the outbox.',
            ),
            const _BoundaryTile(
              icon: Icons.key_outlined,
              title: 'Authentication secrets',
              detail:
                  'Future account tokens use Android secure storage, not the '
                  'planner database or backups.',
            ),
            const SizedBox(height: 20),
            const Text(
              'Next Transfer does not claim full-database encryption or '
              'end-to-end encryption. It states only protections implemented '
              'and verified.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Android screenshots, screen recordings, and normal recent-app '
              'previews are allowed. Privacy Lock, notification redaction, '
              'secure token storage, private attachments, and sensitive '
              'logging restrictions remain independent protections.',
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'Review and control'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Permissions'),
                    subtitle: const Text(
                      'Review purpose and current status. No permission is '
                      'requested from this page.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.permissions),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Diagnostic export preview'),
                    subtitle: const Text(
                      'Review sanitized details before any future export.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RoutePaths.diagnosticPreview),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('deletion-impact-tile'),
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Review deletion impacts'),
                    subtitle: const Text(
                      'No data is deleted by opening this explanation.',
                    ),
                    trailing: const Icon(Icons.info_outline),
                    onTap: () => _showDeletionImpact(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Attachments use scoped system pickers. Next Transfer does not '
              'request broad storage access or background location.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeletionImpact(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deletion impacts'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'These are separate operations. Review the affected copy '
                  'before confirming any future destructive action.',
                ),
                const SizedBox(height: 16),
                for (final impact in DeletionImpactCatalog.values) ...[
                  Text(
                    impact.title,
                    style: Theme.of(dialogContext).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(impact.explanation),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

final class _BoundaryTile extends StatelessWidget {
  const _BoundaryTile({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(detail),
      ),
    );
  }
}
