import 'dart:async';

import 'package:rmplanner/core/notifications/notification_payload.dart';

final class NotificationResponseController {
  final StreamController<NotificationResponseIntent> _responses =
      StreamController<NotificationResponseIntent>.broadcast();
  NotificationResponseIntent? _initial;
  NotificationResponseIntent? _lastResponse;
  DateTime? _lastResponseAt;

  Stream<NotificationResponseIntent> get responses => _responses.stream;

  void capture({
    required String? payload,
    String? actionId,
    bool initial = false,
  }) {
    final intent = NotificationPayloadCodec.tryDecode(
      payload,
      actionId: actionId,
    );
    if (intent == null) return;
    final now = DateTime.now();
    if (_lastResponse == intent &&
        _lastResponseAt != null &&
        now.difference(_lastResponseAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastResponse = intent;
    _lastResponseAt = now;
    if (initial && _initial == null) {
      _initial = intent;
      return;
    }
    _responses.add(intent);
  }

  NotificationResponseIntent? takeInitial() {
    final value = _initial;
    _initial = null;
    return value;
  }

  Future<void> dispose() => _responses.close();
}
