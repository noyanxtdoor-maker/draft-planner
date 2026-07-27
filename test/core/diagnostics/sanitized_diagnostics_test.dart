import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';

void main() {
  test('Q0: diagnostics keep allowlisted scalars and discard private data', () {
    final diagnostics = SanitizedDiagnostics();

    diagnostics.record(
      'startup_test',
      context: <String, Object?>{
        'attempt': 2,
        'database_state': 'ready',
        'profile_id': 'private-profile-id',
        'private_notes': 'private journal content',
        'token': 'secret-token',
        'route_kind': <String>['unsafe', 'collection'],
      },
    );

    expect(diagnostics.events, hasLength(1));
    expect(diagnostics.events.single.code, 'startup_test');
    expect(diagnostics.events.single.safeContext, <String, Object?>{
      'attempt': 2,
      'database_state': 'ready',
    });
    expect(
      diagnostics.events.single.safeContext.values,
      isNot(contains('secret-token')),
    );
  });

  test('AC-W-022: optional diagnostic details require preview selection', () {
    final diagnostics = SanitizedDiagnostics()
      ..record(
        'database_open_ready',
        context: const <String, Object?>{
          'database_state': 'ready',
          'token': 'never-export',
        },
      );

    final minimal = diagnostics.prepareExportPreview(
      includeOptionalContext: false,
    );
    final reviewed = diagnostics.prepareExportPreview(
      includeOptionalContext: true,
    );

    expect(minimal.events.single.safeContext, isEmpty);
    expect(reviewed.events.single.safeContext, <String, Object?>{
      'database_state': 'ready',
    });
    expect(
      reviewed.events.single.safeContext.values,
      isNot(contains('never-export')),
    );
  });

  test('AC-W-012: diagnostic event codes cannot carry private payloads', () {
    final diagnostics = SanitizedDiagnostics()..record('token=private-value');

    expect(diagnostics.events.single.code, 'invalid_diagnostic_code');
  });
}
