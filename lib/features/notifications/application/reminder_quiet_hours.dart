import 'package:rmplanner/features/notifications/domain/notification_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Computes local calendar boundaries rather than adding 24-hour durations,
/// so daylight-saving transitions keep the configured wall-clock end time.
abstract final class ReminderQuietHours {
  static DateTime delayUntilEnd({
    required DateTime targetUtc,
    required QuietHoursSettings settings,
    tz.Location? location,
  }) {
    if (!settings.enabled) return targetUtc;
    final local = location == null
        ? targetUtc.toLocal()
        : tz.TZDateTime.from(targetUtc, location);
    final minute = local.hour * 60 + local.minute;
    if (!settings.isInQuietHours(minute)) return targetUtc;
    final end = settings.endMinute!;
    final nextDay =
        settings.startMinute! > end && minute >= settings.startMinute!;
    return (location == null
            ? DateTime(
                local.year,
                local.month,
                local.day + (nextDay ? 1 : 0),
                end ~/ 60,
                end % 60,
              )
            : tz.TZDateTime(
                location,
                local.year,
                local.month,
                local.day + (nextDay ? 1 : 0),
                end ~/ 60,
                end % 60,
              ))
        .toUtc();
  }
}
