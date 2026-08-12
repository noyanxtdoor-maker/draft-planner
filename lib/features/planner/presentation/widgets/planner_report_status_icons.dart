import 'package:flutter/material.dart';

import 'package:rmplanner/features/planner/presentation/widgets/planner_event_report_status.dart';

/// Canonical circular report-status icon component matching the
/// authoritative icon sheet.
///
/// The sheet defines four circular shapes:
///
///   [!] Unreported           → amber/yellow FILLED disc + dark exclamation
///   [−] Did Not Attempt      → neutral gray ring + minus bar
///   [／] Missed - Attempted  → muted rose FILLED disc + dark diagonal slash
///   [✓] Completed            → muted green FILLED disc + dark check
///
/// One reusable, independently selectable and scalable component renders
/// all four; only the [kind] changes the disc, glyph, and semantics. The
/// [style] selects the visual treatment:
///
///   * [PlannerReportStatusIconStyle.canonical] — the sheet-accurate
///     display treatment used by Planner Event blocks (gray ring for
///     Did Not Attempt, filled discs for the other three);
///   * [PlannerReportStatusIconStyle.selected] — the strong preview-control
///     selection used by the Event detail status row: a filled disc for
///     every status (including a filled gray disc for Did Not Attempt) so
///     selection is never communicated by color alone;
///   * [PlannerReportStatusIconStyle.unselected] — the neutral preview
///     control: outline ring + subdued glyph on a transparent surface.
///
/// The component is a [CustomPaint], so it stays sharp at every density,
/// scales freely through [size], and carries no raster or emoji content.
class PlannerReportStatusIcon extends StatelessWidget {
  const PlannerReportStatusIcon({
    required this.kind,
    this.size = 22,
    this.style = PlannerReportStatusIconStyle.canonical,
    this.semanticLabel,
    this.isContactEvent = false,
    super.key,
  });

  /// The report status this icon represents. Backup and linked-Task
  /// affordances are not report statuses and never use this component.
  final PlannerReportStatusKind kind;

  /// Visual diameter in logical pixels. Event blocks use ~22 dp (16 dp in
  /// very-short blocks); preview controls use ~40–44 dp.
  final double size;

  /// Visual treatment (canonical badge vs. selected/unselected control).
  final PlannerReportStatusIconStyle style;

  /// Optional explicit semantics label. Defaults to the status label.
  final String? semanticLabel;

  /// Contact Events use the richer 'Missed - Attempted' label for the
  /// partial outcome; generic Events read 'Missed' (Planner Polish Delta 2).
  final bool isContactEvent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          semanticLabel ??
          PlannerEventReportStatus.labelFor(
            kind,
            isContactEvent: isContactEvent,
          ),
      image: true,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size.square(size),
          painter: _ReportStatusCirclePainter(
            kind: kind,
            style: style,
            strokeWidth: _strokeWidthFor(size),
          ),
        ),
      ),
    );
  }

  static double _strokeWidthFor(double size) => (size * 0.1).clamp(1.2, 3.2);
}

/// Visual treatment for [PlannerReportStatusIcon].
enum PlannerReportStatusIconStyle { canonical, selected, unselected }

/// Paints the circular disc/ring and the dark glyph for one status.
///
/// All geometry is derived from [size] so the icon scales linearly and
/// stays crisp at 14–44 dp. Glyphs are drawn as stroked paths (check,
/// diagonal slash, minus, exclamation) rather than font glyphs, matching
/// the sheet's clean line work without emoji or Material-icon coupling.
class _ReportStatusCirclePainter extends CustomPainter {
  const _ReportStatusCirclePainter({
    required this.kind,
    required this.style,
    required this.strokeWidth,
  });

  final PlannerReportStatusKind kind;
  final PlannerReportStatusIconStyle style;
  final double strokeWidth;

  /// Dark ink for glyphs on filled discs (matches the sheet's dark glyphs).
  static const Color _darkInk = Color(0xFF1A1B1E);

  bool get _filledDisc =>
      style == PlannerReportStatusIconStyle.selected ||
      (style == PlannerReportStatusIconStyle.canonical &&
          kind != PlannerReportStatusKind.didNotAttempt);

  Color get _discColor => PlannerEventReportStatus.colorFor(kind);

  Color get _glyphColor {
    if (style == PlannerReportStatusIconStyle.unselected) {
      return Colors.white54;
    }
    return _filledDisc ? _darkInk : _discColor;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (style == PlannerReportStatusIconStyle.unselected) {
      // Neutral outline ring + subdued glyph on a transparent surface.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white38;
      canvas.drawCircle(center, radius - strokeWidth, ring);
      _paintGlyph(canvas, center, radius, _glyphColor);
      return;
    }

    if (_filledDisc) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = _discColor;
      canvas.drawCircle(center, radius, fill);
      // Crisp 1 px separation between the disc edge and the glyphs.
      _paintGlyph(canvas, center, radius * 0.82, _glyphColor);
      return;
    }

    // Canonical Did Not Attempt: neutral gray ring (double-line echo of the
    // sheet) with a matching minus bar, no fill.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = _discColor;
    canvas.drawCircle(center, radius - strokeWidth, ring);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.55
      ..color = _discColor.withValues(alpha: 0.65);
    canvas.drawCircle(center, radius - strokeWidth * 2.4, inner);
    _paintGlyph(canvas, center, radius * 0.82, _glyphColor);
  }

  void _paintGlyph(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth * 1.15
      ..color = color;
    switch (kind) {
      case PlannerReportStatusKind.unreported:
        _paintExclamation(canvas, center, radius, paint);
      case PlannerReportStatusKind.didNotAttempt:
        _paintMinus(canvas, center, radius, paint);
      case PlannerReportStatusKind.missedAttempted:
        _paintSlash(canvas, center, radius, paint);
      case PlannerReportStatusKind.completed:
        _paintCheck(canvas, center, radius, paint);
      case PlannerReportStatusKind.backup:
      case PlannerReportStatusKind.linked:
        // Non-report affordances never render through this component.
        break;
    }
  }

  void _paintExclamation(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = paint.strokeWidth
      ..color = paint.color;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.42),
      Offset(center.dx, center.dy + radius * 0.12),
      bar,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + radius * 0.5),
      radius * 0.16,
      Paint()..color = paint.color,
    );
  }

  void _paintMinus(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - radius * 0.52, center.dy),
      Offset(center.dx + radius * 0.52, center.dy),
      paint,
    );
  }

  void _paintSlash(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawLine(
      Offset(center.dx - radius * 0.48, center.dy + radius * 0.48),
      Offset(center.dx + radius * 0.48, center.dy - radius * 0.48),
      paint,
    );
  }

  void _paintCheck(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx - radius * 0.52, center.dy + radius * 0.04)
      ..lineTo(center.dx - radius * 0.1, center.dy + radius * 0.42)
      ..lineTo(center.dx + radius * 0.52, center.dy - radius * 0.38);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReportStatusCirclePainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.style != style ||
      oldDelegate.strokeWidth != strokeWidth;
}
