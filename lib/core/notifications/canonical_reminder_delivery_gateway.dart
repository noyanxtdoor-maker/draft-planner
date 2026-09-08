import 'package:rmplanner/core/notifications/notification_gateway.dart';

/// A gateway that re-reads repository truth at delivery instead of persisting
/// rendered content in an alarm or a background input payload.
abstract interface class CanonicalReminderDeliveryGateway {
  Future<bool> hasPendingReminder(int platformId, DateTime scheduledAtUtc);
  Future<bool> hasDisplayedReminder(int platformId);
  Future<void> showCanonicalReminder(LocalNotificationRequest request);
}
