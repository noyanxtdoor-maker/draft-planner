// Owner-review cleanup (agent-owned). Deletes ONLY the three agent-created
// 'NT OWNER REVIEW' source records and their reminder_policies rows; sets the
// matching background_work_requests rows to the app's terminal state
// 'cancelledObsolete' (the same state the app's reconciler writes when a
// source disappears). No owner-created rows are touched. App must be stopped.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
const dllDir = r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows';
const pkg = 'com.nexttransfer.rmplanner';
const device = 'adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp';
const deviceDb = 'app_flutter/next_transfer.sqlite';
const tmpPush = 'nt_review_push.b64';

String idList(List<String> ids) => ids.map((e) => "'$e'").join(',');

Future<void> main() async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) DynamicLibrary.open(dll.path);
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final local = dir.path + Platform.pathSeparator + 'next_transfer.sqlite';
  final p = await Process.run(adb, ['-s', device, 'shell', 'run-as $pkg base64 $deviceDb']);
  if (p.exitCode != 0) throw 'pull failed: ${p.stderr}';
  final raw = (p.stdout as String).replaceAll(RegExp(r'\s'), '');
  await File(local).writeAsBytes(base64Decode(raw));
  final db = sqlite3.open(local);
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

  final taskIds = <String>[
    for (final r in db.select("SELECT id FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%';").rows) r[0] as String,
  ];
  final eventIds = <String>[
    for (final r in db.select("SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%';").rows) r[0] as String,
  ];
  final allIds = <String>[...taskIds, ...eventIds];
  stdout.writeln('agent records found: tasks=$taskIds events=$eventIds');

  final totalsBefore = <String, int>{
    'calendar_events': db.select('SELECT COUNT(*) FROM calendar_events;').rows.first[0] as int,
    'planner_tasks': db.select('SELECT COUNT(*) FROM planner_tasks;').rows.first[0] as int,
  };

  db.execute('BEGIN;');
  for (final id in allIds) {
    db.execute("UPDATE background_work_requests SET state='cancelledObsolete', updated_at_utc=? WHERE owner_id=?;", [now, id]);
    db.execute('DELETE FROM reminder_policies WHERE source_id=?;', [id]);
  }
  for (final id in taskIds) {
    db.execute('DELETE FROM planner_tasks WHERE id=?;', [id]);
  }
  for (final id in eventIds) {
    db.execute('DELETE FROM calendar_events WHERE id=?;', [id]);
  }
  db.execute('COMMIT;');

  final leftT = db.select("SELECT COUNT(*) FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%';").rows.first[0] as int;
  final leftE = db.select("SELECT COUNT(*) FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%';").rows.first[0] as int;
  final leftP = allIds.isEmpty
      ? 0
      : db.select('SELECT COUNT(*) FROM reminder_policies WHERE source_id IN (' + idList(allIds) + ');').rows.first[0] as int;
  final workLeft = allIds.isEmpty
      ? <List<Object?>>[]
      : db.select('SELECT state, COUNT(*) FROM background_work_requests WHERE owner_id IN (' + idList(allIds) + ') GROUP BY state;').rows;
  final totalsAfter = <String, int>{
    'calendar_events': db.select('SELECT COUNT(*) FROM calendar_events;').rows.first[0] as int,
    'planner_tasks': db.select('SELECT COUNT(*) FROM planner_tasks;').rows.first[0] as int,
  };
  final privacy = db.select("SELECT lock_enabled, notification_preview_mode FROM privacy_preferences WHERE key='primary';").rows.first;
  final prefs = db.select('SELECT event_reminders_enabled, task_reminders_enabled, default_task_reminder_minutes, quiet_hours_enabled, quiet_start_minute, quiet_end_minute FROM notification_preferences;').rows.first;

  stdout.writeln('agent rows remaining after cleanup: tasks=$leftT events=$leftE policies=$leftP');
  for (final r in workLeft) {
    stdout.writeln('agent work rows now: ' + r.join(' | '));
  }
  stdout.writeln('calendar_events before=${totalsBefore['calendar_events']} after=${totalsAfter['calendar_events']} (deleted=${eventIds.length})');
  stdout.writeln('planner_tasks before=${totalsBefore['planner_tasks']} after=${totalsAfter['planner_tasks']} (deleted=${taskIds.length})');
  stdout.writeln('privacy prefs now: ' + privacy.join(' | '));
  stdout.writeln('notification prefs now: ' + prefs.join(' | '));

  db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
  db.dispose();
  final b64 = base64Encode(File(local).readAsBytesSync());
  final tmpLocal = File(Directory.systemTemp.path + Platform.pathSeparator + tmpPush);
  await tmpLocal.writeAsString(b64);
  final push = await Process.run(adb, ['-s', device, 'push', tmpLocal.path, '/data/local/tmp/$tmpPush']);
  if (push.exitCode != 0) throw 'push failed: ${push.stderr}';
  final sh = await Process.run(adb, ['-s', device, 'shell', 'run-as $pkg sh -c "base64 -d /data/local/tmp/$tmpPush > $deviceDb"']);
  if (sh.exitCode != 0) throw 'install failed: ${sh.stderr}';
  await Process.run(adb, ['-s', device, 'shell', 'rm -f /data/local/tmp/$tmpPush']);
  stdout.writeln('cleaned database installed to device; temp file removed.');
  await dir.delete(recursive: true);
}
