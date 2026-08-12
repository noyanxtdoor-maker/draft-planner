import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/external_handoff.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_timeline_view.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/domain/planner_task.dart';

/// Contact Profile + Timeline (two tabs only, no Progress).  Profile holds
/// Contact Information, Upcoming/Follow-Up, Availability, Groups & Tags,
/// Notes, and Record Details.  The FAB offers New Event / New Task / Add
/// Note; follow-up stays a Task or Calendar Event, never a third entity.
final class ContactDetailScreen extends ConsumerStatefulWidget {
  const ContactDetailScreen({required this.contactId, super.key});

  final String contactId;

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

final class _ContactDetailScreenState
    extends ConsumerState<ContactDetailScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(contactDetailProvider(widget.contactId));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: InternalAppBar(title: const Text('Contact')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: InternalAppBar(title: const Text('Contact')),
        body: const Center(child: Text('Contact could not be opened.')),
      ),
      data: (detail) => _build(detail),
    );
  }

  Widget _build(ContactDetail detail) {
    final contact = detail.contact;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          contact.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.appBarTitle,
        ),
        actions: <Widget>[
          IconButton(
            key: const Key('contact-favorite-toggle'),
            tooltip: contact.isFavorite ? 'Remove favorite' : 'Add favorite',
            icon: Icon(
              contact.isFavorite ? Icons.star : Icons.star_border,
              color: contact.isFavorite ? AppTheme.rose : null,
            ),
            onPressed: () async {
              final repository = ref.read(contactRepositoryProvider);
              final profileId = ref.read(contactProfileIdProvider);
              await repository.setFavorite(
                profileId: profileId,
                contactId: contact.id,
                favorite: !contact.isFavorite,
              );
            },
          ),
          PopupMenuButton<String>(
            key: const Key('contact-detail-overflow'),
            tooltip: 'More options',
            onSelected: (value) => _handleOverflow(value, detail),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'edit', child: Text('Edit contact')),
              PopupMenuItem<String>(
                value: 'merge',
                child: const Text('Find duplicates'),
              ),
              PopupMenuDivider(),
              if (contact.isArchived)
                PopupMenuItem<String>(value: 'restore', child: Text('Restore'))
              else
                PopupMenuItem<String>(value: 'archive', child: Text('Archive')),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _TabBar(
            selectedIndex: _tab,
            onChanged: (index) => setState(() => _tab = index),
          ),
          Expanded(
            child: _tab == 0
                ? _ProfileTab(
                    detail: detail,
                    onEdit: () =>
                        context.push(RoutePaths.contactEdit(contact.id)),
                  )
                : _TimelineTab(contactId: contact.id),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('contact-detail-fab'),
        tooltip: 'Create',
        onPressed: () => _showFabActions(detail),
        backgroundColor: AppTheme.rose,
        foregroundColor: AppTheme.background,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  void _handleOverflow(String value, ContactDetail detail) {
    switch (value) {
      case 'edit':
        unawaited(context.push(RoutePaths.contactEdit(detail.contact.id)));
      case 'merge':
        unawaited(context.push(RoutePaths.mergeContacts));
      case 'archive':
        unawaited(_archive(detail.contact));
      case 'restore':
        unawaited(_restore(detail.contact));
    }
  }

  Future<void> _archive(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive contact?'),
        content: Text(
          '${contact.displayName} will disappear from active lists and '
          'selectors, but every Event, Task, and Timeline record stays '
          'intact and can be restored later.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            key: const Key('confirm-archive-contact'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    await repository.archiveContact(
      profileId: profileId,
      contactId: contact.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.displayName} archived.')),
      );
      unawaited(Navigator.of(context).maybePop());
    }
  }

  Future<void> _restore(Contact contact) async {
    final repository = ref.read(contactRepositoryProvider);
    final profileId = ref.read(contactProfileIdProvider);
    await repository.restoreContact(
      profileId: profileId,
      contactId: contact.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${contact.displayName} restored.')),
      );
    }
  }

  Future<void> _showFabActions(ContactDetail detail) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Create with ${detail.contact.displayName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ListTile(
              key: const Key('fab-new-event'),
              leading: const Icon(Icons.event_outlined),
              title: const Text('New Event'),
              subtitle: const Text(
                'Opens the Event form with this Contact pre-selected in People.',
              ),
              onTap: () => Navigator.of(sheetContext).pop('event'),
            ),
            ListTile(
              key: const Key('fab-new-task'),
              leading: const Icon(Icons.task_alt),
              title: const Text('New Task / Follow-Up'),
              subtitle: const Text('A separate Task, linked to this Contact.'),
              onTap: () => Navigator.of(sheetContext).pop('task'),
            ),
            ListTile(
              key: const Key('fab-add-note'),
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Add Note'),
              onTap: () => Navigator.of(sheetContext).pop('note'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'event':
        await context.push(
          '${RoutePaths.calendarEventCreate}?contacts=${detail.contact.id}',
        );
      case 'task':
        await context.push(
          '${RoutePaths.taskCreate}?contacts=${detail.contact.id}',
        );
      case 'note':
        await _addNote(detail);
    }
  }

  Future<void> _addNote(ContactDetail detail) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          key: const Key('add-note-field'),
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Write a note...'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('save-note-button'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.isNotEmpty && mounted) {
      final repository = ref.read(contactRepositoryProvider);
      final profileId = ref.read(contactProfileIdProvider);
      await repository.addNote(
        profileId: profileId,
        contactId: detail.contact.id,
        text: text,
      );
    }
  }
}

