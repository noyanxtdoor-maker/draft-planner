import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';
import 'package:rmplanner/core/colors/vs11_color_system.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';
import 'package:rmplanner/features/planner/domain/event_color_preferences.dart';
import 'package:rmplanner/features/planner/domain/event_type.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_color_preview.dart';
import 'package:rmplanner/features/settings/presentation/event_color_picker_dialog.dart';

/// Opens the Next Transfer Recommended Colors modal (exactly 15 muted
/// swatches in a responsive grid).  Returns the selected color on Apply, or
/// null when the user cancels.  Nothing is persisted here; the caller owns
/// its Save semantics.
Future<Color?> showRecommendedEventColorsDialog(
  BuildContext context, {
  required Color initialColor,
  Iterable<int> peerAccentColors = const <int>[],
}) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _RecommendedEventColorsDialog(
          initialColor: initialColor,
          peerAccentColors: peerAccentColors.toList(growable: false),
        ),
  );
}

/// Opens the custom hex input.  Accepts '#A1B2C3' or 'A1B2C3', validates six
/// hex digits, shows a live preview plus dark-surface warnings, and returns
/// the normalized color on Apply (null on Cancel).
Future<Color?> showCustomHexColorDialog(
  BuildContext context, {
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CustomHexColorDialog(initialColor: initialColor),
  );
}

/// A compact icon-button action (star/sparkles) that opens the Recommended
/// Colors modal.  Keeps a 48 x 48 tap target and a full tooltip/semantics
/// label, so it works on narrow rows without text overflow.
///
/// Used by the Event Colors Settings rows.  The Edit Event Type screen uses
/// the unified inline color panel instead (see [EventTypeColorPanel]).
final class RecommendedEventColorsAction extends StatelessWidget {
  const RecommendedEventColorsAction({
    required this.onPressed,
    this.color = AppTheme.rose,
    super.key,
  });

  final VoidCallback onPressed;
  final Color color;

  static const String label = 'Next Transfer Recommended Colors';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.auto_awesome, size: 22, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// The unified, non-boxed color section used by Edit Event Type.
///
/// One open section on the normal screen background:
///
///   Event Block Color
///   [ live event-block preview ]
///
///   Recommended Colors
///   [ inline 15-swatch palette ]
///
///           🎨 Color Palette      ⬡ Custom Hex
///
/// - a live event-block preview renders the current draft through the same
///   accent -> surface pipeline as the Planner block;
/// - the inline Recommended Colors grid replaces the recommended modal on
///   this screen: tapping a swatch immediately updates the draft accent;
/// - [Color Palette] and [Custom Hex] are compact inline icon/text actions
///   with no outline or card shape;
/// - there is no standalone sparkle control and no separate surface picker
///   in this section.
///
/// Every action reports through [onColorChanged] as a draft; the caller
/// persists only when its own Save contract runs.
final class EventTypeColorPanel extends StatelessWidget {
  const EventTypeColorPanel({
    required this.eventTypeLabel,
    required this.currentPreference,
    required this.initialColor,
    required this.onColorChanged,
    this.peerAccentColors = const <int>[],
    super.key,
  });

  final String eventTypeLabel;

  /// The saved/fallback (accent + surface) pair before this edit session.
  final EventColorPreference currentPreference;

  /// The current draft accent (0xAARRGGBB).
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final Iterable<int> peerAccentColors;

  /// The preview pair: an unchanged accent preserves the curated stored
  /// surface; a changed accent derives the surface through the existing
  /// policy so the preview can never show a stale old-color surface.
  EventColorPreference get _previewPreference => EventColorPreference(
    accentArgb: initialColor.toARGB32(),
    surfaceArgb: PlannerEventBlockColorPolicy.resolvedSurfaceArgb(
      accentArgb: initialColor.toARGB32(),
      currentAccentArgb: currentPreference.accentArgb,
      currentSurfaceArgb: currentPreference.surfaceArgb,
    ),
  );

  /// A deterministic preview Event Type. Only [EventType.label] is consumed
  /// by [PlannerEventColorPreview], so a synthesized type is sufficient.
  EventType get _previewEventType => EventType(
    id: 'event-block-color-preview',
    stableKey: 'event-block-color-preview',
    label: eventTypeLabel,
    icon: EventTypeIcon.calendar,
    colorValue: initialColor.toARGB32(),
    isSystem: false,
    isArchived: false,
    reportRequiredDefault: false,
    defaultDurationMinutes: 60,
    position: 0,
    mappingVersion: 1,
    indicatorKeys: const <String>{},
  );

  bool _isUnavailable(int argb) => peerAccentColors.any(
    (peer) => Vs11ColorSystem.sameOpaqueRgb(peer, argb),
  );

