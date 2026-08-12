import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/planner/domain/event_color_math.dart';
import 'package:rmplanner/features/planner/domain/recommended_event_colors.dart';
import 'package:rmplanner/features/settings/presentation/event_color_picker_dialog.dart';

/// Opens the Next Transfer Recommended Colors modal (exactly 15 muted
/// swatches in a responsive grid).  Returns the selected color on Apply, or
/// null when the user cancels.  Nothing is persisted here; the caller owns
/// its Save semantics.
Future<Color?> showRecommendedEventColorsDialog(
  BuildContext context, {
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _RecommendedEventColorsDialog(initialColor: initialColor),
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
/// the unified tappable Color row instead (see [EventTypeColorPanel]).
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
///   Color                                      ●
///           🎨 Color Palette      ⬡ Custom Hex
///
/// - the whole Color row (label + empty middle + current swatch) is tappable
///   and opens the Next Transfer Recommended Colors dialog;
/// - [Color Palette] and [Custom Hex] are compact inline icon/text actions
///   with no outline or card shape;
/// - there is no standalone sparkle control in this section.
///
/// Every action reports through [onColorChanged] as a draft; the caller
/// persists only when its own Save contract runs.
final class EventTypeColorPanel extends StatelessWidget {
  const EventTypeColorPanel({
    required this.eventTypeLabel,
    required this.initialColor,
    required this.onColorChanged,
    super.key,
  });

  final String eventTypeLabel;
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  static const String rowLabel = 'Choose from Next Transfer Recommended Colors';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The tappable Color row.  Transparent/open on the screen background;
        // a minimum 48 dp hit height is preserved by the InkWell's padding.
        Semantics(
          button: true,
          label: rowLabel,
          child: InkWell(
            key: const Key('event-type-color-row'),
            onTap: () => _openRecommended(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              // 12 + 12 + 24 (swatch/text row) = a 48 dp hit height for the
              // whole tappable row while the open section stays transparent.
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Color',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Semantics(
                    label:
                        'Current color '
                        '#${(initialColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                    child: CircleAvatar(
                      key: const Key('event-type-color-swatch'),
                      radius: 12,
                      backgroundColor: initialColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      onColorChanged(chosen);
    }
  }

  Future<void> _openRecommended(BuildContext context) async {
    final chosen = await showRecommendedEventColorsDialog(
      context,
      initialColor: initialColor,
    );
    if (chosen != null) {
      onColorChanged(chosen);
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
            foregroundColor: AppTheme.rose,
          ),
        ),
      ),
    );
  }
}

final class _RecommendedEventColorsDialog extends StatefulWidget {
  const _RecommendedEventColorsDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_RecommendedEventColorsDialog> createState() =>
      _RecommendedEventColorsDialogState();
}

final class _RecommendedEventColorsDialogState
    extends State<_RecommendedEventColorsDialog> {
  late int? _selected = _initialSelection();

  int? _initialSelection() {
    var best = 0;
    var bestDistance = double.infinity;
    for (
      var index = 0;
      index < RecommendedEventColorPalette.colors.length;
      index += 1
    ) {
      final distance = EventColorMath.okLabDistance(
        RecommendedEventColorPalette.colors[index].argb,
        widget.initialColor.toARGB32(),
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = index;
      }
    }
    // Raw OKLab distances across sRGB peak around 1.5, so this bound is
    // deliberately generous: it always preselects the nearest swatch.  The
    // swatch never auto-applies; Apply alone persists through the caller.
    return bestDistance < 12 ? best : null;
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
                        const swatch = 44.0;
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
      return const SizedBox(width: 44, height: 44);
    }
    final color = RecommendedEventColorPalette.colors[index];
    final selected = _selected == index;
    final semanticsLabel = '${color.name} ${color.hex}';
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: InkWell(
        key: Key('recommended-event-color-${color.name}'),
        onTap: () => setState(() => _selected = index),
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(color.argb),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: selected
              ? const Center(
                  child: Icon(Icons.check, size: 20, color: Colors.white),
                )
              : null,
        ),
      ),
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
