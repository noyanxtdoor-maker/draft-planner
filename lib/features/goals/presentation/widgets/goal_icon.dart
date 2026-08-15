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
/// Pack B2 light bridge: the raw teal/gold SVG artwork passes contrast on the
/// app's dark surfaces (7.14/7.86:1 measured in the Pack B audit) but fails on
/// a light background (2.18/1.97:1).  In Light mode the artwork gets a compact
/// dark plate (the same #181A1E surface the app uses in Dark) that sits ONLY
/// behind the artwork.  B3.3 R2 refined the plate so it reads intentional
/// rather than oversized: artwork inset 0.12 x size, corner radius 0.30 x
/// size.  Assets, registry IDs, dark output, and the outer [size] geometry
/// are unchanged.
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
      final svg = ExcludeSemantics(
        child: SvgPicture.asset(
          definition.assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: null,
          excludeFromSemantics: true,
        ),
      );
      if (Theme.of(context).brightness == Brightness.dark) {
        child = svg;
      } else {
        // Light-only dark artwork plate (B3.3 R2: 12% inset, 30% corner
        // radius of size).  Keeps teal/gold artwork >= 3:1 against the app
        // surface while reading intentional rather than oversized/heavy.
        child = DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(size * 0.30),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.12),
            child: Center(child: svg),
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
