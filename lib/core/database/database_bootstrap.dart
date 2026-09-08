import 'package:rmplanner/core/database/app_database.dart';
import 'package:rmplanner/core/diagnostics/sanitized_diagnostics.dart';

final class DatabaseBootstrap {
  const DatabaseBootstrap({required this.database, required this.diagnostics});

  final AppDatabase database;
  final SanitizedDiagnostics diagnostics;

  Future<void> verifyOpen() async {
    diagnostics.record(
      'database_open_started',
      context: const <String, Object?>{'database_state': 'opening'},
    );
    final result = await database
        .customSelect('PRAGMA quick_check')
        .getSingle();
    if (result.data.values.single != 'ok') {
      throw StateError('Database integrity check did not return ok');
    }
    diagnostics.record(
      'database_open_ready',
      context: const <String, Object?>{'database_state': 'ready'},
    );
  }
}
