import 'package:flutter/foundation.dart';

/// Bounded debug-only trace. IDs/tokens only; never record names or details.
abstract final class MapInteractionTrace {
  static const enabled =
      kDebugMode && bool.fromEnvironment('NT_MAP_TRACE', defaultValue: true);
  static final _clock = Stopwatch()..start();
  static final List<Map<String, Object>> events = [];
  static String token = 'none';
  static int _next = 0;
  static bool _pendingNative = false;

  static void nativeTap(int mapId, int gesture, int renderGeneration) {
    token = 'native:$mapId:$gesture';
    _pendingNative = true;
    record('T0-received', '', extra: 'render=$renderGeneration');
  }

  static void commit(String id) {
    if (!_pendingNative) token = 'dart:${++_next}';
    _pendingNative = false;
    record('T1', id);
  }

  static void record(
    String phase,
    String id, {
    String? gesture,
    String extra = '',
  }) {
    if (!enabled || events.length >= 256) return;
    final entry = <String, Object>{
      'phase': phase,
      'token': gesture ?? token,
      'id': id,
      'us': _clock.elapsedMicroseconds,
      'extra': extra,
    };
    events.add(entry);
    debugPrint('NTMapTiming $entry');
  }
}
