import 'package:flutter/material.dart';

/// Shared interaction treatment for Planner top-bar icon actions.
///
/// Icons rest without a background and receive the same soft, circular white
/// press feedback. The action callback and tooltip remain owned by the
/// [IconButton], so existing semantics and hit targets are unchanged.
final class PlannerTopBarIconButton extends StatelessWidget {
  const PlannerTopBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style:
          IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
            shape: const CircleBorder(),
          ).copyWith(
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.14),
            ),
          ),
      icon: icon,
    );
  }
}

final class PlannerFilterIcon extends StatelessWidget {
  const PlannerFilterIcon({this.color = Colors.white, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(28),
      painter: PlannerFunnelIconPainter(color),
    );
  }
}

final class PlannerSelectionIcon extends StatelessWidget {
  const PlannerSelectionIcon({this.color = Colors.white, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(28),
      painter: PlannerSelectionIconPainter(color),
    );
  }
}

final class PlannerFunnelIconPainter extends CustomPainter {
  const PlannerFunnelIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(3, 4)
      ..lineTo(25, 4)
      ..lineTo(16, 13)
      ..lineTo(16, 23)
      ..lineTo(12, 20);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PlannerFunnelIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

final class PlannerSelectionIconPainter extends CustomPainter {
  const PlannerSelectionIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final square = RRect.fromRectAndRadius(
      const Rect.fromLTWH(7, 4, 17, 17),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(square, paint);
    final offset = Path()
      ..moveTo(3, 8)
      ..lineTo(3, 24)
      ..lineTo(18, 24);
    canvas.drawPath(offset, paint);
    final check = Path()
      ..moveTo(11, 12)
      ..lineTo(14, 15)
      ..lineTo(20, 8);
    canvas.drawPath(check, paint);
  }

  @override
  bool shouldRepaint(covariant PlannerSelectionIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
