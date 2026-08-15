import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';

/// Shared renderer for every production Goal surface.
///
/// The SVG internals are explicitly excluded from semantics so the widget
/// contributes one accessible image node, including when it falls back for a
/// null or unknown ID.
///
/// Light UI Final Polish (POLISH-03): the B3.3 dark plate AND the GI-01
/// 1.06x #181A1E halo are REMOVED.  Light mode renders the raw original
/// two-tone foreground SVG only — no plate, no halo, no artificial black
/// outline, `colorFilter` stays null — and Dark mode is raw SVG only too.
/// The owner prioritizes the clean no-outline direction; text labels
/// accompany Goal Icons so the icon is never the sole information carrier
/// (raw-art Light contrast is recorded honestly in the session audit, not
/// forced by a plate).
///
/// POLISH-06: [spiritual_temple] alone renders at an optical scale of 1.15x
/// via a renderer-only per-ID correction (default 1.0).  Its thin-stroke
/// artwork has the lowest ink density of the family and reads undersized
/// next to peers at the same requested size; the correction is applied by
/// painting the SVG at size / scale and scaling by scale, so the outer
/// [size] geometry stays exact and the caller still requests the same
/// GI-02 size.  No registry identity changes and no SVG edits.
final class GoalIcon extends StatelessWidget {
  const GoalIcon({
    required this.iconId,
    this.size = 32,
    this.semanticLabel,
    this.color = AppTheme.rose,
    this.fallbackIcon,
    super.key,
  });

  final String? iconId;
  final double size;
  final String? semanticLabel;
  final Color color;
  final IconData? fallbackIcon;

  /// Renderer-only optical scale per icon ID (POLISH-06).  Default 1.0;
  /// only the audited outlier is changed.  This is rendering metadata, never
  /// registry identity: IDs/categories/aliases/assets are untouched.
  static const Map<String, double> _opticalScaleById = <String, double>{
    'spiritual_temple': 1.15,
  };

  /// Testable per-ID optical scale; 1.0 for every icon without a correction.
  @visibleForTesting
  static double opticalScaleFor(String? iconId) {
    final definition = GoalIconRegistry.instance.findById(iconId);
    if (definition == null) {
      return 1.0;
    }
    return _opticalScaleById[definition.id] ?? 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final definition = GoalIconRegistry.instance.findById(iconId);
    final label = semanticLabel ?? definition?.semanticsLabel ?? 'Goal icon';
    final Widget child;
    if (definition == null) {
      child = Icon(
        fallbackIcon ?? _fallbackForRole(null),
        size: size,
        color: color,
      );
    } else {
      final opticalScale = _opticalScaleById[definition.id] ?? 1.0;
      if (opticalScale == 1.0) {
        child = ExcludeSemantics(
          child: SvgPicture.asset(
            definition.assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            colorFilter: null,
            excludeFromSemantics: true,
          ),
        );
      } else {
        // Optical scale: paint the SVG at size * scale and shrink it by
        // 1 / scale, so the painted viewBox lands EXACTLY at `size` while
        // the artwork inside renders `scale`-times larger (its transparent
        // viewBox padding is cropped, never the outer box stretched).  The
        // caller still requests the same GI-02 size and nothing overflows.
        child = Center(
          child: Transform.scale(
            scale: 1 / opticalScale,
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: SvgPicture.asset(
                definition.assetPath,
                width: size * opticalScale,
                height: size * opticalScale,
                fit: BoxFit.contain,
                colorFilter: null,
                excludeFromSemantics: true,
              ),
            ),
          ),
        );
      }
    }
    return Semantics(
      image: true,
      label: label,
      child: SizedBox.square(dimension: size, child: child),
    );
  }

  static IconData _fallbackForRole(GoalRole? role) => switch (role) {
    GoalRole.dailyWeekly => Icons.today_outlined,
    GoalRole.weekly => Icons.flag_outlined,
    GoalRole.weeklyMonthly => Icons.calendar_month_outlined,
    null => Icons.flag_outlined,
  };
}

IconData goalIconFallbackForRole(GoalRole? role) => switch (role) {
  GoalRole.dailyWeekly => Icons.today_outlined,
  GoalRole.weekly => Icons.flag_outlined,
  GoalRole.weeklyMonthly => Icons.calendar_month_outlined,
  null => Icons.flag_outlined,
};