final class _TabBar extends StatelessWidget {
  const _TabBar({required this.selectedIndex, required this.onChanged});

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF2A2D31), width: 1)),
      ),
      child: Row(
        children: <Widget>[
          _TabItem(
            key: const Key('profile-tab'),
            label: 'Profile',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabItem(
            key: const Key('timeline-tab'),
            label: 'Timeline',
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

final class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppTheme.rose : const Color(0xFF9CA0A6),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? AppTheme.rose : Colors.transparent,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile tab
// ---------------------------------------------------------------------------

final class _ProfileTab extends ConsumerWidget {
  const _ProfileTab({required this.detail, required this.onEdit});

  final ContactDetail detail;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = detail.contact;
    final upcomingTasks =
        ref.watch(contactUpcomingTasksProvider(contact.id)).value ??
        const <PlannerTask>[];
    final patterns =
        ref.watch(commonEventPatternsProvider(contact.id)).value ??
        const <CommonEventPattern>[];
    final timeline = ref.watch(contactTimelineProvider(contact.id)).value;
    final nextEvent = timeline?.upcoming.isEmpty ?? true
        ? null
        : timeline!.upcoming.first;

    return ListView(
      key: const Key('contact-profile-tab'),
      padding: const EdgeInsets.only(bottom: 96),
      children: <Widget>[
        _SectionHeader(
          title: 'Contact Information',
          action: _EditAction(label: 'Edit', onTap: onEdit),
        ),
        _ContactInformation(
          detail: detail,
          onAddNote: (text) => ref
              .read(contactRepositoryProvider)
              .addNote(
                profileId: ref.read(contactProfileIdProvider),
                contactId: detail.contact.id,
                text: text,
              ),
        ),
        _SectionHeader(
          title: 'Upcoming / Follow-Up',
          action: _EditAction(
            label: 'Create',
            onTap: () => _createFollowUp(context),
          ),
        ),
        _UpcomingSection(
          nextEventTitle: nextEvent?.title,
          nextEventSubtitle: nextEvent?.subtitle,
          upcomingTasks: upcomingTasks,
          onCreateFollowUp: () => _createFollowUp(context),
        ),
        _SectionHeader(title: 'Availability'),
        _AvailabilitySection(windows: detail.availability, patterns: patterns),
        _SectionHeader(title: 'Groups & Tags'),
        _GroupsTagsSection(
          groups: detail.groups,
          primaryGroupId: detail.primaryGroupId,
          tags: detail.tags,
        ),
        _SectionHeader(
          title: 'Notes',
          action: _EditAction(
            label: 'Add',
            onTap: () => _addNoteFromProfile(context, ref),
          ),
        ),
        _NotesSection(notes: detail.notes),
        _SectionHeader(title: 'Record Details'),
        _RecordDetails(contact: contact),
      ],
    );
  }

  void _createFollowUp(BuildContext context) {
    final contact = detail.contact;
    unawaited(
      showModalBottomSheet<String>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Create Follow-Up',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                key: const Key('follow-up-event'),
                leading: const Icon(Icons.event_outlined),
                title: const Text('Calendar Event'),
                onTap: () => Navigator.of(sheetContext).pop('event'),
              ),
              ListTile(
                key: const Key('follow-up-task'),
                leading: const Icon(Icons.task_alt),
                title: const Text('Task'),
                onTap: () => Navigator.of(sheetContext).pop('task'),
              ),
            ],
          ),
        ),
      ).then((value) async {
        if (value == null || !context.mounted) {
          return;
        }
        if (value == 'event') {
          await context.push(
            '${RoutePaths.calendarEventCreate}?contacts=${contact.id}',
          );
        } else {
          await context.push('${RoutePaths.taskCreate}?contacts=${contact.id}');
        }
      }),
    );
  }

  Future<void> _addNoteFromProfile(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text != null && text.isNotEmpty && context.mounted) {
      final profileId = ref.read(contactProfileIdProvider);
      await ref
          .read(contactRepositoryProvider)
          .addNote(
            profileId: profileId,
            contactId: detail.contact.id,
            text: text,
          );
    }
  }
}

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

