// Owner-review Action helper (agent-owned, not part of the app).
// Broadcasts the app's own ActionBroadcastReceiver intent for an existing
// scheduled owner-review reminder, exercising the production action path.
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
  if (dll.existsSync()) DynamicLibrary.open(dll.path);
  // 1) pull db and find the owner-review work rows
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  final p = await Process.run(adb, [
    '-s', device, 'shell', 'run-as $pkg base64 $deviceDb',
  ]);
  final bytes = base64Decode((p.stdout as String).replaceAll(RegExp(r'\s'), ''));
  await File(local).writeAsBytes(bytes);
  final db = sqlite3.open(local, mode: OpenMode.readOnly);
  final rows = db.select(
    "SELECT stable_key, owner_id, occurrence_id, state, snooze_count, platform_notification_id "
    "FROM background_work_requests "
    "WHERE owner_id IN (SELECT id FROM planner_tasks WHERE title LIKE '%NT OWNER REVIEW%') "
    "OR owner_id IN (SELECT id FROM calendar_events WHERE title LIKE '%NT OWNER REVIEW%') "
    "ORDER BY updated_at_utc DESC LIMIT 5;",
  );
  stdout.writeln('=== owner-review durable rows before ===');
  for (final r in rows.rows) {
    stdout.writeln(r.join(' | '));
  }
  db.dispose();
  await dir.delete(recursive: true);
  if (rows.rows.isEmpty) {
    stderr.writeln('No owner-review work rows found.');
    exit(1);
  }
  final key = rows.rows.first[0] as String;
  final ownerId = rows.rows.first[1] as String;
  final occurrence = rows.rows.first[2] as String;
  final kind = key.contains('calendarEvent') ? 'calendarEvent' : 'task';
  final snooze = args.contains('--snooze');
  final action = snooze ? 'snooze' : 'open';
  // 2) broadcast the Action intent
  final idms = DateTime.now().toUtc().millisecondsSinceEpoch;
  final b = await Process.run(adb, [
    '-s', device, 'shell',
    'am broadcast -a com.nexttransfer.rmplanner.ACTION_REMINDER '
    "-n $pkg/.ActionBroadcastReceiver "
    '--es stable_key "$key" '
    '--es source_id "$ownerId" '
    '--es occurrence_id "$occurrence" '
    '--es source_kind "$kind" '
    '--es action "$action" '
    '--es generation "0" '
    '--el action_utc_ms "$idms"',
  ]);
  stdout.write(b.stdout);
  stdout.write(b.stderr);
  await Future<void>.delayed(const Duration(seconds: 2));
  // 3) print resulting state
  final dir2 = await Directory.systemTemp.createTemp('nt_review_db');
  final local2 = '${dir2.path}${Platform.pathSeparator}next_transfer.sqlite';
  final p2 = await Process.run(adb, [
    '-s', device, 'shell', 'run-as $pkg base64 $deviceDb',
  ]);
  final bytes2 = base64Decode((p2.stdout as String).replaceAll(RegExp(r'\s'), ''));
  await File(local2).writeAsBytes(bytes2);
  final db2 = sqlite3.open(local2, mode: OpenMode.readOnly);
  final after = db2.select(
    "SELECT stable_key, state, scheduled_for_utc, next_eligible_at_utc, snooze_count "
    "FROM background_work_requests WHERE stable_key = '$key';",
  );
  stdout.writeln('=== row after $action ===');
  for (final r in after.rows) {
    stdout.writeln(r.join(' | '));
  }
  db2.dispose();
  await dir2.delete(recursive: true);
}
