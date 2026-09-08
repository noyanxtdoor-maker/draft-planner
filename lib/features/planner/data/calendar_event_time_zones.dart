import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:rmplanner/features/planner/domain/planner_date.dart';
import 'package:timezone/data/latest.dart' as time_zone_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class DeviceTimeZoneSource {
  Future<String> readTimeZoneId();
}

final class FlutterDeviceTimeZoneSource implements DeviceTimeZoneSource {
  const FlutterDeviceTimeZoneSource();

  @override
  Future<String> readTimeZoneId() async {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  }
}

final class IanaCalendarEventTimeZones {
  IanaCalendarEventTimeZones({required this.displayTimeZoneId}) {
    if (!isValid(displayTimeZoneId)) {
      throw ArgumentError.value(
        displayTimeZoneId,
        'displayTimeZoneId',
        'A valid IANA time-zone identity is required',
      );
    }
  }

  static bool _initialized = false;

  final String displayTimeZoneId;

  /// Canonical device zone as a [tz.Location] for Quiet Hours arithmetic so
  /// every delayed target uses the same wall clock as Event/Task scheduling.
  tz.Location get deviceLocation => tz.getLocation(displayTimeZoneId);

  static void initialize() {
    if (_initialized) {
      return;
    }
    time_zone_data.initializeTimeZones();
    _initialized = true;
  }

  static Future<IanaCalendarEventTimeZones> forDevice({
    DeviceTimeZoneSource source = const FlutterDeviceTimeZoneSource(),
  }) async {
    initialize();
    String zoneId;
    try {
      zoneId = await source.readTimeZoneId();
    } on Object {
      zoneId = 'Etc/UTC';
    }
    if (!tz.timeZoneDatabase.locations.containsKey(zoneId)) {
      zoneId = 'Etc/UTC';
    }
    return IanaCalendarEventTimeZones(displayTimeZoneId: zoneId);
  }

  bool isValid(String timeZoneId) {
    initialize();
    return tz.timeZoneDatabase.locations.containsKey(timeZoneId);
  }

  DateTime wallTimeToUtc({
    required PlannerDate date,
    required int minuteOfDay,
    required String timeZoneId,
  }) {
    final location = tz.getLocation(timeZoneId);
    final value = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      minuteOfDay ~/ 60,
      minuteOfDay % 60,
    );
    return value.toUtc();
  }

  DateTime utcToDisplayWall(DateTime value) {
    return utcToWall(value: value, timeZoneId: displayTimeZoneId);
  }

  DateTime utcToWall({required DateTime value, required String timeZoneId}) {
    final display = tz.TZDateTime.from(
      value.toUtc(),
      tz.getLocation(timeZoneId),
    );
    return DateTime(
      display.year,
      display.month,
      display.day,
      display.hour,
      display.minute,
      display.second,
    );
  }

  PlannerDate utcToDisplayDate(DateTime value) {
    return PlannerDate.fromDateTime(utcToDisplayWall(value));
  }
}