final class _EditAction extends StatelessWidget {
  const _EditAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: AppTheme.rose,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}

final class _ContactInformation extends StatelessWidget {
  const _ContactInformation({required this.detail, required this.onAddNote});

  final ContactDetail detail;
  final Future<void> Function(String note) onAddNote;

  @override
  Widget build(BuildContext context) {
    final methods = detail.methods;
    final phone = methods
        .where((m) => m.type == ContactMethodType.phone)
        .toList();
    final email = methods
        .where((m) => m.type == ContactMethodType.email)
        .toList();
    final social = methods
        .where((m) => m.type == ContactMethodType.social)
        .toList();
    final address = detail.contact.addressText;
    final rows = <Widget>[
      for (final method in phone)
        _InfoRow(
          icon: Icons.phone_outlined,
          primary: method.rawValue,
          secondary: method.label ?? 'Phone',
          trailing: _HandoffButtons(
            onCall: () => _handoff(context, 'call', method.rawValue),
            onMessage: () => _handoff(context, 'message', method.rawValue),
          ),
        ),
      for (final method in email)
        _InfoRow(
          icon: Icons.mail_outline,
          primary: method.rawValue,
          secondary: method.label ?? 'Email',
          trailing: _HandoffButtons(
            onEmail: () => _handoff(context, 'email', method.rawValue),
          ),
        ),
      for (final method in social)
        _InfoRow(
          icon: Icons.alternate_email,
          primary: method.rawValue,
          secondary: method.label ?? 'Social Profile',
        ),
      if (address != null && address.isNotEmpty)
        _InfoRow(
          icon: Icons.place_outlined,
          primary: address,
          secondary: 'Address',
        ),
      _InfoRow(
        icon: Icons.touch_app_outlined,
        primary: _preferredLabel(detail.contact.preferredContactMethod),
        secondary: 'Preferred contact method',
      ),
    ];
    return Column(children: rows);
  }

  static String _preferredLabel(ContactPreferredMethod method) {
    return switch (method) {
      ContactPreferredMethod.message => 'Message',
      ContactPreferredMethod.call => 'Call',
      ContactPreferredMethod.email => 'Email',
    };
  }

  Future<void> _handoff(
    BuildContext context,
    String kind,
    String rawValue,
  ) async {
    final launched = switch (kind) {
      'call' => await ExternalHandoff.launchCall(rawValue),
      'message' => await ExternalHandoff.launchSms(rawValue),
      _ => await ExternalHandoff.launchEmail(rawValue),
    };
    if (!launched) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No app is available for this handoff.'),
          ),
        );
      }
      return;
    }
    if (!context.mounted) {
      return;
    }
    // Returning from an external app creates NO factual outcome.  The only
    // record offered is an explicit user-typed note.
    await ExternalHandoff.showReturnSheet(
      context,
      contactDisplayName: detail.contact.displayName,
      onAddNote: onAddNote,
    );
  }
}

