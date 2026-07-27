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
}
