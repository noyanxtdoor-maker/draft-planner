// PRE-M5 timing sample setup (agent-owned, not part of the app).
// Creates ONLY 'NT PREM5 TIMING' rows: 2 Events + 1 Task, each with a series
// reminder_policies row in inherit mode, so known lead minutes apply.
// The app process MUST be stopped while the database is replaced.
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

String stableId(String kind) {
  const uuid = Uuid();
  return uuid.v5(Uuid.NAMESPACE_URL, 'com.nexttransfer.rmplanner:prem5-timing:$kind');
}

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
  final nowUtcSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final db = await pullDb(dir);
  final profile = db.select("SELECT id FROM local_profiles WHERE slot='primary';");
  if (profile.rows.length != 1) throw 'expected exactly one primary profile';
  final profileId = profile.rows.first[0] as String;

  final manila = DateTime.now().toUtc().add(const Duration(hours: 8));
  final today = '${manila.year.toString().padLeft(4, '0')}-${manila.month.toString().padLeft(2, '0')}-${manila.day.toString().padLeft(2, '0')}';
  final tomorrow = DateTime.utc(manila.year, manila.month, manila.day + 1);
  final tomorrowStr = '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';

  final eventA = stableId('event-a'); // today, +40 min, lead 5  -> target +35
  final eventB = stableId('event-b'); // tomorrow 09:00, lead 15 -> target 08:45
  final taskT = stableId('task-t');   // today, +40 min, lead 10 -> target +30

  db.execute('BEGIN;');
  try {
    db.execute(
      "INSERT OR IGNORE INTO calendar_events (id, profile_id, title, notes, timing, start_date, start_minute, end_minute, "
      "time_zone_id, location_text, requires_report, contribution_rule_key, recurrence_frequency, recurrence_end_mode, "
      "recurrence_end_date, recurrence_count, status, parent_event_id, replacement_event_id, created_at_utc, updated_at_utc, "
      "activity_type_id, activity_type_mapping_version, is_backup_appointment, backup_for_event_id, backup_relationship_provenance, "
      "activity_type_stable_key_snapshot, activity_type_label_snapshot, activity_type_color_value_snapshot, goal_id, "
      "recurrence_pattern_json, latitude, longitude, coordinate_source) "
      "VALUES (?, ?, ?, ?, 'timed', ?, ?, ?, 'Asia/Manila', NULL, 0, NULL, 'none', 'never', NULL, NULL, 'scheduled', "
      "NULL, NULL, ?, ?, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);",
      [eventA, profileId, 'NT PREM5 TIMING EVENT A — DELETE ME',
       'Agent-created temporary timing sample A.', today, manila.hour * 60 + manila.minute + 40, manila.hour * 60 + manila.minute + 80, nowUtcSeconds, nowUtcSeconds],
    );
    db.execute(
      "INSERT OR IGNORE INTO calendar_events (id, profile_id, title, notes, timing, start_date, start_minute, end_minute, "
      "time_zone_id, location_text, requires_report, contribution_rule_key, recurrence_frequency, recurrence_end_mode, "
      "recurrence_end_date, recurrence_count, status, parent_event_id, replacement_event_id, created_at_utc, updated_at_utc, "
      "activity_type_id, activity_type_mapping_version, is_backup_appointment, backup_for_event_id, backup_relationship_provenance, "
      "activity_type_stable_key_snapshot, activity_type_label_snapshot, activity_type_color_value_snapshot, goal_id, "
      "recurrence_pattern_json, latitude, longitude, coordinate_source) "
      "VALUES (?, ?, ?, ?, 'timed', ?, 540, 600, 'Asia/Manila', NULL, 0, NULL, 'none', 'never', NULL, NULL, 'scheduled', "
      "NULL, NULL, ?, ?, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);",
      [eventB, profileId, 'NT PREM5 TIMING EVENT B — DELETE ME',
       'Agent-created temporary timing sample B.', tomorrowStr, nowUtcSeconds, nowUtcSeconds],
    );
    db.execute(
      "INSERT OR IGNORE INTO planner_tasks (id, profile_id, title, notes, due_date, status, requires_report, "
      "contribution_rule_key, created_at_utc, updated_at_utc, due_minute, recurrence_frequency, people_json, "
      "linked_activity_type_id, linked_activity_type_stable_key, linked_activity_type_label_snapshot, goal_id, is_backup) "
      "VALUES (?, ?, ?, ?, ?, 'incomplete', 0, NULL, ?, ?, ?, 'none', '[]', NULL, NULL, NULL, NULL, 0);",
      [taskT, profileId, 'NT PREM5 TIMING TASK T — DELETE ME',
       'Agent-created temporary timing sample T.', today, nowUtcSeconds, nowUtcSeconds, manila.hour * 60 + manila.minute + 40],
    );
    int policy(String id, String kind, String src, int lead) {
      final rows = db.select('SELECT COUNT(*) FROM reminder_policies WHERE id=?;', [id]).rows.first[0] as int;
      if (rows > 0) return 0;
      db.execute(
        "INSERT INTO reminder_policies (id, profile_id, source_kind, source_id, occurrence_id, purpose, contact_id, mode, offset_minutes, created_at_utc, updated_at_utc) "
        "VALUES (?, ?, ?, ?, 'series', 'standard', NULL, 'inherit', ?, ?, ?);",
        [id, profileId, kind, src, lead, nowUtcSeconds, nowUtcSeconds],
      );
      return 1;
    }
    final p1 = policy(stableId('policy-event-a'), 'calendarEvent', eventA, 5);
    final p2 = policy(stableId('policy-event-b'), 'calendarEvent', eventB, 15);
    final p3 = policy(stableId('policy-task-t'), 'task', taskT, 10);
    db.execute('COMMIT;');
    stdout.writeln('created-or-present: A=$eventA B=$eventB T=$taskT policies=$p1/$p2/$p3');
  } catch (e) {
    db.execute('ROLLBACK;');
    rethrow;
  } finally {
    await pushDb(db, '${dir.path}${Platform.pathSeparator}next_transfer.sqlite');
    dir.deleteSync(recursive: true);
  }
}
