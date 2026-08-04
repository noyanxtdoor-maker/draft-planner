import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';
import 'package:rmplanner/features/goals/presentation/widgets/goal_icon.dart';

final class GoalIconPickerArgs {
  const GoalIconPickerArgs({
    required this.goalTitle,
    required this.currentIconId,
  });

  final String goalTitle;
  final String? currentIconId;
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
  final _searchController = TextEditingController();
  String? _selectedId;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    _selectedId = GoalIconRegistry.instance.contains(widget.args.currentIconId)
        ? widget.args.currentIconId
        : null;
    _searchController.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_searchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _searchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text;
    final allIcons = GoalIconRegistry.instance.search(query);
    final suggestions = query.trim().isEmpty
        ? GoalIconRegistry.instance.suggestionsForGoalTitle(
            widget.args.goalTitle,
          )
        : const <GoalIconSuggestion>[];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final tileHeight = textScale >= 1.25 ? 136.0 : 124.0;
    return Scaffold(
      appBar: AppBar(
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
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: <Widget>[
              Text(
                'Choose an icon for your goal',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 3),
              const Text(
                'Icons help you quickly identify your goals.',
                style: AppTypography.secondary,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('goal-icon-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search icons...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('goal-icon-search-clear'),
                          tooltip: 'Clear search',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              if (suggestions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                Text(
                  'Suggested for "${widget.args.goalTitle}"',
                  style: AppTypography.sectionTitle,
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
              ],
              const SizedBox(height: 22),
              Text('All Icons', style: AppTypography.sectionTitle),
              const SizedBox(height: 8),
              if (allIcons.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        Text('No icons found.'),
                        SizedBox(height: 4),
                        Text('Try a different search.'),
                      ],
                    ),
                  ),
                )
              else
                _IconGrid(
                  key: const Key('goal-icon-all'),
                  icons: allIcons,
                  selectedId: _selectedId,
                  tileHeight: tileHeight,
                  onSelected: _select,
                ),
              const SizedBox(height: 16),
              const Text(
                'Select one of the six approved goal icons. You can change it '
                'at any time in Edit Goal.',
                style: AppTypography.secondary,
              ),
            ],
          ),
        ),
      ),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: icons.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
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
    final border = selected ? AppTheme.rose : const Color(0xFF414649);
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
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: <Widget>[
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      ExcludeSemantics(
                        child: GoalIcon(
                          iconId: definition.id,
                          size: 32,
                          color: AppTheme.rose,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        definition.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.micro.copyWith(
                          color: selected ? AppTheme.rose : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        definition.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.secondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppTheme.rose,
                        shape: BoxShape.circle,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.check,
                          color: Color(0xFF340012),
                          size: 16,
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
