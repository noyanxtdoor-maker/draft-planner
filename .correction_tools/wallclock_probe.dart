// Probe: what do the same wall-clock fields look like inside a plain `dart`
// isolate (headless WorkManager equivalent) on THIS Windows machine?
// The device claim to verify is the same in principle: TZDateTime(location)
// returns wall-clock numbers in that location regardless of process default.
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  tzdata.initializeTimeZones();
  final manila = tz.getLocation('Asia/Manila');
  final t = tz.TZDateTime(manila, 2026, 9, 7, 11, 35);
  print('TZDateTime(Asia/Manila, 2026-09-07 11:35).hour = ${t.hour}');
  print('.timeZoneOffset = ${t.timeZoneOffset}');
  print('.toUtc().hour = ${t.toUtc().hour}');
  final utc = DateTime.utc(2026, 9, 7, 3, 35);
  final shown = tz.TZDateTime.from(utc, manila);
  print('TZDateTime.from(03:35Z, Manila).hour = ${shown.hour} (expect 11)');
  // default local zone in this headless process:
  print('DateTime.now() here is local-machine zone; TZDateTime ops above are location-scoped.');
}