final class _HandoffButtons extends StatelessWidget {
  const _HandoffButtons({this.onCall, this.onMessage, this.onEmail});

  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final VoidCallback? onEmail;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onCall != null)
          IconButton(
            key: const Key('handoff-call'),
            tooltip: 'Call',
            onPressed: onCall,
            icon: const Icon(Icons.call_outlined, size: 20),
          ),
        if (onMessage != null)
          IconButton(
            key: const Key('handoff-message'),
            tooltip: 'Message',
            onPressed: onMessage,
            icon: const Icon(Icons.chat_outlined, size: 20),
          ),
        if (onEmail != null)
          IconButton(
            key: const Key('handoff-email'),
            tooltip: 'Email',
            onPressed: onEmail,
            icon: const Icon(Icons.mail_outline, size: 20),
          ),
      ],
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.primary,
    required this.secondary,
    this.trailing,
  });

  final IconData icon;
  final String primary;
  final String secondary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: const Color(0xFF9CA0A6)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  primary.isEmpty ? '—' : primary,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  secondary,
                  style: const TextStyle(
                    color: Color(0xFF9CA0A6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

final class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    required this.nextEventTitle,
    required this.nextEventSubtitle,
    required this.upcomingTasks,
    required this.onCreateFollowUp,
  });

  final String? nextEventTitle;
  final String? nextEventSubtitle;
  final List<PlannerTask> upcomingTasks;
  final VoidCallback onCreateFollowUp;

  @override
  Widget build(BuildContext context) {
    if (nextEventTitle == null && upcomingTasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Nothing scheduled yet.',
              style: TextStyle(color: Color(0xFF9CA0A6)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('create-follow-up-empty'),
              onPressed: onCreateFollowUp,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create follow-up'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (nextEventTitle != null)
          ListTile(
            key: const Key('profile-next-event'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.event, color: AppTheme.rose),
            title: Text(
              nextEventTitle!,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(nextEventSubtitle ?? ''),
          ),
        for (final task in upcomingTasks)
          ListTile(
            key: Key('profile-upcoming-task-${task.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.task_alt, color: Color(0xFFFFC857)),
            title: Text(
              task.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              task.dueDate == null
                  ? 'No due date'
                  : 'Due ${friendlyContactDate(task.dueDate!)}',
            ),
            onTap: () => context.push('${RoutePaths.tasks}/${task.id}'),
          ),
      ],
    );
  }
}

final class _AvailabilitySection extends StatelessWidget {
  const _AvailabilitySection({required this.windows, required this.patterns});

  final List<ContactAvailability> windows;
  final List<CommonEventPattern> patterns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final window in windows)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.schedule, size: 20),
            title: Text(
              '${_weekdayName(window.weekday)}  '
              '${_formatMinute(window.startMinute)} – ${_formatMinute(window.endMinute)}',
            ),
          ),
        if (windows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'No availability entered.',
              style: TextStyle(color: Color(0xFF9CA0A6)),
            ),
          ),
        if (patterns.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Common Event Times',
              style: TextStyle(color: Color(0xFF9CA0A6), fontSize: 13),
            ),
          ),
          for (final pattern in patterns)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      pattern.title,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${pattern.weekdayLabel} ${pattern.startMinuteLabel}',
                    style: const TextStyle(
                      color: Color(0xFF9CA0A6),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pattern.count}',
                    style: const TextStyle(
                      color: AppTheme.rose,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  static String _weekdayName(int weekday) {
    const names = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  static String _formatMinute(int minute) {
    final hour24 = minute ~/ 60;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minuteText = (minute % 60).toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '$hour12:$minuteText $period';
  }
}

final class _GroupsTagsSection extends StatelessWidget {
  const _GroupsTagsSection({
    required this.groups,
    required this.primaryGroupId,
    required this.tags,
  });

  final List<ContactGroup> groups;
  final String? primaryGroupId;
  final List<ContactTag> tags;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final group in groups)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1E21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Color(group.colorValue)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (group.id == primaryGroupId) ...<Widget>[
                    const Icon(Icons.star, size: 14, color: AppTheme.rose),
                    const SizedBox(width: 4),
                  ],
                  Text(group.name, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          for (final tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1E21),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A2D31)),
              ),
              child: Text(tag.name, style: const TextStyle(fontSize: 14)),
            ),
          if (groups.isEmpty && tags.isEmpty)
            const Text(
              'No groups or tags.',
              style: TextStyle(color: Color(0xFF9CA0A6)),
            ),
        ],
      ),
    );
  }
}

final class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});

  final List<ContactNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'No notes yet.',
          style: TextStyle(color: Color(0xFF9CA0A6)),
        ),
      );
    }
    return Column(
      children: <Widget>[
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF181A1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2D31)),
              ),
              child: Text(note.noteText, style: const TextStyle(fontSize: 14)),
            ),
          ),
      ],
    );
  }
}

final class _RecordDetails extends StatelessWidget {
  const _RecordDetails({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final created = contact.createdAtUtc.toLocal();
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final createdLabel =
        '${months[created.month - 1]} ${created.day}, ${created.year}';
    final origin = switch (contact.source) {
      ContactSource.manual => 'Manual',
      ContactSource.deviceImport => 'Device Import',
      ContactSource.betterCalendarImport => 'BetterCalendar Import',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _detailRow('Created', createdLabel),
          _detailRow('Origin', origin),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9CA0A6), fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline tab
// ---------------------------------------------------------------------------

final class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(contactTimelineProvider(contactId));
    final patterns =
        ref.watch(commonEventPatternsProvider(contactId)).value ??
        const <CommonEventPattern>[];
    return timelineAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          const Center(child: Text('Timeline could not be opened.')),
      data: (timeline) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CommonEventsPanel(patterns: patterns),
          Expanded(child: ContactTimelineView(timeline: timeline)),
        ],
      ),
    );
  }
}
