import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';

/// Dedicated search route: 56 dp rounded field, results over name, phone,
/// email, social, group, tag, and address text.  No FTS on Notes.
final class ContactSearchScreen extends ConsumerStatefulWidget {
  const ContactSearchScreen({super.key});

  @override
  ConsumerState<ContactSearchScreen> createState() =>
      _ContactSearchScreenState();
}

final class _ContactSearchScreenState
    extends ConsumerState<ContactSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<ContactSummary> _results = const <ContactSummary>[];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const <ContactSummary>[];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _controller.text;
    if (query.trim().isEmpty) {
      return;
    }
    final profileId = ref.read(contactProfileIdProvider);
    final today = ref.read(plannerDateSourceProvider).today();
    try {
      final results = await ref
          .read(contactRepositoryProvider)
          .searchContacts(profileId: profileId, query: query, today: today);
      if (!mounted || query != _controller.text) {
        return;
      }
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    } on Object {
      if (mounted && query == _controller.text) {
        setState(() {
          _results = const <ContactSummary>[];
          _searching = false;
          _searched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InternalAppBar(
        title: const Text('Search'),
        leading: BackButton(
          key: const Key('contact-search-back'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const Key('contact-search-field'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: const Icon(Icons.search, size: 24),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('contact-search-clear'),
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: const Color(0xFF181A1E),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFF2A2D31)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFF2A2D31)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: Color(0xFF9CA0A6)),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Matches', style: InternalScreen.sectionHeading),
            ),
            const Divider(height: 1, thickness: 1),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_results.isEmpty && _searched) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.search_off, size: 48, color: Color(0xFF454850)),
              SizedBox(height: 12),
              Text(
                'No matches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Try another name, phone, email, group, or tag.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9CA0A6), fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('contact-search-results'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final summary = _results[index];
        return ContactListRow(
          summary: summary,
          onTap: () =>
              context.push(RoutePaths.contactDetail(summary.contact.id)),
        );
      },
    );
  }
}
