import 'dart:convert'; import 'dart:ffi'; import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
void main() {
  DynamicLibrary.open(r'C:\Users\sherl\Downloads\NT_C7_IMPLEMENTATION_20260825_235900\build\native_assets\windows\sqlite3.dll');
  final adb = r'C:\Users\sherl\AppData\Local\Temp\next-transfer-toolchain\android-sdk\platform-tools\adb.exe';
  final dir = Directory.systemTemp.createTempSync('pol');
  final local = dir.path + '/db.sqlite';
  final p = Process.runSync(adb, ['-s','adb-10620253B3004617-2m7ZVB._adb-tls-connect._tcp','shell','run-as com.nexttransfer.rmplanner base64 app_flutter/next_transfer.sqlite']);
  File(local).writeAsBytesSync(base64Decode((p.stdout as String).replaceAll(RegExp(r'\s'),'')));
  final db = sqlite3.open(local, mode: OpenMode.readOnly);
  final rows = db.select('SELECT id, source_kind, occurrence_id, purpose, contact_id, mode, offset_minutes FROM reminder_policies LIMIT 8;');
  for (final r in rows.rows) { stdout.writeln(r.join(' | ')); }
  final cnt = db.select('SELECT mode, COUNT(*) FROM reminder_policies GROUP BY mode;');
  for (final r in cnt.rows) { stdout.writeln('mode count: ' + r.join(' | ')); }
  db.dispose(); dir.deleteSync(recursive: true);
}
