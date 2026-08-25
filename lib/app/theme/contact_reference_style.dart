import 'package:flutter/material.dart';

/// Light-mode Contact presentation tokens derived from the supplied reference
/// captures. They are intentionally opt-in: existing data and the app-wide
/// appearance preferences remain authoritative outside Contact presentation.
abstract final class ContactReferenceStyle {
  static const Color canvas = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFF1F3F7);
  static const Color raisedSurface = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFC4CDD4);
  static const Color onCanvas = Color(0xFF202124);
  static const Color destructive = Color(0xFFB3261E);
  static const Color success = Color(0xFF2F8F46);
  static const Color warning = Color(0xFFF5AE19);

  static bool _isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color canvasOf(BuildContext context) =>
      _isLight(context) ? canvas : Theme.of(context).colorScheme.surface;

  static Color surfaceOf(BuildContext context) => _isLight(context)
      ? surface
      : Theme.of(context).colorScheme.surfaceContainer;

  static Color raisedSurfaceOf(BuildContext context) =>
      _isLight(context) ? raisedSurface : Theme.of(context).colorScheme.surface;

  static Color lineOf(BuildContext context) =>
      _isLight(context) ? line : Theme.of(context).colorScheme.outlineVariant;

  /// Contact presentation must follow the selected Next Transfer color mode.
  /// The old fixed light teal bypassed both the Blue and Rose theme-primary
  /// contracts, producing a Profile that could never match the approved
  /// Blue-Light target or respect the owner's chosen appearance mode.
  static Color actionOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color onCanvasOf(BuildContext context) =>
      _isLight(context) ? onCanvas : Theme.of(context).colorScheme.onSurface;

  static Color destructiveOf(BuildContext context) =>
      _isLight(context) ? destructive : Theme.of(context).colorScheme.error;

  static Color successOf(BuildContext context) =>
      _isLight(context) ? success : const Color(0xFF81C784);

  static Color warningOf(BuildContext context) =>
      _isLight(context) ? warning : const Color(0xFFFFD166);
}
