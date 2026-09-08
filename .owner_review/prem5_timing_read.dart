// PRE-M5 timing evidence reader (agent-owned, read-only).
// Pull: device clock, durable background_work_requests for the agent rows,
// pending plugin notifications, and NotificationManager post evidence.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
const dllDir = r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows';
const pkg = 'com.nexttransfer.rmplanner';
const device = 'adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp';
const deviceDb = 'app_flutter/next_transfer.sqlite';

Future<Database> pullDb(Directory dir) async {
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  final p = await Process.run(adb, ['-s', device, 'shell', 'run-as $pkg base64 $deviceDb']);
  if (p.exitCode != 0) throw 'pull failed: ${p.stderr}';
  await File(local).writeAsBytes(base64Decode((p.stdout as String).replaceAll(RegExp(r'\s'), '')));
  return sqlite3.open(local);
}

Future<void> main(List<String> args) async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) DynamicLibrary.open(dll.path);

  // 1) device clock
  final clock = await Process.run(adb, ['-s', device, 'shell', 'date +"%Y-%m-%d %H:%M:%S %z"']);
  stdout.writeln('DEVICE CLOCK: ${clock.stdout.toString().trim()}');

  // 2) durable work rows for agent records
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final db = await pullDb(dir);
  final rows = db.select(
    "SELECT stable_key, owner_kind, owner_id, occurrence_id, source_revision, scheduled_for_utc, state, "
    "platform_notification_id, snooze_count, next_eligible_at_utc, attempt_count, created_at_utc, updated_at_utc "
    "FROM background_work_requests WHERE owner_id IN "
    "(SELECT id FROM calendar_events WHERE title LIKE '%NT PREM5 TIMING%') "
    "OR owner_id IN (SELECT id FROM planner_tasks WHERE title LIKE '%NT PREM5 TIMING%') "
    "ORDER BY updated_at_utc DESC;");
  stdout.writeln('DURABLE WORK ROWS: ${rows.rows.length}');
  for (final r in rows.rows) {
    final sched = r[5] is int ? DateTime.fromMillisecondsSinceEpoch((r[5] as int) * 1000, isUtc: true) : r[5];
    stdout.writeln('  key=${r[0]} kind=${r[1]} state=${r[6]} schedUtc=$sched platformId=${r[7]} snooze=${r[8]} nextElig=${r[9]} rev=${r[4]}');
  }
  // 3) source rows for context
  final srcs = db.select(
    "SELECT id, 'event' AS kind, title, start_date, start_minute FROM calendar_events WHERE title LIKE '%NT PREM5 TIMING%' "
    "UNION ALL SELECT id, 'task', title, due_date, due_minute FROM planner_tasks WHERE title LIKE '%NT PREM5 TIMING%';");
  for (final r in srcs.rows) {
    stdout.writeln('SOURCE ${r[1]}: id=${r[0]} date=${r[3]} minute=${r[4]} title=${r[2]}');
  }
  // 4) preferences
  final prefs = db.select("SELECT system_notifications_enabled, event_reminders_enabled, task_reminders_enabled, "
      "default_task_reminder_minutes, quiet_hours_enabled FROM notification_preferences LIMIT 1;");
  for (final r in prefs.rows) stdout.writeln('NOTIF PREFS: master=${r[0]} event=${r[1]} task=${r[2]} defaultTaskMin=${r[3]} quiet=${r[4]}');
  final pp = db.select("SELECT default_reminder_minutes FROM planner_preferences LIMIT 1;");
  for (final r in pp.rows) stdout.writeln('PLANNER PREFS: defaultEventMin=${r[0]}');
  db.dispose();
  dir.deleteSync(recursive: true);

  // 5) pending plugin notifications (flutter_local_notifications store)
  final pending = await Process.run(adb, [
    '-s', device, 'shell',
    'run-as $pkg sh -c "ls files/ 2>/dev/null; ls app_flutter/ 2>/dev/null"',
  ]);
  stdout.writeln('APP FILES: ${pending.stdout.toString().trim().replaceAll('\n', ' | ')}');
}
