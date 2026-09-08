// Owner-review evidence tool (agent-owned, not part of the app).
// Read-only inspection: pulls app_flutter/next_transfer.sqlite via adb run-as,
// opens it with the project's sqlite3 package + the app's bundled sqlite3.dll.
// NEVER writes to the device. Operates only on the pulled local copy.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
const dllDir = r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows';
const pkg = 'com.nexttransfer.rmplanner';
const device = 'adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp';
const deviceDb = 'app_flutter/next_transfer.sqlite';

Future<void> main(List<String> args) async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) {
    // ignore: unnecessary_statement
    DynamicLibrary.open(dll.path);
  }
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  final b64 = await Process.run(adb, [
    '-s', device, 'shell', 'run-as $pkg base64 $deviceDb',
  ]);
  if (b64.exitCode != 0) {
    stderr.writeln('DB pull failed: ${b64.stderr}');
    exit(1);
  }
  final clean = (b64.stdout as String).replaceAll(RegExp(r'\s'), '');
  final bytes = base64Decode(clean);
  await File(local).writeAsBytes(bytes);
  stdout.writeln('DB bytes pulled: ${bytes.length}');
  final db = sqlite3.open(local, mode: OpenMode.readOnly);
  if (args.contains('--schema')) {
    for (final t in const [
      'notification_preferences', 'reminder_policies',
      'background_work_requests', 'planner_tasks', 'calendar_events',
      'privacy_preferences', 'local_profiles',
    ]) {
      stdout.writeln('== $t ==');
      try {
        final cols = db.select('PRAGMA table_info($t)');
        for (final row in cols.rows) {
          stdout.writeln('${row[1]} : ${row[2]}');
        }
      } catch (err) {
        stdout.writeln('pragma error: $err');
      }
    }
    db.dispose();
    await dir.delete(recursive: true);
    return;
  }
  final queries = <String, String>{
    'privacy_preferences':
        "SELECT key, lock_enabled, notification_preview_mode, updated_at_utc FROM privacy_preferences;",
    'notification_preferences':
        "SELECT * FROM notification_preferences;",
    'owner_review_tasks':
        "SELECT id, title, due_date, due_minute, status, updated_at_utc FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%' ORDER BY updated_at_utc DESC LIMIT 10;",
    'owner_review_events':
        "SELECT id, title, status, updated_at_utc FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%' ORDER BY updated_at_utc DESC LIMIT 10;",
    'owner_review_policies':
        "SELECT source_kind, source_id, occurrence_id, mode, offset_minutes, updated_at_utc FROM reminder_policies WHERE source_id IN (SELECT id FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%') OR source_id IN (SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%') ORDER BY updated_at_utc DESC LIMIT 20;",
    'owner_review_work':
        "SELECT stable_key, owner_id, occurrence_id, state, scheduled_for_utc, next_eligible_at_utc, snooze_count, platform_notification_id, attempt_count, source_revision, updated_at_utc FROM background_work_requests WHERE owner_id IN (SELECT id FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%') OR owner_id IN (SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%') ORDER BY updated_at_utc DESC LIMIT 30;",
    'work_state_counts':
        "SELECT state, COUNT(*) AS n FROM background_work_requests GROUP BY state;",
    'recent_work':
        "SELECT stable_key, state, scheduled_for_utc, next_eligible_at_utc, snooze_count, updated_at_utc FROM background_work_requests ORDER BY updated_at_utc DESC LIMIT 12;",
    'profiles':
        "SELECT id, slot FROM local_profiles;",
  };
  for (final e in queries.entries) {
    stdout.writeln('=== ${e.key} ===');
    try {
      final rows = db.select(e.value);
      for (final row in rows.rows) {
        stdout.writeln(row.map((c) => '$c').join(' | '));
      }
      if (rows.isEmpty) stdout.writeln('(no rows)');
    } catch (err) {
      stdout.writeln('query error: $err');
    }
  }
  db.dispose();
  await dir.delete(recursive: true);
}
