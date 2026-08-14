import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

/// Duplicate detection is advisory only — it flags candidate pairs from
/// normalized phone/email; the user always decides.  Merging consolidates
/// Event links, Task links, occurrence participant snapshots, groups, tags,
/// methods, notes, and Timeline under a survivor; absorbed identities stay
/// historically traceable and are never deleted as data loss.
final class MergeContactsScreen extends ConsumerStatefulWidget {
  const MergeContactsScreen({super.key});

  @override
  ConsumerState<MergeContactsScreen> createState() =>
      _MergeContactsScreenState();
}

final class _MergeContactsScreenState
    extends ConsumerState<MergeContactsScreen> {
  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(duplicateCandidatesProvider);
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Find Duplicates')),
      body: candidatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(
          child: Text('Duplicate analysis could not be opened.'),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No possible duplicates found. Matching is advisory and '
                  'never merges automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.secondaryTextOf(context),
                  ),
                ),
              ),
            );
          }
          return ListView(
            key: const Key('merge-candidates-list'),
            padding: InternalScreen.pagePadding,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Matching is advisory — it compares normalized phone and '
                  'email only. You always decide what to merge.',
                  style: TextStyle(
                    color: AppTheme.secondaryTextOf(context),
                    fontSize: 13,
                  ),
                ),
              ),
              for (final group in groups)
                _CandidateGroup(
                  group: group,
                  onMerge: (survivorId, absorbedId) =>
                      unawaited(_startMerge(group, survivorId, absorbedId)),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startMerge(
    List<Contact> group,
    String survivorId,
    String absorbedId,
  ) async {
    final profileId = ref.read(contactProfileIdProvider);
    final repository = ref.read(contactRepositoryProvider);
    try {
      final plan = await repository.readMergePlan(
        profileId: profileId,
        survivorId: survivorId,
        absorbedIds: <String>[absorbedId],
      );
      if (!mounted) {
        return;
      }
      final choices = await showModalBottomSheet<ContactMergeChoices>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => _MergeChoicesSheet(plan: plan),
      );
      if (choices == null || !mounted) {
        return;
      }
      final merged = await repository.mergeContacts(
        profileId: profileId,
        survivorId: survivorId,
        absorbedIds: <String>[absorbedId],
        choices: choices,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merged into ${merged.displayName}.')),
      );
    } on ContactValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

final class _CandidateGroup extends ConsumerWidget {
  const _CandidateGroup({required this.group, required this.onMerge});

  final List<Contact> group;
  final void Function(String survivorId, String absorbedId) onMerge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: Key('merge-candidate-${group.first.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceVariantOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Possible duplicate',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryTextOf(context),
            ),
          ),
          const SizedBox(height: 8),
          for (final contact in group)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceRaisedOf(context),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      contact.initials,
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          contact.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _methodSummary(ref, contact),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.secondaryTextOf(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            key: Key('choose-survivor-${group.first.id}'),
            onPressed: () => _chooseSurvivor(context, ref),
            child: const Text('Merge...'),
          ),
        ],
      ),
    );
  }

  void _chooseSurvivor(BuildContext context, WidgetRef ref) {
    unawaited(
      showModalBottomSheet<({String survivorId, String absorbedId})>(
        context: context,
        useSafeArea: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Choose which record survives',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              for (final contact in group)
                ListTile(
                  key: Key('survivor-option-${contact.id}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text(contact.displayName),
                  subtitle: Text(_methodSummary(ref, contact)),
                  onTap: () {
                    final survivorId = contact.id;
                    final absorbedId = group
                        .where((c) => c.id != survivorId)
                        .first
                        .id;
                    Navigator.of(
                      sheetContext,
                    ).pop((survivorId: survivorId, absorbedId: absorbedId));
                  },
                ),
            ],
          ),
        ),
      ).then((result) {
        if (result != null) {
          onMerge(result.survivorId, result.absorbedId);
        }
      }),
    );
  }

  static String _methodSummary(WidgetRef ref, Contact contact) {
    final detail = ref.watch(contactDetailProvider(contact.id)).value;
    final phones = detail == null
        ? const <String>[]
        : <String>[
            for (final method in detail.methods)
              if (method.type == ContactMethodType.phone &&
                  method.rawValue.isNotEmpty)
                method.rawValue,
          ];
    final emails = detail == null
        ? const <String>[]
        : <String>[
            for (final method in detail.methods)
              if (method.type == ContactMethodType.email &&
                  method.rawValue.isNotEmpty)
                method.rawValue,
          ];
    return <String>[...phones, ...emails].join(' • ');
  }
}

/// Compare the two records field by field and pick which value survives.
final class _MergeChoicesSheet extends StatefulWidget {
  const _MergeChoicesSheet({required this.plan});

  final ContactMergePlan plan;

  @override
  State<_MergeChoicesSheet> createState() => _MergeChoicesSheetState();
}

final class _MergeChoicesSheetState extends State<_MergeChoicesSheet> {
  late final Map<String, String> _choices = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final survivor = plan.survivor;
    final absorbed = plan.absorbed;
    final fields = <String, String Function(Contact)>{
      'Name': (c) => c.displayName,
      'Address': (c) => c.addressText ?? '',
      'Preferred method': (c) => c.preferredContactMethod.name,
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const Text(
              'Compare records',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${absorbed.length} absorbed record will keep its links, '
              'Timeline, and notes history, now under the survivor.',
              style: TextStyle(
                color: AppTheme.secondaryTextOf(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in fields.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryTextOf(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    RadioGroup<String>(
                      groupValue: _choices[entry.key] ?? survivor.id,
                      onChanged: (value) => setState(() {
                        _choices[entry.key] = value ?? survivor.id;
                      }),
                      child: Column(
                        children: <Widget>[
                          for (final (index, contact) in [
                            survivor,
                            ...absorbed,
                          ].indexed)
                            RadioListTile<String>(
                              key: Key('merge-value-${entry.key}-$index'),
                              value: contact.id,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                entry.value(contact),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                contact.id == survivor.id
                                    ? 'Survivor'
                                    : 'Absorbed',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('confirm-merge'),
              onPressed: () =>
                  Navigator.of(context).pop(ContactMergeChoices(_choices)),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Merge'),
            ),
          ],
        ),
      ),
    );
  }
}
