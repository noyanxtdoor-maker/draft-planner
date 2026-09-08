import 'package:rmplanner/core/notifications/notification_payload.dart';

enum NotificationChannelKind { reminders, planning }

extension NotificationChannelDefinition on NotificationChannelKind {
  String get id => switch (this) {
    NotificationChannelKind.reminders => 'next_transfer_reminders',
    NotificationChannelKind.planning => 'next_transfer_planning',
  };

  String get label => switch (this) {
    NotificationChannelKind.reminders => 'Reminders',
    NotificationChannelKind.planning => 'Planning',
  };

  String get description => switch (this) {
    NotificationChannelKind.reminders =>
      'User-selected Event and Task reminders.',
    NotificationChannelKind.planning =>
      'Planning reminders introduced in later milestones.',
  };
}

final class LocalNotificationRequest {
  const LocalNotificationRequest({
    required this.platformId,
    required this.stableKey,
    required this.channel,
    required this.scheduledAtUtc,
    required this.title,
    required this.body,
    required this.responseIntent,
  });

  final int platformId;
  final String stableKey;
  final NotificationChannelKind channel;
  final DateTime scheduledAtUtc;
  final String title;
  final String body;
  final NotificationResponseIntent responseIntent;
}

final class PendingLocalNotification {
  const PendingLocalNotification({required this.platformId, this.payload});

  final int platformId;
  final String? payload;
}

abstract interface class NotificationGateway {
  Stream<NotificationResponseIntent> get responses;

  Future<void> initialize();

  Future<void> schedule(LocalNotificationRequest request);

  Future<void> cancel(int platformId);

  Future<List<PendingLocalNotification>> pending();

  NotificationResponseIntent? takeInitialResponse();
}
