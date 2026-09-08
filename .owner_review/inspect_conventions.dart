// Read-only: full schema + one sample row per table to learn conventions.
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
const dllDir = r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows';
const pkg = 'com.nexttransfer.rmplanner';
const device = 'adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp';
const deviceDb = 'app_flutter/next_transfer.sqlite';

Future<void> main() async {
  final dll = File('$dllDir\\sqlite3.dll');
  if (dll.existsSync()) DynamicLibrary.open(dll.path);
  final dir = await Directory.systemTemp.createTemp('nt_review_db');
  final local = '${dir.path}${Platform.pathSeparator}next_transfer.sqlite';
  final p = await Process.run(adb, ['-s', device, 'shell', 'run-as $pkg base64 $deviceDb']);
  await File(local).writeAsBytes(base64Decode((p.stdout as String).replaceAll(RegExp(r'\s'), '')));
  final db = sqlite3.open(local, mode: OpenMode.readOnly);
  for (final t in const ['calendar_events', 'planner_tasks']) {
    stdout.writeln('===== $t columns =====');
    final cols = db.select('PRAGMA table_info($t)');
    for (final c in cols.rows) {
      stdout.writeln('${c[1]} : ${c[2]} notnull=${c[3]} default=${c[4]} pk=${c[5]}');
    }
    stdout.writeln('===== $t sample row =====');
    final row = db.select('SELECT * FROM $t LIMIT 1');
    if (row.rows.isEmpty) {
      stdout.writeln('(empty)');
    } else {
      final names = row.columnNames;
      for (var i = 0; i < names.length; i++) {
        stdout.writeln('${names[i]} = ${row.rows.first[i]}');
      }
    }
  }
  stdout.writeln('===== timed future events count by time_zone_id =====');
  final tz = db.select("SELECT time_zone_id, COUNT(*) n FROM calendar_events WHERE timing='timed' GROUP BY time_zone_id");
  for (final r in tz.rows) {
    stdout.writeln(r.join(' | '));
  }
  db.dispose();
  await dir.delete(recursive: true);
}
