import 'package:flutter/foundation.dart';

final class DiagnosticEvent {
  const DiagnosticEvent({required this.code, required this.safeContext});

  final String code;
  final Map<String, Object?> safeContext;
}

final class DiagnosticExportPreview {
  const DiagnosticExportPreview({
    required this.events,
    required this.includesOptionalContext,
  });

  final List<DiagnosticEvent> events;
  final bool includesOptionalContext;
}

final class SanitizedDiagnostics {
  SanitizedDiagnostics({this.emitToDebugConsole = false});

  static final RegExp _safeCode = RegExp(r'^[a-z0-9_]{1,64}$');
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

  DiagnosticExportPreview prepareExportPreview({
    required bool includeOptionalContext,
  }) {
    final previewEvents = <DiagnosticEvent>[
      for (final event in _events)
        DiagnosticEvent(
          code: event.code,
          safeContext: includeOptionalContext
              ? Map<String, Object?>.unmodifiable(event.safeContext)
              : const <String, Object?>{},
        ),
    ];
    return DiagnosticExportPreview(
      events: List<DiagnosticEvent>.unmodifiable(previewEvents),
      includesOptionalContext: includeOptionalContext,
    );
  }

  void record(
    String code, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final safeCode = _safeCode.hasMatch(code)
        ? code
        : 'invalid_diagnostic_code';
    final safeContext = <String, Object?>{
      for (final entry in context.entries)
        if (_allowedContextKeys.contains(entry.key) &&
            _isSafeScalar(entry.value))
          entry.key: entry.value,
    };
    _events.add(DiagnosticEvent(code: safeCode, safeContext: safeContext));

    if (emitToDebugConsole) {
      debugPrint('[NextTransfer] $safeCode $safeContext');
    }
  }

  bool _isSafeScalar(Object? value) {
    return value == null || value is bool || value is int || value is String;
  }
}
