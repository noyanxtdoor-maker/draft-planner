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
    final child = definition == null
        ? Icon(fallbackIcon ?? _fallbackForRole(null), size: size, color: color)
        : ExcludeSemantics(
            child: SvgPicture.asset(
              definition.assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              colorFilter: null,
              excludeFromSemantics: true,
            ),
          );
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
