import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/planner_day.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

/// Resolves the current presentation pair for a Planner item without changing
/// the item or rereading the Event table. The map is supplied by the existing
/// Event Type controller and changes atomically when a settings write lands.
///
/// B2-CORRECTION: the block path is brightness-aware.  DARK returns the
/// existing stored/resolved pair EXACTLY (byte-identical dark output).
/// LIGHT applies the locked deterministic render transform:
///   1. seedAccent = stored/resolved Event accent identity color.
///   2. surface = seedAccent at 16% alpha blended over the active card
///      surface (a pastel, never a dark block).
///   3. foreground/body text = Light onSurface (dark, readable).
///   4. accent/border = seed hue/saturation preserved, HSL lightness lowered
///      only until the accent reaches >= 3:1 against the derived surface.
///   5. pathological custom colors that still cannot reach 3:1 fall back to
///      Light onSurface for the accent while the pastel surface stays.
/// Stored Event data / history / export are never rewritten.
abstract final class PlannerEventColorResolver {
  static EventColorPreference preferenceForType(
    EventType type,
    Map<String, EventColorPreference> preferencesByStableKey,
  ) {
    return preferencesByStableKey[type.stableKey] ??
        PlannerEventColorDefaults.forEventType(type);
  }

  static Color accentColorForType(
    EventType type,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    return Color(
      preferencesByTypeId[type.id]?.accentArgb ??
          PlannerEventColorDefaults.forEventType(type).accentArgb,
    );
  }

  static Color surfaceColorForType(
    EventType type,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    return Color(
      preferencesByTypeId[type.id]?.surfaceArgb ??
          PlannerEventColorDefaults.forEventType(type).surfaceArgb,
    );
  }

  static EventColorPreference? preferenceFor(
    PlannerCalendarItem event,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    final typeId = event.activityTypeId;
    return typeId == null ? null : preferencesByTypeId[typeId];
  }

  /// Block accent (left strip / border / highlight) for [event].
  ///
  /// Dark returns the exact stored/resolved accent.  Light applies the
  /// locked hue-preserving adjustment (see class doc).
  static Color accentColor(
    BuildContext context,
    PlannerCalendarItem event,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    final seed = Color(
      preferenceFor(event, preferencesByTypeId)?.accentArgb ??
          event.activityTypeColorValue ??
          0xFFE91E63,
    );
    if (Theme.of(context).brightness == Brightness.dark) {
      return seed;
    }
    final scheme = Theme.of(context).colorScheme;
    final surface = EventLightRender.surfaceFor(seed, scheme.surface);
    return EventLightRender.accentFor(seed, surface, scheme.onSurface);
  }

  /// Block body surface for [event].
  ///
  /// Dark returns the exact stored/resolved surface.  Light returns the
  /// deterministic pastel derived from the seed accent.
  static Color surfaceColor(
    BuildContext context,
    PlannerCalendarItem event,
    Map<String, EventColorPreference> preferencesByTypeId,
  ) {
    final preference = preferenceFor(event, preferencesByTypeId);
    final seed = Color(
      preference?.accentArgb ?? event.activityTypeColorValue ?? 0xFFE91E63,
    );
    if (Theme.of(context).brightness == Brightness.dark) {
      if (preference != null) {
        return Color(preference.surfaceArgb);
      }
      return PlannerEventBlockColorPolicy.surfaceColor(seed);
    }
    return EventLightRender.surfaceFor(
      seed,
      Theme.of(context).colorScheme.surface,
    );
  }
}

/// The locked deterministic Light Event render transform (B2-CORRECTION).
abstract final class EventLightRender {
  /// Pastel surface: the seed accent at 16% alpha over the active card
  /// surface.
  static Color surfaceFor(Color seedAccent, Color cardSurface) {
    return Color.alphaBlend(
      seedAccent.withValues(alpha: 0.16),
      cardSurface,
    );
  }

  /// Hue/saturation-preserving accent: lower HSL lightness only until the
  /// accent reaches >= 3:1 against [surface]; falls back to [fallback] when
  /// even a bounded lightness floor cannot reach the threshold.
  static Color accentFor(Color seedAccent, Color surface, Color fallback) {
    final hsl = HSLColor.fromColor(seedAccent);
    // Keep the seed's hue and saturation; walk lightness down from the seed
    // (capped at 0.55 so dark seeds never produce a pale accent).
    final start = hsl.lightness > 0.55 ? 0.55 : hsl.lightness;
    var candidate = hsl.withLightness(start).toColor();
    if (_contrast(candidate, surface) >= 3.0) {
      return candidate;
    }
    for (var step = 1; step <= 20; step++) {
      final lightness = start - 0.015 * step;
      if (lightness <= 0.10) {
        break;
      }
      candidate = hsl.withLightness(lightness).toColor();
      if (_contrast(candidate, surface) >= 3.0) {
        return candidate;
      }
    }
    return fallback;
  }

  static double _contrast(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
