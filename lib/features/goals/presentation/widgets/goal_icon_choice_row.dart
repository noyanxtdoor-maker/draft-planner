import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';

final class GoalIconChoiceRow extends StatelessWidget {
  const GoalIconChoiceRow({
    required this.goalTitle,
    required this.iconId,
    required this.fallbackIcon,
    required this.onTap,
    this.showSuggestion = false,
    super.key,
  });

  final String goalTitle;
  final String? iconId;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final bool showSuggestion;

  @override
  Widget build(BuildContext context) {
    final definition = GoalIconRegistry.instance.findById(iconId);
    final name = definition?.displayName ?? 'Choose an icon';
    final supporting = showSuggestion && definition != null
        ? 'Suggested from "$goalTitle"'
        : definition?.category ?? 'Optional';
    return Semantics(
      button: true,
      label: definition == null
          ? 'Choose an icon for $goalTitle'
          : '$name icon for $goalTitle',
      hint: 'Opens Choose Icon',
      child: InkWell(
        key: const Key('goal-icon-choice-row'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // GI-02: goal art doubles to 72dp; keep just enough height.
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            // POLISH-04: Light uses the semantic near-white surface + outline
            // (never a gray slab); Dark keeps its deep surface fill.
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.surfaceOf(context)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineOf(context)),
          ),
          child: Row(
            children: <Widget>[
              GoalIcon(
                iconId: iconId,
                // GI-02: exactly 2x (36 -> 72).
                size: 72,
                semanticLabel: definition?.semanticsLabel ?? 'No icon selected',
                fallbackIcon: fallbackIcon,
                // Step 8 (R01): the 'No icon selected' fallback uses the Goal
                // artwork-family blue (#5CAEC9) consistently with Planning,
                // Home, and the archive.
                color: AppTheme.goalIconFallbackBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supporting,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: showSuggestion
                            ? AppTheme.accentTealOf(context)
                            : AppTheme.onFillTextOf(context, 0.70),
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        definition == null ? 'Choose' : 'Change',
                        style: AppTypography.cardTitle.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