  bool _isSelectable(int argb) =>
      Vs11ColorSystem.sameOpaqueRgb(argb, initialColor.toARGB32()) ||
      !_isUnavailable(argb);

  Iterable<RecommendedEventColor> get _visibleRecommendedColors sync* {
    final currentArgb = initialColor.toARGB32();
    if (!Vs11ColorSystem.isCanonical(currentArgb)) {
      yield RecommendedEventColor(name: 'Current custom color', argb: currentArgb);
    }
    for (final color in RecommendedEventColorPalette.colors) {
      if (_isSelectable(color.argb)) {
        yield color;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Event Block Color',
          key: const Key('event-block-color-title'),
          style: InternalScreen.sectionHeading,
        ),
        const SizedBox(height: 8),
        PlannerEventColorPreview(
          key: const Key('event-block-color-preview'),
          eventType: _previewEventType,
          preference: _previewPreference,
        ),
        const SizedBox(height: 12),
        Text(
          'Recommended Colors',
          key: const Key('recommended-colors-title'),
          style: InternalScreen.sectionHeading,
        ),
        const SizedBox(height: 8),
        // The single inline Recommended Colors group. The recommended modal
        // is retired from this screen; Settings -> Colors keeps the modal.
        Wrap(
          key: const Key('recommended-colors-inline'),
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.start,
          children: <Widget>[
            for (final color in _visibleRecommendedColors)
              _RecommendedColorSwatch(
                key: Key(
                  'recommended-event-color-'
                  '${color.name}',
                ),
                color: color,
                selected: Vs11ColorSystem.sameOpaqueRgb(
                  color.argb,
                  initialColor.toARGB32(),
                ),
                onTap: () => onColorChanged(Color(color.argb)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Compact inline secondary actions (no boxes).  48 dp hit targets
        // preserved while the visible footprint stays small.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: <Widget>[
            _InlineColorAction(
              key: const Key('event-color-palette-action'),
              icon: Icons.palette_outlined,
              label: 'Color Palette',
              onPressed: () => _openPalette(context),
            ),
            _InlineColorAction(
              key: const Key('event-color-custom-hex-action'),
              icon: Icons.hexagon_outlined,
              label: 'Custom Hex',
              onPressed: () => _openCustomHex(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openPalette(BuildContext context) async {
    final chosen = await showPlannerEventColorPicker(
      context: context,
      eventTypeLabel: eventTypeLabel,
      role: EventColorRole.accent,
      initialColor: initialColor,
      otherColor: Theme.of(context).scaffoldBackgroundColor,
      onChanged: onColorChanged,
    );
    if (chosen != null) {
      final nearPeer = peerAccentColors.any(
        (peer) =>
            !Vs11ColorSystem.sameOpaqueRgb(peer, chosen.toARGB32()) &&
            EventColorMath.isNearDuplicate(
              Vs11ColorSystem.opaqueRgb(peer),
              Vs11ColorSystem.opaqueRgb(chosen.toARGB32()),
            ),
      );
      onColorChanged(chosen);
      if (nearPeer && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This custom color is close to another active Event Type color. It can still be used.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openCustomHex(BuildContext context) async {
    final chosen = await showCustomHexColorDialog(
      context,
      initialColor: initialColor,
    );
    if (chosen != null) {
      onColorChanged(chosen);
    }
  }
}

/// A single circular Recommended Colors swatch with selected-state UI,
/// shared by the inline Edit Event Type palette and the recommended modal.
final class _RecommendedColorSwatch extends StatelessWidget {
  const _RecommendedColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final RecommendedEventColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = '${color.name} ${color.hex}';
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: SizedBox(
        width: 48,
        height: 48,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(color.argb),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outline,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Center(
                      child: Icon(
                        Icons.check,
                        size: 20,
                        color: _checkForeground(color.argb),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Color _checkForeground(int swatchArgb) {
    const dark = 0xFF1A1C1F;
    const light = 0xFFFFFFFF;
    return Color(
      EventColorMath.contrastRatio(dark, swatchArgb) >=
              EventColorMath.contrastRatio(light, swatchArgb)
          ? dark
          : light,
    );
  }
}

/// A compact inline secondary color action: transparent, no outline, ~34 dp
/// visual height inside a 48 dp hit area.
final class _InlineColorAction extends StatelessWidget {
  const _InlineColorAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Center(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            // Default padded tap target keeps a real 48 dp hit area; the
            // transparent button surface keeps the visible footprint small.
            visualDensity: VisualDensity.compact,
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

final class _RecommendedEventColorsDialog extends StatefulWidget {
  const _RecommendedEventColorsDialog({
    required this.initialColor,
    required this.peerAccentColors,
  });

  final Color initialColor;
  final List<int> peerAccentColors;

  @override
  State<_RecommendedEventColorsDialog> createState() =>
      _RecommendedEventColorsDialogState();
}

final class _RecommendedEventColorsDialogState
    extends State<_RecommendedEventColorsDialog> {
  late int? _selected = _initialSelection();

  int? _initialSelection() {
    for (
      var index = 0;
      index < RecommendedEventColorPalette.colors.length;
      index += 1
    ) {
      if (Vs11ColorSystem.sameOpaqueRgb(
        RecommendedEventColorPalette.colors[index].argb,
        widget.initialColor.toARGB32(),
      )) {
        return index;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('recommended-event-colors-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 347),
        child: SizedBox(
          width: 347,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      'Next Transfer Recommended Colors',
                      key: const Key('recommended-event-colors-title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        height: 24 / 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 10.0;
                         const swatch = 48.0;
                        final columns =
                            ((constraints.maxWidth + gap) / (swatch + gap))
                                .floor();
                        final effectiveColumns = columns.clamp(3, 5);
                        final rows =
                            (RecommendedEventColorPalette.colors.length /
                                    effectiveColumns)
                                .ceil();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (var row = 0; row < rows; row += 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: gap),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    for (
                                      var column = 0;
                                      column < effectiveColumns;
                                      column += 1
                                    ) ...<Widget>[
                                      if (column > 0)
                                        const SizedBox(width: gap),
                                      _buildSwatch(
                                        row * effectiveColumns + column,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          key: const Key('recommended-event-colors-cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('recommended-event-colors-apply'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _selected == null
                              ? null
                              : () => Navigator.of(context).pop(
                                  Color(
                                    RecommendedEventColorPalette
                                        .colors[_selected!]
                                        .argb,
                                  ),
                                ),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwatch(int index) {
    if (index >= RecommendedEventColorPalette.colors.length) {
      return const SizedBox(width: 48, height: 48);
    }
    final color = RecommendedEventColorPalette.colors[index];
    final unavailable = widget.peerAccentColors.any(
      (peer) =>
          !Vs11ColorSystem.sameOpaqueRgb(peer, widget.initialColor.toARGB32()) &&
          Vs11ColorSystem.sameOpaqueRgb(peer, color.argb),
    );
    if (unavailable) {
      return const SizedBox(width: 48, height: 48);
    }
    return _RecommendedColorSwatch(
      key: Key('recommended-event-color-${color.name}'),
      color: color,
      selected: _selected == index,
      onTap: () => setState(() => _selected = index),
    );
  }
}

final class _CustomHexColorDialog extends StatefulWidget {
  const _CustomHexColorDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_CustomHexColorDialog> createState() => _CustomHexColorDialogState();
}

final class _CustomHexColorDialogState extends State<_CustomHexColorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: EventColorMath.formatHex(widget.initialColor.toARGB32()).substring(1),
  );
  int? _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = EventColorMath.parseHex(_controller.text);
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _parsed = EventColorMath.parseHex(_controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final invalid = parsed == null && _controller.text.trim().isNotEmpty;
    final poorContrast =
        parsed != null && EventColorMath.hasPoorContrastOnDarkSurface(parsed);
    final tooBright =
        parsed != null && EventColorMath.isExcessivelyBright(parsed);
    return Dialog(
      key: const Key('custom-hex-color-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 347),
        child: SizedBox(
          width: 347,
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Text(
                      'Custom Hex Color',
                      key: const Key('custom-hex-title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        height: 24 / 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label:
                        'Live preview ${EventColorMath.formatHex(parsed ?? 0)}',
                    child: Center(
                      child: Container(
                        key: const Key('custom-hex-preview'),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: parsed == null
                              ? Colors.transparent
                              : Color(parsed),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: parsed == null
                                ? Colors.white24
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      key: const Key('custom-hex-input'),
                      controller: _controller,
                      decoration: InputDecoration(
                        prefixText: '# ',
                        labelText: 'Hex color',
                        hintText: 'A1B2C3',
                        errorText: invalid
                            ? 'Enter exactly 6 hex digits (for example A1B2C3).'
                            : null,
                        helperText: parsed == null
                            ? 'A six-digit RGB value'
                            : null,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        letterSpacing: 2,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                  if (parsed != null) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        EventColorMath.formatHex(parsed),
                        key: const Key('custom-hex-normalized'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (poorContrast)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: Text(
                          'This color may be hard to see on the dark '
                          'interface.',
                          key: const Key('custom-hex-contrast-warning'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    if (tooBright)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Text(
                          'This color is very bright on the dark interface.',
                          key: const Key('custom-hex-brightness-warning'),
                          style: TextStyle(
                            color: AppTheme.warning,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          key: const Key('custom-hex-cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          key: const Key('custom-hex-apply'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: parsed == null
                              ? null
                              : () => Navigator.of(context).pop(Color(parsed)),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
