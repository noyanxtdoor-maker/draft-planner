// Owner-review policy timing helper (agent-owned). Sets ONLY the agent
// 'NT OWNER REVIEW' reminder_policies rows' offsets. App must be stopped.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
const dllDir = r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows';
const pkg = 'com.nexttransfer.rmplanner';
const device = 'adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp';
const deviceDb = 'app_flutter/next_transfer.sqlite';
const tmpPush = 'nt_review_push.b64';

Future<Database> pullDb(Directory dir) async {
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  final p = await Process.run(adb, ['-s', device, 'shell', 'run-as $pkg base64 $deviceDb']);
  if (p.exitCode != 0) throw 'pull failed: ${p.stderr}';
  await File(local).writeAsBytes(base64Decode((p.stdout as String).replaceAll(RegExp(r'\s'), '')));
  return sqlite3.open(local);
}

Future<void> pushDb(Database db, String path) async {
  db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
  db.dispose();
  final b64 = base64Encode(File(path).readAsBytesSync());
  final tmpLocal = File(Directory.systemTemp.path + Platform.pathSeparator + tmpPush);
  await tmpLocal.writeAsString(b64);
  final push = await Process.run(adb, ['-s', device, 'push', tmpLocal.path, '/data/local/tmp/$tmpPush']);
  if (push.exitCode != 0) throw 'push failed: ${push.stderr}';
  final sh = await Process.run(adb, [
    '-s', device, 'shell',
    'run-as $pkg sh -c "base64 -d /data/local/tmp/$tmpPush > $deviceDb"',
  ]);
  if (sh.exitCode != 0) throw 'install failed: ${sh.stderr}';
}

Future<void> main(List<String> args) async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) DynamicLibrary.open(dll.path);
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  final db = await pullDb(dir);
  final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  // args: --event-offset <min>  and/or --task-offset <min>  and/or --clear-event-policy
  final eo = args.indexOf('--event-offset');
  final to = args.indexOf('--task-offset');
  final clearE = args.contains('--clear-event-policy');
  if (clearE) {
    db.execute("DELETE FROM reminder_policies WHERE source_id IN (SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%');");
    stdout.writeln('event policy cleared');
  }
  if (eo >= 0) {
    final eventId = db.select("SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%' LIMIT 1;").rows.first[0] as String;
    final occ = db.select("SELECT occurrence_id FROM background_work_requests WHERE owner_id=? AND occurrence_id IS NOT NULL ORDER BY updated_at_utc DESC LIMIT 1;", [eventId]);
    if (occ.rows.isEmpty) throw 'no scheduled occurrence row for event';
    final occId = occ.rows.first[0] as String;
    final existing = db.select("SELECT id FROM reminder_policies WHERE source_id=? AND occurrence_id=?;", [eventId, occId]);
    if (existing.rows.isEmpty) {
      final pid = const Uuid().v5(Uuid.NAMESPACE_URL, 'com.nexttransfer.rmplanner:owner-review:event-policy:2026-09-07');
      final profileId = db.select("SELECT id FROM local_profiles WHERE slot='primary';").rows.first[0] as String;
      db.execute(
        "INSERT INTO reminder_policies (id, profile_id, source_kind, source_id, occurrence_id, purpose, contact_id, mode, offset_minutes, created_at_utc, updated_at_utc) "
        "VALUES (?, ?, 'calendarEvent', ?, ?, 'standard', NULL, 'offset', ?, ?, ?);",
        [pid, profileId, eventId, occId, int.parse(args[eo + 1]), now, now],
      );
    } else {
      db.execute("UPDATE reminder_policies SET offset_minutes=?, updated_at_utc=? WHERE source_id=? AND occurrence_id=?;", [
        int.parse(args[eo + 1]), now, eventId, occId,
      ]);
    }
    stdout.writeln('event policy offset -> ${args[eo + 1]} min (occurrence $occId)');
  }
  if (to >= 0) {
    final taskId = db.select("SELECT id FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW TASK — DELETE ME%' LIMIT 1;").rows.first[0] as String;
    db.execute("UPDATE reminder_policies SET offset_minutes=?, updated_at_utc=? WHERE source_id=?;", [int.parse(args[to + 1]), now, taskId]);
    stdout.writeln('task policy offset -> ${args[to + 1]} min');
  }
  final pol = db.select("SELECT source_kind, occurrence_id, mode, offset_minutes FROM reminder_policies WHERE source_id IN (SELECT id FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%') OR source_id IN (SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%');");
  for (final r in pol.rows) {
    stdout.writeln('policy: ${r.join(' | ')}');
  }
  await pushDb(db, local);
  stdout.writeln('pushed.');
  db.dispose();
  await dir.delete(recursive: true);
}
