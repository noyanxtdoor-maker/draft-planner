import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/features/maps/application/boundary_edit_session.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';
import 'package:rmplanner/features/maps/presentation/saved_place_marker_visuals.dart';
import 'package:rmplanner/features/settings/presentation/event_color_picker_dialog.dart';

/// Full-screen Saved Place editor shared by Add Place and Edit Place. It uses
/// the canonical Next Transfer form design system (InternalAppBar,
/// InternalScreen tokens) so fonts, colors, spacing and components match the
/// established Planner/Add/Edit forms; PMG supplies layout/proportion only.
/// It owns draft presentation and validation; the Maps workflow remains the
/// sole persistence boundary.
///
/// M6.1 Pass 2: Define Boundary happens on the SAME canonical Maps canvas.
/// The form NEVER pushes a second GoogleMap — tapping + Boundary commits a
/// [SavedPlaceFormSnapshot] into [boundaryEditSessionProvider] and pops the
/// form; the canonical map enters Define Boundary mode. Done/X re-opens THIS
/// form with every unsaved value restored verbatim from the session snapshot.
final class SavedPlaceFormScreen extends ConsumerStatefulWidget {
  const SavedPlaceFormScreen({
    required this.coordinate,
    required this.onSave,
    required this.onCancel,
    this.initialPlace,
    this.initialSnapshot,
    super.key,
  });

  final MapCoordinate coordinate;
  final SavedPlace? initialPlace;

  /// Same-map round trip: exact form state captured at the previous yield.
  /// Non-null only when re-opening after Define Boundary Done/X.
  final SavedPlaceFormSnapshot? initialSnapshot;
  final Future<void> Function(SavedPlaceDraft draft) onSave;
  final VoidCallback onCancel;

  @override
  ConsumerState<SavedPlaceFormScreen> createState() =>
      _SavedPlaceFormScreenState();
}

