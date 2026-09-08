import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/contacts/application/contact_providers.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';
import 'package:rmplanner/features/contacts/presentation/widgets/contact_widgets.dart';
import 'package:rmplanner/features/planner/application/planner_providers.dart';

/// Dedicated search route: 56 dp rounded field, results over name, phone,
/// email, social, group, and address text.  No FTS on Notes.
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
                  fillColor: AppTheme.surfaceVariantOf(
                    context,
                  ).withValues(alpha: .45),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            if (_controller.text.trim().isNotEmpty) ...<Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Matches', style: InternalScreen.sectionHeading),
              ),
              const Divider(height: 1, thickness: 1),
            ],
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.manage_search,
                size: 52,
                color: AppTheme.outlineOf(context),
              ),
              const SizedBox(height: 14),
              const Text(
                'Find the people you’re looking for',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Search by name, phone, email, groups, or address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondaryTextOf(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty && _searched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off,
                size: 48,
                color: AppTheme.outlineOf(context),
              ),
              const SizedBox(height: 12),
              const Text(
                'No matches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Try another name, phone, email, group, or address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondaryTextOf(context),
                  fontSize: 14,
                ),
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

/// Reusable picker variant of the accepted Contacts Search presentation.
/// The caller supplies canonical search semantics and owns what selection
/// means; typing and result state remain route-local and 250ms debounced.
final class ContactSearchPickerScreen<T> extends StatefulWidget {
  const ContactSearchPickerScreen({
    required this.search,
    required this.onSelected,
    required this.resultBuilder,
    this.hintText = 'Search contacts',
    this.emptyTitle = 'Find the people you’re looking for',
    this.emptyMessage = 'Search by name, phone, email, groups, or address.',
    super.key,
  });

  final Future<List<T>> Function(String query) search;
  final FutureOr<void> Function(T result) onSelected;
  final Widget Function(BuildContext context, T result, VoidCallback onTap)
  resultBuilder;
  final String hintText;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<ContactSearchPickerScreen<T>> createState() =>
      _ContactSearchPickerScreenState<T>();
}

final class _ContactSearchPickerScreenState<T>
    extends State<ContactSearchPickerScreen<T>> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<T> _results = <T>[];
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
        _results = <T>[];
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
    if (query.trim().isEmpty) return;
    try {
      final results = await widget.search(query);
      if (!mounted || query != _controller.text) return;
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    } on Object {
      if (mounted && query == _controller.text) {
        setState(() {
          _results = <T>[];
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
          key: const Key('map-search-back'),
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
                key: const Key('map-search-field'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onQueryChanged,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search, size: 24),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('map-search-clear'),
                          icon: const Icon(Icons.close, size: 24),
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: AppTheme.surfaceVariantOf(
                    context,
                  ).withValues(alpha: .45),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            if (_controller.text.trim().isNotEmpty) ...<Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Matches', style: InternalScreen.sectionHeading),
              ),
              const Divider(height: 1, thickness: 1),
            ],
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.manage_search,
                size: 52,
                color: AppTheme.outlineOf(context),
              ),
              const SizedBox(height: 14),
              Text(
                widget.emptyTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondaryTextOf(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty && _searched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.search_off,
                size: 48,
                color: AppTheme.outlineOf(context),
              ),
              const SizedBox(height: 12),
              const Text(
                'No matches',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Try another name, phone, email, group, or address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.secondaryTextOf(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      key: const Key('map-search-results'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return widget.resultBuilder(
          context,
          result,
          () => unawaited(Future<void>.sync(() => widget.onSelected(result))),
        );
      },
    );
  }
}
