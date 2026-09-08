// PRE-M5 policy mode tool (agent-owned). Edits ONLY the 'NT PREM5 TIMING'
// reminder_policies rows. App process MUST be stopped while DB is replaced.
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

int argVal(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return -1;
  return int.parse(args[i + 1]);
}

Future<void> main(List<String> args) async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) DynamicLibrary.open(dll.path);
  final nowUtcSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final db = await pullDb(dir);
  db.execute('BEGIN;');
  try {
    for (final spec in [
      ('policy-event-a', 'calendarEvent', argVal(args, '--a')),
      ('policy-event-b', 'calendarEvent', argVal(args, '--b')),
      ('policy-task-t', 'task', argVal(args, '--t')),
    ]) {
      final (pk, _, min) = spec;
      if (min < 0) continue;
      db.execute(
        "UPDATE reminder_policies SET mode='offset', offset_minutes=?, updated_at_utc=? WHERE id=?;",
        [min, nowUtcSeconds, stableId(pk)],
      );
      stdout.writeln('$pk -> offset $min');
    }
    db.execute('COMMIT;');
  } catch (e) {
    db.execute('ROLLBACK;');
    rethrow;
  } finally {
    await pushDb(db, '${dir.path}${Platform.pathSeparator}next_transfer.sqlite');
    dir.deleteSync(recursive: true);
  }
}
