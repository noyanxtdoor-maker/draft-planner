import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';

/// Dedicated recoverable-contact lifecycle surface. Archive and Recently
/// Deleted deliberately stay separate; neither tab contains a hard-delete or
/// retention countdown because historical Event/Task relationships still own
/// restrictive Contact references.
final class ContactLifecycleScreen extends ConsumerWidget {
  const ContactLifecycleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.read(contactProfileIdProvider);
    ref.watch(contactChangesProvider(profileId));
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: InternalAppBar(
          title: const Text('Contacts'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Archived'),
              Tab(text: 'Recently Deleted'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _LifecycleList(lifecycleState: ContactLifecycleState.archived),
            _LifecycleList(
              lifecycleState: ContactLifecycleState.recentlyDeleted,
            ),
          ],
        ),
      ),
    );
  }
}

final class _LifecycleList extends ConsumerWidget {
  const _LifecycleList({required this.lifecycleState});

  final ContactLifecycleState lifecycleState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileId = ref.read(contactProfileIdProvider);
    final future = ref.read(contactRepositoryProvider).readLifecycleContacts(
      profileId: profileId,
      lifecycleState: lifecycleState,
      today: ref.read(plannerDateSourceProvider).today(),
    );
    return FutureBuilder<List<ContactSummary>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final contacts = snapshot.data!;
        if (contacts.isEmpty) {
          return Center(
            child: Text(
              lifecycleState == ContactLifecycleState.archived
                  ? 'No archived contacts.'
                  : 'No recently deleted contacts.',
              style: TextStyle(color: AppTheme.secondaryTextOf(context)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: contacts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final summary = contacts[index];
            final timestamp = lifecycleState == ContactLifecycleState.archived
                ? summary.contact.archivedAtUtc
                : summary.contact.deletedAtUtc;
            return ListTile(
              key: Key('contact-lifecycle-row-${summary.contact.id}'),
              leading: ContactGroupDot(summary: summary),
              title: Text(summary.contact.displayName),
              subtitle: timestamp == null
                  ? null
                  : Text(
                      '${lifecycleState == ContactLifecycleState.archived ? 'Archived' : 'Deleted'} ${_dateLabel(timestamp)}',
                    ),
              trailing: TextButton(
                key: Key('contact-lifecycle-restore-${summary.contact.id}'),
                onPressed: () => unawaited(_restore(ref, summary.contact.id)),
                child: const Text('Restore'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restore(WidgetRef ref, String contactId) async {
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    if (lifecycleState == ContactLifecycleState.archived) {
      await repository.restoreContact(profileId: profileId, contactId: contactId);
    } else {
      await repository.restoreRecentlyDeletedContact(
        profileId: profileId,
        contactId: contactId,
      );
    }
  }

  static String _dateLabel(DateTime value) =>
      value.toLocal().toIso8601String().split('T').first;
}
