import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';

final class GoalIconPickerArgs {
  const GoalIconPickerArgs({
    required this.goalTitle,
    required this.currentIconId,
    this.initialCategory,
  });

  final String goalTitle;
  final String? currentIconId;

  /// Optional internal category active on open (null = All). Display-only;
  /// the saved iconId is never affected by the active filter.
  final String? initialCategory;
}

final class GoalIconPickerScreen extends StatefulWidget {
  const GoalIconPickerScreen({
    required this.args,
    this.onSelected,
    this.onCancel,
    super.key,
  });

  final GoalIconPickerArgs args;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onCancel;

  @override
  State<GoalIconPickerScreen> createState() => _GoalIconPickerScreenState();
}

final class _GoalIconPickerScreenState extends State<GoalIconPickerScreen> {
  /// Internal registry categories in picker order (display labels come from
  /// the registry's display-only Stage-1.2 mapping; null means All).
  static const List<String> _categoryOrder = <String>[
    'Work & Learning',
    'Money & Home',
    'Health & Daily Life',
    'People & Relationships',
    'Faith & Service',
    'Travel & Interests',
  ];

  String? _selectedId;
  String? _activeCategory;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    // Resolve through the registry so a stored retired alias (find_job /
    // finance_pie_chart) selects its canonical tile without any data rewrite.
    _selectedId =
        GoalIconRegistry.instance.findById(widget.args.currentIconId)?.id;
    _activeCategory =
        GoalIconRegistry.approvedCategories.contains(widget.args.initialCategory)
            ? widget.args.initialCategory
            : null;
  }

  @override
  Widget build(BuildContext context) {
    final allIcons = GoalIconRegistry.allIcons;
    final suggestions = GoalIconRegistry.instance.suggestionsForGoalTitle(
      widget.args.goalTitle,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // Step 9 density: art 64dp, row 72 (80 at textScale >= 1.25);
    // columns are width-responsive in _IconGrid (4/3/2/1 at 306/228/150).
    final tileHeight = textScale >= 1.25 ? 80.0 : 72.0;
    final filteredIcons = _activeCategory == null
        ? allIcons
        : allIcons
              .where((definition) => definition.category == _activeCategory)
              .toList(growable: false);
    final scaffold = Scaffold(
      appBar: InternalAppBar(
        // A8: Material 3 swaps the fallback app-bar base from surface to
        // surfaceContainer once the list scrolls under it.  Transparent
        // surface tint alone does not pin the base color, so Choose Icon
        // pins surface + zero scrolled-under elevation explicitly.  B2: the
        // pinned base follows the active theme surface (dark #181A1E,
        // light #F4F1F2) so unscrolled == scrolled-under in BOTH themes with
        // no brown/maroon shift.
        backgroundColor: AppTheme.surfaceOf(context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('goal-icon-picker-back'),
          tooltip: 'Back',
          onPressed: _close,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Choose Icon'),
        actions: <Widget>[
          TextButton(
            key: const Key('goal-icon-picker-save'),
            onPressed: _selectedId == null ? null : _save,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: ListView(
            padding: InternalScreen.pagePadding,
            children: <Widget>[
              Text(
                'Choose an icon for your goal',
                style: InternalScreen.sectionHeading,
              ),
              const SizedBox(height: 3),
              const Text(
                'Icons help you quickly identify your goals.',
                style: AppTypography.secondary,
              ),
              const SizedBox(height: 14),
              if (suggestions.isNotEmpty) ...<Widget>[
                Text(
                  'Suggested for "${widget.args.goalTitle}"',
                  style: InternalScreen.sectionHeading,
                ),
                const SizedBox(height: 8),
                _IconGrid(
                  key: const Key('goal-icon-suggestions'),
                  icons: <GoalIconDefinition>[
                    for (final suggestion in suggestions) suggestion.definition,
                  ],
                  selectedId: _selectedId,
                  tileHeight: tileHeight,
                  onSelected: _select,
                ),
                const SizedBox(height: 18),
              ],
              const SizedBox(height: 18),
              SingleChildScrollView(
                key: const Key('goal-icon-category-chips'),
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      _CategoryChip(
                        label: 'All',
                        selected: _activeCategory == null,
                        onTap: () => setState(() => _activeCategory = null),
                      ),
                      for (final category in _categoryOrder)
                        _CategoryChip(
                          label: GoalIconRegistry.displayCategoryLabel(
                            category,
                          ),
                          selected: _activeCategory == category,
                          onTap: () => setState(() => _activeCategory = category),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('All Icons', style: InternalScreen.sectionHeading),
              const SizedBox(height: 8),
              _IconGrid(
                key: const Key('goal-icon-all'),
                icons: filteredIcons,
                selectedId: _selectedId,
                tileHeight: tileHeight,
                onSelected: _select,
              ),
              const SizedBox(height: 16),
              const Text(
                'Select an icon for your goal. You can change it at any time '
                'in Edit Goal.',
                style: AppTypography.secondary,
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.onCancel == null) {
      return scaffold;
    }
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _close();
        }
      },
      child: scaffold,
    );
  }

  void _select(String iconId) {
    setState(() => _selectedId = iconId);
  }

  void _save() {
    final selected = _selectedId;
    if (selected != null && !_returning) {
      _returning = true;
      final onSelected = widget.onSelected;
      if (onSelected != null) {
        onSelected(selected);
      } else {
        Navigator.of(context).pop(selected);
      }
    }
  }

  void _close() {
    if (_returning) {
      return;
    }
    _returning = true;
    final onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
    } else {
      Navigator.of(context).pop();
    }
  }
}

final class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.icons,
    required this.selectedId,
    required this.tileHeight,
    required this.onSelected,
    super.key,
  });

  final List<GoalIconDefinition> icons;
  final String? selectedId;
  final double tileHeight;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    // Step 9 density: width-responsive columns. The inner width is the
    // incoming constraint (page padding already applied upstream); each
    // breakpoint preserves a >=72dp cell width.
    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth;
        final crossAxisCount = innerWidth >= 306
            ? 4
            : innerWidth >= 228
            ? 3
            : innerWidth >= 150
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: icons.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 6,
            mainAxisSpacing: 10,
            mainAxisExtent: tileHeight,
          ),
          itemBuilder: (context, index) {
            final definition = icons[index];
            return _IconTile(
              definition: definition,
              selected: definition.id == selectedId,
              onTap: () => onSelected(definition.id),
            );
          },
        );
      },
    );
  }
}

