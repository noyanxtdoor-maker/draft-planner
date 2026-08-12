import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';
import 'package:rmplanner/features/startup/application/startup_providers.dart';

final class DiagnosticPreviewScreen extends ConsumerStatefulWidget {
  const DiagnosticPreviewScreen({super.key});

  @override
  ConsumerState<DiagnosticPreviewScreen> createState() =>
      _DiagnosticPreviewScreenState();
}

final class _DiagnosticPreviewScreenState
    extends ConsumerState<DiagnosticPreviewScreen> {
  bool _includeOptionalContext = false;
  DiagnosticExportPreview? _preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Diagnostic export preview')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            const Text(
              'Nothing is exported automatically. Raw calendar imports, '
              'private text, precise locations, document references, and '
              'authentication secrets are never included.',
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('diagnostic-context-checkbox'),
              value: _includeOptionalContext,
              onChanged: (value) {
                setState(() {
                  _includeOptionalContext = value ?? false;
                  _preview = null;
                });
              },
              title: const Text('Include approved operational details'),
              subtitle: const Text(
                'Limited to allow-listed scalar fields such as database state '
                'and schema version. Review the preview below.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('prepare-diagnostic-preview-button'),
              onPressed: () {
                setState(() {
                  _preview = ref
                      .read(diagnosticsProvider)
                      .prepareExportPreview(
                        includeOptionalContext: _includeOptionalContext,
                      );
                });
              },
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Prepare review preview'),
            ),
            const SizedBox(height: 20),
            if (_preview == null)
              const Text('Prepare a preview to review sanitized event codes.')
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  '${_preview!.events.length} sanitized events ready for review',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_preview!.events.isEmpty)
                const Text('No diagnostic events are currently recorded.')
              else
                for (final event in _preview!.events)
                  Card(
                    child: ListTile(
                      title: Text(event.code),
                      subtitle: event.safeContext.isEmpty
                          ? const Text('No optional details included')
                          : Text(event.safeContext.toString()),
                    ),
                  ),
              const SizedBox(height: 12),
              const Text(
                'Preview only — no file or message has been created or shared.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
