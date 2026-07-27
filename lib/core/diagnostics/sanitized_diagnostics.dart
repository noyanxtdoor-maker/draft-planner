import 'package:flutter/foundation.dart';

final class DiagnosticEvent {
  const DiagnosticEvent({required this.code, required this.safeContext});

  final String code;
  final Map<String, Object?> safeContext;
}

final class SanitizedDiagnostics {
  SanitizedDiagnostics({this.emitToDebugConsole = false});

  static const Set<String> _allowedContextKeys = <String>{
    'attempt',
    'database_state',
    'onboarding_stage',
    'route_kind',
    'schema_from',
    'schema_to',
  };

  final bool emitToDebugConsole;
  final List<DiagnosticEvent> _events = <DiagnosticEvent>[];

  List<DiagnosticEvent> get events =>
      List<DiagnosticEvent>.unmodifiable(_events);

  void record(
    String code, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final safeContext = <String, Object?>{
      for (final entry in context.entries)
        if (_allowedContextKeys.contains(entry.key) &&
            _isSafeScalar(entry.value))
          entry.key: entry.value,
    };
    _events.add(DiagnosticEvent(code: code, safeContext: safeContext));

    if (emitToDebugConsole) {
      debugPrint('[NextTransfer] $code $safeContext');
    }
  }

  bool _isSafeScalar(Object? value) {
    return value == null || value is bool || value is int || value is String;
  }
}