final class _SavedPlaceFormScreenState
    extends ConsumerState<SavedPlaceFormScreen> {
  late final TextEditingController _label;
  late final TextEditingController _emoji;
  late SavedPlaceMarkerMode _mode;
  late SavedPlaceStandardCategory _category;
  late String _colorHex;
  late String _boundaryColorHex;
  SavedPlaceBoundary? _boundaryDraft;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPlace;
    final snapshot = widget.initialSnapshot;
    _label = TextEditingController(
      text: snapshot?.label ?? initial?.label ?? '',
    );
    _emoji = TextEditingController(
      text: snapshot?.customEmoji ?? initial?.customEmoji ?? '',
    );
    _mode =
        snapshot?.markerMode ??
        initial?.markerMode ??
        SavedPlaceMarkerMode.standard;
    _category =
        snapshot?.standardCategory ??
        initial?.standardCategory ??
        SavedPlaceStandardCategory.information;
    _colorHex = normalizeMarkerColorHex(
      snapshot?.markerColorHex ??
          initial?.markerColorHex ??
          _category.defaultColorArgb.toRadixString(16).substring(2),
    );
    // M6: the boundary draft is a COPY of any persisted boundary (or the
    // snapshot's preserved draft after a same-map visit). It stays in memory
    // until the main Save; Cancel discards every draft change.
    _boundaryDraft = snapshot?.boundaryDraft ?? initial?.boundary;
    _boundaryColorHex = normalizeMarkerColorHex(
      snapshot?.boundaryColorHex ??
          initial?.boundary?.colorHex ??
          defaultBoundaryColorHex,
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Color get _previewColor => Color(markerColorHexToArgb(_colorHex));

  Color get _accent => Theme.of(context).colorScheme.primary;

  void _selectCategory(SavedPlaceStandardCategory category) {
    setState(() {
      _category = category;
      _colorHex = normalizeMarkerColorHex(
        category.defaultColorArgb.toRadixString(16).substring(2),
      );
      _error = null;
    });
  }

  Future<void> _chooseColor() async {
    final previousHex = _colorHex;
    final chosen = await showPlannerEventColorPicker(
      context: context,
      eventTypeLabel: 'Saved Place',
      role: EventColorRole.accent,
      initialColor: _previewColor,
      otherColor: _previewColor,
      onChanged: (color) {
        if (mounted) setState(() => _colorHex = colorHex(color));
      },
    );
    if (!mounted) return;
    setState(() => _colorHex = chosen == null ? previousHex : colorHex(chosen));
  }

  Future<void> _save() async {
    if (_saving) return;
    final draft = SavedPlaceDraft(
      label: _label.text,
      coordinate: widget.coordinate,
      markerMode: _mode,
      standardCategory: _category,
      customEmoji: _mode == SavedPlaceMarkerMode.custom ? _emoji.text : null,
      markerColorHex: _colorHex,
      boundary: _boundaryDraft?.copyWith(colorHex: _boundaryColorHex),
    );
    try {
      final normalized = draft.normalized();
      setState(() {
        _saving = true;
        _error = null;
      });
      await widget.onSave(normalized);
    } on SavedPlaceValidationException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.initialPlace == null
              ? 'Saved Place could not be created. Try again.'
              : 'Saved Place could not be updated. Try again.';
        });
      }
    }
  }

  Future<void> _chooseBoundaryColor() async {
    final previousHex = _boundaryColorHex;
    final chosen = await showPlannerEventColorPicker(
      context: context,
      eventTypeLabel: 'Boundary',
      role: EventColorRole.accent,
      initialColor: _boundaryPreviewColor,
      otherColor: _boundaryPreviewColor,
      onChanged: (color) {
        if (mounted) {
          setState(() => _boundaryColorHex = colorHex(color));
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _boundaryColorHex = chosen == null ? previousHex : colorHex(chosen);
    });
  }

  Color get _boundaryPreviewColor =>
      Color(markerColorHexToArgb(_boundaryColorHex));

  /// Exact form state captured at yield time; travels inside the boundary
  /// session so the same form re-opens with every unsaved value intact.
  SavedPlaceFormSnapshot _captureSnapshot() => SavedPlaceFormSnapshot(
    label: _label.text,
    markerMode: _mode,
    standardCategory: _category,
    customEmoji: _emoji.text,
    markerColorHex: _colorHex,
    boundaryColorHex: _boundaryColorHex,
    boundaryDraft: _boundaryDraft,
  );

  /// M6.1 Pass 2: yield to the SAME canonical Maps canvas for Define
  /// Boundary. No second GoogleMap is ever created. The form commits its
  /// exact state into the session, then pops itself (a zero-write cancel
  /// from the Maps workflow's perspective); the canonical map enters
  /// Define Boundary mode with the unchanged camera/map type/context.
  /// Done or X re-opens this form with the snapshot restored.
  void _yieldToBoundaryEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    final initial = widget.initialPlace;
    ref
        .read(boundaryEditSessionProvider.notifier)
        .begin(
          origin: initial == null
              ? BoundaryEditOriginAdd(coordinate: widget.coordinate)
              : BoundaryEditOriginEdit(place: initial),
          snapshot: _captureSnapshot(),
        );
    // Yield: the canonical map takes over THIS route's slot.
    Navigator.of(context).pop();
  }

  /// Trash on the Added Boundary row. A brand-new unsaved draft clears
  /// immediately; a persisted boundary (existing place) requires the locked
  /// confirmation so Cancel-before-Save remains fully truthful.
  Future<void> _removeBoundaryDraft() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (widget.initialPlace?.boundary != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Remove boundary?'),
          content: const Text(
            'This removes the boundary from this Saved Place. '
            'The Saved Place itself will not be deleted.',
          ),
          actions: <Widget>[
            TextButton(
              key: const Key('remove-boundary-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('remove-boundary-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _boundaryDraft = null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) widget.onCancel();
      },
      child: Scaffold(
        key: const Key('saved-place-form-screen'),
        appBar: InternalAppBar(
          backgroundColor: AppTheme.surfaceOf(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          title: Text(widget.initialPlace == null ? 'Add Place' : 'Edit Place'),
          leading: IconButton(
            key: const Key('saved-place-cancel'),
            tooltip: 'Cancel',
            onPressed: _saving ? null : widget.onCancel,
            color: _accent,
            icon: const Icon(Icons.close),
          ),
          actions: <Widget>[
            IconButton(
              key: const Key('saved-place-save'),
              tooltip: 'Save Place',
              onPressed: _saving ? null : () => unawaited(_save()),
              color: _accent,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
            ),
          ],
        ),
        body: GestureDetector(
          key: const Key('saved-place-blank-space-dismiss'),
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            top: false,
            child: ListView(
              key: const Key('saved-place-form-scroll'),
              padding: InternalScreen.pagePadding,
              children: <Widget>[
                Text('Icon', style: InternalScreen.sectionHeading),
                const SizedBox(height: InternalScreen.labelToControlGap),
                const Divider(),
                const SizedBox(height: InternalScreen.fieldGap),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<SavedPlaceMarkerMode>(
                    key: const Key('saved-place-mode'),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: const VisualDensity(
                        horizontal: -4,
                        vertical: -2,
                      ),
                      textStyle: WidgetStateProperty.all(InternalScreen.label),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? _accent
                            : Theme.of(context).colorScheme.surface,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      side: WidgetStateProperty.resolveWith(
                        (states) => BorderSide(
                          color: states.contains(WidgetState.selected)
                              ? _accent
                              : AppTheme.outlineOf(context),
                        ),
                      ),
                    ),
                    segments: const <ButtonSegment<SavedPlaceMarkerMode>>[
                      ButtonSegment<SavedPlaceMarkerMode>(
                        value: SavedPlaceMarkerMode.standard,
                        label: Text('Standard'),
                      ),
                      ButtonSegment<SavedPlaceMarkerMode>(
                        value: SavedPlaceMarkerMode.custom,
                        label: Text('Custom'),
                      ),
                    ],
                    selected: <SavedPlaceMarkerMode>{_mode},
                    onSelectionChanged: (selection) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _mode = selection.first;
                        _error = null;
                      });
                    },
                  ),
                ),
                SizedBox(height: InternalScreen.sectionGap),
                if (_mode == SavedPlaceMarkerMode.standard) ...<Widget>[
                  _buildCategoryGrid(),
                  SizedBox(height: InternalScreen.sectionGap),
                  _buildColorPicker(),
                ] else
                  _buildCustomEmoji(),
                SizedBox(height: InternalScreen.sectionGap),
                Text('Label', style: InternalScreen.sectionHeading),
                const SizedBox(height: InternalScreen.labelToControlGap),
                const Divider(),
                const SizedBox(height: InternalScreen.fieldGap),
                TextField(
                  key: const Key('saved-place-label'),
                  controller: _label,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    labelStyle: InternalScreen.fieldLabel,
                    isDense: true,
                  ),
                ),
                SizedBox(height: InternalScreen.sectionGap),
                Text('Boundary', style: InternalScreen.sectionHeading),
                const SizedBox(height: InternalScreen.labelToControlGap),
                const Divider(),
                const SizedBox(height: InternalScreen.fieldGap),
                if (_boundaryDraft == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      key: const Key('saved-place-add-boundary'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: _yieldToBoundaryEditor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.add, color: _accent, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'Boundary',
                              style: AppTypography.body.copyWith(
                                color: _accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Added Boundary',
                          key: const Key('saved-place-added-boundary'),
                          style: AppTypography.body,
                        ),
                      ),
                      IconButton(
                        key: const Key('saved-place-edit-boundary'),
                        tooltip: 'Edit Boundary',
                        onPressed: _yieldToBoundaryEditor,
                        color: _accent,
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        key: const Key('saved-place-remove-boundary'),
                        tooltip: 'Remove Boundary',
                        onPressed: () => unawaited(_removeBoundaryDraft()),
                        color: Theme.of(context).colorScheme.error,
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                SizedBox(height: InternalScreen.sectionGap),
                Text('Boundary Color', style: InternalScreen.sectionHeading),
                const SizedBox(height: InternalScreen.labelToControlGap),
                const Divider(),
                const SizedBox(height: InternalScreen.fieldGap),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    InkWell(
                      key: const Key('saved-place-continuous-boundary-color'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => unawaited(_chooseBoundaryColor()),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              key: const Key('saved-place-boundary-swatch'),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _boundaryPreviewColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.outlineOf(context),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox.square(
                              dimension: 40,
                              child: Center(
                                child: Icon(
                                  Icons.edit_outlined,
                                  color: _accent,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error case final error?) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    key: const Key('saved-place-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Structural 3x3 category grid. Rows are content-sized (IntrinsicHeight),
  /// so every category label stays fully visible at any text scale — there is
  /// no fixed tile aspect ratio left to overflow.
  Widget _buildCategoryGrid() {
    final categories = SavedPlaceStandardCategory.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var row = 0; row < 3; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final category in categories.sublist(
                  row * 3,
                  row * 3 + 3,
                )) ...<Widget>[
                  if (category != categories[row * 3]) const SizedBox(width: 8),
                  Expanded(
                    child: _CategoryCell(
                      category: category,
                      selected: category == _category,
                      accent: _accent,
                      onTap: () => _selectCategory(category),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomEmoji() {
    return TextField(
      key: const Key('saved-place-emoji'),
      controller: _emoji,
      textInputAction: TextInputAction.done,
      maxLines: 1,
      inputFormatters: <TextInputFormatter>[const _EmojiGraphemeFormatter()],
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: const InputDecoration(
        labelText: 'Emoji',
        labelStyle: InternalScreen.fieldLabel,
        hintText: 'Choose one emoji',
        isDense: true,
      ),
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Icon Color', style: InternalScreen.sectionHeading),
        const SizedBox(height: InternalScreen.labelToControlGap),
        const Divider(),
        const SizedBox(height: InternalScreen.fieldGap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              key: const Key('saved-place-continuous-color'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => unawaited(_chooseColor()),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      key: const Key('saved-place-color-swatch'),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _previewColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.outlineOf(context)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox.square(
                      dimension: 40,
                      child: Center(
                        child: Icon(
                          Icons.edit_outlined,
                          color: _accent,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final class _EmojiGraphemeFormatter extends TextInputFormatter {
  const _EmojiGraphemeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || isSingleEmojiGrapheme(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

final class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.category,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final SavedPlaceStandardCategory category;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectionColor = SavedPlaceVisualIdentity.categoryAccent(
      category,
      accent,
      Theme.of(context).brightness,
    );
    final unselectedIconColor = category == SavedPlaceStandardCategory.avoid
        ? selectionColor
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      key: Key('saved-place-category-${category.storageKey}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: selected ? selectionColor : AppTheme.outlineOf(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected && category != SavedPlaceStandardCategory.avoid)
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: selectionColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  savedPlaceCategoryIcon(category),
                  size: 16,
                  color: selectionColor.computeLuminance() > .179
                      ? Colors.black
                      : Colors.white,
                ),
              )
            else
              Icon(
                savedPlaceCategoryIcon(category),
                size: 26,
                color: unselectedIconColor,
              ),
            const SizedBox(height: 4),
            Text(
              category.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: AppTypography.secondary.copyWith(
                fontSize: 13,
                height: 1.15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? selectionColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
