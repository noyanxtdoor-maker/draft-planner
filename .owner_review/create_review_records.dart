// Owner-review record tool (agent-owned, not part of the app).
// Creates/edits/deletes ONLY 'NT OWNER REVIEW' rows via an offline SQLite
// transaction on a pushed database file. The app process MUST be stopped
// while the database is replaced (force-stop before and after).
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
const dllDir = r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows';
const pkg = 'com.nexttransfer.rmplanner';
const device = 'adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp';
const deviceDb = 'app_flutter/next_transfer.sqlite';

const taskTitle = 'NT OWNER REVIEW TASK — DELETE ME';
const eventTitle = 'NT OWNER REVIEW EVENT — DELETE ME';
const taskNotes = 'Agent-created temporary record for owner physical review.';
const eventNotes = 'Agent-created temporary record for owner physical review.';

/// Deterministic agent-owned UUID (uuid v5, URL namespace) so re-runs are idempotent.
String stableId(String kind) {
  const uuid = Uuid();
  return uuid.v5(Uuid.NAMESPACE_URL, 'com.nexttransfer.rmplanner:owner-review:$kind:2026-09-07');
}

String lastLocalPath = '';

Future<Database> pullDb(Directory dir) async {
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  lastLocalPath = local;
  final p = await Process.run(adb, ['-s', device, 'shell', 'run-as $pkg base64 $deviceDb']);
  if (p.exitCode != 0) throw 'pull failed: ${p.stderr}';
  await File(local).writeAsBytes(base64Decode((p.stdout as String).replaceAll(RegExp(r'\s'), '')));
  return sqlite3.open(local);
}

Future<void> pushDb(Database db, String path) async {
  db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
  db.dispose();
  // base64 push: decode on-device into the app dir.
  final b64 = base64Encode(File(path).readAsBytesSync());
  const tmpName = 'nt_review_push.b64';
  final tmpLocal = File(Directory.systemTemp.path + Platform.pathSeparator + tmpName);
  await tmpLocal.writeAsString(b64);
  final push = await Process.run(adb, [
    '-s', device, 'push', tmpLocal.path, '/data/local/tmp/$tmpName',
  ]);
  if (push.exitCode != 0) throw 'push failed: ${push.stderr}';
  final sh = await Process.run(adb, [
    '-s', device, 'shell',
    'run-as $pkg sh -c "base64 -d /data/local/tmp/$tmpName > $deviceDb && rm /data/local/tmp/$tmpName"',
  ]);
  if (sh.exitCode != 0) throw 'install failed: ${sh.stderr}';
}

Future<void> main(List<String> args) async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) DynamicLibrary.open(dll.path);
  final nowUtcSeconds = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000);
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final db = await pullDb(dir);
  final profile = db.select("SELECT id FROM local_profiles WHERE slot='primary';");
  if (profile.rows.length != 1) throw 'expected exactly one primary profile';
  final profileId = profile.rows.first[0] as String;

  String plannerDateNow() {
    final manila = DateTime.now().toUtc().add(const Duration(hours: 8));
    return '${manila.year.toString().padLeft(4, '0')}-${manila.month.toString().padLeft(2, '0')}-${manila.day.toString().padLeft(2, '0')}';
  }

  final taskId = stableId('task');
  final eventId = stableId('event');

  db.execute('BEGIN;');
  try {
    // ---------- TASK (timed, future) ----------
    final existingTask = db.select("SELECT COUNT(*) FROM planner_tasks WHERE id=?", [taskId]).rows.first[0] as int;
    if (existingTask == 0) {
      db.execute(
        "INSERT INTO planner_tasks (id, profile_id, title, notes, due_date, status, requires_report, "
        "contribution_rule_key, created_at_utc, updated_at_utc, due_minute, recurrence_frequency, people_json, "
        "linked_activity_type_id, linked_activity_type_stable_key, linked_activity_type_label_snapshot, goal_id, is_backup) "
        "VALUES (?, ?, ?, ?, ?, 'incomplete', 0, NULL, ?, ?, 720, 'none', '[]', NULL, NULL, NULL, NULL, 0);",
        [taskId, profileId, taskTitle, taskNotes, plannerDateNow(), nowUtcSeconds, nowUtcSeconds],
      );
    }
    // ---------- EVENT (timed, future) ----------
    final existingEvent = db.select("SELECT COUNT(*) FROM calendar_events WHERE id=?", [eventId]).rows.first[0] as int;
    if (existingEvent == 0) {
      db.execute(
        "INSERT INTO calendar_events (id, profile_id, title, notes, timing, start_date, start_minute, end_minute, "
        "time_zone_id, location_text, requires_report, contribution_rule_key, recurrence_frequency, recurrence_end_mode, "
        "recurrence_end_date, recurrence_count, status, parent_event_id, replacement_event_id, created_at_utc, updated_at_utc, "
        "activity_type_id, activity_type_mapping_version, is_backup_appointment, backup_for_event_id, backup_relationship_provenance, "
        "activity_type_stable_key_snapshot, activity_type_label_snapshot, activity_type_color_value_snapshot, goal_id, "
        "recurrence_pattern_json, latitude, longitude, coordinate_source) "
        "VALUES (?, ?, ?, ?, 'timed', ?, 735, 780, 'Asia/Manila', NULL, 0, NULL, 'none', 'never', NULL, NULL, 'scheduled', "
        "NULL, NULL, ?, ?, NULL, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);",
        [eventId, profileId, eventTitle, eventNotes, plannerDateNow(), nowUtcSeconds, nowUtcSeconds],
      );
    }
    // ---------- DATE-ONLY TASK (no due_minute; must get NO timed reminder) ----------
    final dateOnlyId = stableId('task-date-only');
    final existingDateOnly = db.select("SELECT COUNT(*) FROM planner_tasks WHERE id=?", [dateOnlyId]).rows.first[0] as int;
    if (existingDateOnly == 0) {
      db.execute(
        "INSERT INTO planner_tasks (id, profile_id, title, notes, due_date, status, requires_report, "
        "contribution_rule_key, created_at_utc, updated_at_utc, due_minute, recurrence_frequency, people_json, "
        "linked_activity_type_id, linked_activity_type_stable_key, linked_activity_type_label_snapshot, goal_id, is_backup) "
        "VALUES (?, ?, ?, ?, ?, 'incomplete', 0, NULL, ?, ?, NULL, 'none', '[]', NULL, NULL, NULL, NULL, 0);",
        [dateOnlyId, profileId, 'NT OWNER REVIEW TASK DATE-ONLY — DELETE ME', taskNotes, plannerDateNow(), nowUtcSeconds, nowUtcSeconds],
      );
    }
    db.execute('COMMIT;');
    stdout.writeln('created-or-present: task=$taskId event=$eventId dateOnly=$dateOnlyId');
  } catch (e) {
    db.execute('ROLLBACK;');
    rethrow;
  }

  // quick verify read
  final t = db.select("SELECT id, title, due_date, due_minute, status FROM planner_tasks WHERE id=?", [taskId]);
  final e = db.select("SELECT id, title, timing, start_date, start_minute, end_minute, status FROM calendar_events WHERE id=?", [eventId]);
  stdout.writeln('task row: ${t.rows.first.join(' | ')}');
  stdout.writeln('event row: ${e.rows.first.join(' | ')}');
  await pushDb(db, lastLocalPath);
  stdout.writeln('pushed database back to device.');
}
