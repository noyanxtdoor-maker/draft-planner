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

  /// The approved filter silhouette: a broad rounded mouth, strong diagonal
  /// shoulders, and the asymmetric lower stem with its angled lower-right
  /// exit. Keeping the path here (instead of using Material's filter glyph)
  /// makes the proportions stable at the compact top-bar size.
  static Path pathFor(Size size) {
    final scaleX = size.width / 28;
    final scaleY = size.height / 28;
    double x(double value) => value * scaleX;
    double y(double value) => value * scaleY;
    return Path()
      ..moveTo(x(4.2), y(4.5))
      ..cubicTo(x(3.3), y(4.5), x(3.0), y(5.1), x(3.7), y(5.9))
      ..lineTo(x(11.7), y(14.3))
      ..lineTo(x(11.7), y(22.9))
      ..lineTo(x(16.8), y(20.0))
      ..lineTo(x(16.8), y(14.3))
      ..lineTo(x(24.3), y(5.9))
      ..cubicTo(x(25.0), y(5.1), x(24.7), y(4.5), x(23.8), y(4.5))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(pathFor(size), paint);
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
