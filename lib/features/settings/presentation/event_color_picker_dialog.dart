import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

enum EventColorRole { accent, surface }

Future<Color?> showPlannerEventColorPicker({
  required BuildContext context,
  required String eventTypeLabel,
  required EventColorRole role,
  required Color initialColor,
  required Color otherColor,
}) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _EventColorPickerDialog(
      eventTypeLabel: eventTypeLabel,
      role: role,
      initialColor: initialColor,
      otherColor: otherColor,
    ),
  );
}

final class _EventColorPickerDialog extends StatefulWidget {
  const _EventColorPickerDialog({
    required this.eventTypeLabel,
    required this.role,
    required this.initialColor,
    required this.otherColor,
  });

  final String eventTypeLabel;
  final EventColorRole role;
  final Color initialColor;
  final Color otherColor;

  @override
  State<_EventColorPickerDialog> createState() =>
      _EventColorPickerDialogState();
}

final class _EventColorPickerDialogState
    extends State<_EventColorPickerDialog> {
  late HSVColor _selected;

  @override
  void initState() {
    super.initState();
    _selected = HSVColor.fromColor(widget.initialColor);
  }

  Color get _color => _selected.toColor();

  @override
  Widget build(BuildContext context) {
    final titleRole = widget.role == EventColorRole.accent
        ? 'Accent'
        : 'Surface';
    final textColor = PlannerEventBlockColorPolicy.textColor(_color);
    final accent = widget.role == EventColorRole.accent
        ? _color
        : widget.otherColor;
    final surface = widget.role == EventColorRole.surface
        ? _color
        : widget.otherColor;
    final similarityWarning =
        PlannerEventBlockColorPolicy.contrastRatio(accent, surface) < 1.35;

    return Dialog(
      key: const Key('planner-event-color-picker'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Choose Color',
                  key: const Key('planner-event-color-picker-title'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('$titleRole color for ${widget.eventTypeLabel}'),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Current color ${colorHex(_color)}',
                  child: Container(
                    key: const Key('planner-event-color-current-preview'),
                    height: 40,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      colorHex(_color),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math.min(constraints.maxWidth, 240.0);
                    return Align(
                      alignment: Alignment.center,
                      child: _SaturationValuePicker(
                        key: const Key('planner-event-color-sv-picker'),
                        hsv: _selected,
                        size: size,
                        onChanged: (saturation, value) {
                          setState(() {
                            _selected = _selected
                                .withSaturation(saturation)
                                .withValue(value);
                          });
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _HuePicker(
                  key: const Key('planner-event-color-hue-picker'),
                  hue: _selected.hue,
                  onChanged: (hue) {
                    setState(() {
                      _selected = _selected.withHue(hue);
                    });
                  },
                ),
                if (similarityWarning) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('planner-event-color-contrast-warning'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Accent and background are very similar. The Event '
                      'category may be harder to recognize.',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      key: const Key('planner-event-color-cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('planner-event-color-save'),
                      onPressed: () => Navigator.of(context).pop(_color),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _SaturationValuePicker extends StatelessWidget {
  const _SaturationValuePicker({
    required this.hsv,
    required this.size,
    required this.onChanged,
    super.key,
  });

  final HSVColor hsv;
  final double size;
  final void Function(double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    final handleSize = 18.0;
    final left = (hsv.saturation * (size - handleSize)).clamp(
      0.0,
      size - handleSize,
    );
    final top = ((1 - hsv.value) * (size - handleSize)).clamp(
      0.0,
      size - handleSize,
    );
    return GestureDetector(
      key: const Key('planner-event-color-sv-gesture'),
      onPanDown: (details) => _update(details.localPosition),
      onPanUpdate: (details) => _update(details.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.white,
                      HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Colors.black],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              Positioned(
                left: left,
                top: top,
                child: Container(
                  width: handleSize,
                  height: handleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black54, blurRadius: 2),
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

  void _update(Offset position) {
    onChanged(
      (position.dx / size).clamp(0.0, 1.0),
      (1 - position.dy / size).clamp(0.0, 1.0),
    );
  }
}

final class _HuePicker extends StatelessWidget {
  const _HuePicker({required this.hue, required this.onChanged, super.key});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final hues = <Color>[
      for (var index = 0; index <= 12; index++)
        HSVColor.fromAHSV(1, index * 30.0 % 360, 1, 1).toColor(),
    ];
    return GestureDetector(
      onPanDown: (details) => _update(details.localPosition, context),
      onPanUpdate: (details) => _update(details.localPosition, context),
      child: SizedBox(
        key: const Key('planner-event-color-hue-gesture'),
        height: 28,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final handleLeft = (hue / 360 * (constraints.maxWidth - 18)).clamp(
              0.0,
              constraints.maxWidth - 18,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(colors: hues),
                    ),
                  ),
                ),
                Positioned(
                  left: handleLeft,
                  top: 3,
                  child: Container(
                    width: 18,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(color: Colors.black54, blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _update(Offset position, BuildContext context) {
    final width = context.size?.width ?? 1;
    onChanged((position.dx / width * 360).clamp(0.0, 360.0));
  }
}

String colorHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