final class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.definition,
    required this.selected,
    required this.onTap,
  });

  final GoalIconDefinition definition;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Theme.of(context).colorScheme.primary
        : AppTheme.cardBorderOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${definition.displayName}, ${definition.semanticsLabel}, '
          '${selected ? 'selected' : 'not selected'}',
      hint: selected ? 'Selected' : 'Double tap to select',
      child: Card(
        key: Key('goal-icon-tile-${definition.id}'),
        margin: EdgeInsets.zero,
        // GP-01: in Light the tile sits on the near-white semantic surface
        // (the same card surface as Home Goal cards) so the grid reads as
        // clean white tiles with a subtle outline boundary instead of a gray
        // slab over the canvas; Dark keeps the transparent tile (GI-01 raw
        // art, no plate). 96dp art and the 3-column grid are unchanged.
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.transparent
            : AppTheme.cardOf(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Icon-only compact tile: the icon is the only visual content; the
          // display name and category live in the semantics label and search
          // metadata (owner requirement, Stage-1 picker contract).
          child: Stack(
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ExcludeSemantics(
                    child: GoalIcon(
                      iconId: definition.id,
                      // Step 9 density: 96 -> 64 (the Planning size).
                      size: 64,
                      // Step 8 (R01): the null/unknown-ID fallback uses the
                      // Goal artwork-family blue (definitions always render
                      // SVG art, so this only colors the fallback glyph).
                      color: AppTheme.goalIconFallbackBlue,
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 14,
                        ),
                      ),
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

/// Stage-1.2 horizontal category filter chip (display label only; internal
/// registry category values and saved iconIds are never affected).
final class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : AppTheme.cardBorderOf(context),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: Key('goal-icon-chip-$label'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: selected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
