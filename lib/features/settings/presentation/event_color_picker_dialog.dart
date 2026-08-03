import 'package:flutter/material.dart';

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
    return Dialog(
      key: const Key('planner-event-color-picker'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      'Choose Color',
                      key: const Key('planner-event-color-picker-title'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label:
                        '${widget.eventTypeLabel} ${widget.role.name} color, '
                        '${colorHex(_color)}',
                    child: Center(
                      child: Container(
                        key: const Key('planner-event-color-current-preview'),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final squareSize = (constraints.maxWidth - 42).clamp(
                        1.0,
                        320.0,
                      );
                      return SizedBox(
                        height: squareSize,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SizedBox(
                              width: squareSize,
                              child: _SaturationValuePicker(
                                key: const Key('planner-event-color-sv-picker'),
                                hsv: _selected,
                                size: squareSize,
                                onChanged: (saturation, value) {
                                  setState(() {
                                    _selected = _selected
                                        .withSaturation(saturation)
                                        .withValue(value);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 34,
                              child: _HuePicker(
                                key: const Key(
                                  'planner-event-color-hue-picker',
                                ),
                                hue: _selected.hue,
                                onChanged: (hue) {
                                  setState(() {
                                    _selected = _selected.withHue(hue);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          TextButton(
                            key: const Key('planner-event-color-cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            key: const Key('planner-event-color-save'),
                            onPressed: () => Navigator.of(context).pop(_color),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
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
    const handleSize = 18.0;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          width: size,
          height: size,
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
        width: 34,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final handleTop = (hue / 360 * (constraints.maxHeight - 18)).clamp(
              0.0,
              constraints.maxHeight - 18,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: hues,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: handleTop,
                  left: 1,
                  child: Container(
                    width: 32,
                    height: 18,
                    decoration: BoxDecoration(
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
    final height = context.size?.height ?? 1;
    onChanged((position.dy / height * 360).clamp(0.0, 360.0));
  }
}

String colorHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
