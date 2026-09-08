// Owner-review preference helper (agent-owned). Writes ONLY while the app
// process is stopped. Always run with --show <mode> or --lock <0|1> or
// --quiet <start> <end> or --restore <backupfile>.
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
  if (args.contains('--backup')) {
    final privacy = db.select("SELECT lock_enabled, notification_preview_mode FROM privacy_preferences WHERE key='primary';");
    final prefs = db.select("SELECT event_reminders_enabled, task_reminders_enabled, default_task_reminder_minutes, quiet_hours_enabled, quiet_start_minute, quiet_end_minute FROM notification_preferences;");
    final backup = {
      'lock_enabled': privacy.rows.first[0],
      'notification_preview_mode': privacy.rows.first[1],
      'event_reminders_enabled': prefs.rows.first[0],
      'task_reminders_enabled': prefs.rows.first[1],
      'default_task_reminder_minutes': prefs.rows.first[2],
      'quiet_hours_enabled': prefs.rows.first[3],
      'quiet_start_minute': prefs.rows.first[4],
      'quiet_end_minute': prefs.rows.first[5],
    };
    await File(args[args.indexOf('--backup') + 1]).writeAsString(jsonEncode(backup));
    stdout.writeln('backup written: $backup');
  } else if (args.contains('--restore')) {
    final backup = jsonDecode(File(args[args.indexOf('--restore') + 1]).readAsStringSync()) as Map<String, dynamic>;
    db.execute("UPDATE privacy_preferences SET lock_enabled=?, notification_preview_mode=?, updated_at_utc=? WHERE key='primary';", [
      backup['lock_enabled'], backup['notification_preview_mode'], now,
    ]);
    db.execute("UPDATE notification_preferences SET event_reminders_enabled=?, task_reminders_enabled=?, default_task_reminder_minutes=?, quiet_hours_enabled=?, quiet_start_minute=?, quiet_end_minute=?, updated_at_utc=?;", [
      backup['event_reminders_enabled'], backup['task_reminders_enabled'], backup['default_task_reminder_minutes'],
      backup['quiet_hours_enabled'], backup['quiet_start_minute'], backup['quiet_end_minute'], now,
    ]);
    stdout.writeln('restored pre-review values: $backup');
    await pushDb(db, local);
    stdout.writeln('pushed.');
  } else {
    final i = args.indexOf('--show');
    if (i >= 0) {
      db.execute("UPDATE privacy_preferences SET notification_preview_mode=?, updated_at_utc=? WHERE key='primary';", [args[i + 1], now]);
      stdout.writeln('notification_preview_mode -> ${args[i + 1]}');
    }
    final l = args.indexOf('--lock');
    if (l >= 0) {
      db.execute("UPDATE privacy_preferences SET lock_enabled=?, updated_at_utc=? WHERE key='primary';", [args[l + 1], now]);
      stdout.writeln('lock_enabled -> ${args[l + 1]}');
    }
    final q = args.indexOf('--quiet');
    if (q >= 0) {
      final start = int.parse(args[q + 1]);
      final end = int.parse(args[q + 2]);
      db.execute("UPDATE notification_preferences SET quiet_hours_enabled=1, quiet_start_minute=?, quiet_end_minute=?, updated_at_utc=?;", [start, end, now]);
      stdout.writeln('quiet hours -> $start..$end');
    }
    final p = db.select("SELECT lock_enabled, notification_preview_mode FROM privacy_preferences WHERE key='primary';");
    final n = db.select("SELECT quiet_hours_enabled, quiet_start_minute, quiet_end_minute FROM notification_preferences;");
    stdout.writeln('privacy now: ${p.rows.first.join(' | ')}');
    stdout.writeln('quiet now: ${n.rows.first.join(' | ')}');
    await pushDb(db, local);
    stdout.writeln('pushed.');
  }
  db.dispose();
  await dir.delete(recursive: true);
}
