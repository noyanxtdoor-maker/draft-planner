import 'package:flutter/material.dart';

/// Adaptive layout strategy for Calendar Event blocks on the Day timeline.
///
/// The Planner Day view renders blocks at heights derived from minute
/// spans and the zoomed hour-height. A block can be as small as
/// ~15 minutes (and below the visible line-height) or as tall as several
/// hours. The same widget tree needs to render at every height without
/// a RenderFlex overflow and without leaving the user looking at a
/// Flutter debug stripe.
///
/// The policy in [PlannerEventBlockLayoutPolicy] chooses how much
/// information to reveal based on the available height. This mirrors
/// the approved thresholds in the temporary patch scope:
///
///   * VERY SHORT  (≤ 24 px)        — title with ellipsis only.
///   * SHORT       (> 24 ≤ 44 px)   — title; time only if it fits.
///   * MEDIUM      (> 44 ≤ 70 px)   — title; time; one compact status.
///   * TALL        (> 70 px)        — title; time; status; resize handle.
abstract final class PlannerEventBlockLayoutPolicy {
  /// Compact silhouette constants for the rendered Event block. Keeping
  /// these in the layout policy makes the reference shape testable without
  /// coupling tests to Flutter's internal Material shape objects.
  static const double eventBorderRadius = 4;
  static const double eventAccentWidth = 4;
  static const double backupEventAccentWidth = 7;
  static const Color backupStripeDark = Color(0xFF1B1C1D);
  static const double backupStripeSpacing = 5;
  static const double backupStripeWidth = 2.2;
  static const double contentHorizontalPadding = 8;
  static const double recurrenceRightInset = 8;
  static const double recurrenceIconSize = 18;
  static const double recurringContentRightPadding =
      recurrenceRightInset + recurrenceIconSize + 4;

  static double titleFontSize(Density density) {
    return switch (density) {
      Density.veryShort ||
      Density.short ||
      Density.medium ||
      Density.tall => 14,
    };
  }

  static double timeFontSize(Density density) {
    return switch (density) {
      Density.veryShort ||
      Density.short ||
      Density.medium ||
      Density.tall => 13,
    };
  }

  static double recurrenceIconSizeFor(Density density) {
    return density == Density.veryShort ? 14 : recurrenceIconSize;
  }

  /// Approximate line height for title text at the block's font size.
  static const double titleLineHeight = 18;

  /// Approximate line height for the time text.
  static const double timeLineHeight = 14;

  /// Approximate vertical spacing between title and time rows.
  static const double rowGap = 4;

  /// Inner vertical padding (top + bottom) reserved inside the block.
  static const double verticalPadding = 11;

  /// Threshold for the [Density.veryShort] regime.
  static const double veryShortThreshold = 24;

  /// Threshold for the [Density.short] regime.
  static const double shortThreshold = 44;

  /// Threshold for the [Density.medium] regime.
  static const double mediumThreshold = 70;

  /// Classify the visible density for a given block height in pixels.
  static Density classify(double height) {
    if (height <= veryShortThreshold) {
      return Density.veryShort;
    }
    if (height <= shortThreshold) {
      return Density.short;
    }
    if (height <= mediumThreshold) {
      return Density.medium;
    }
    return Density.tall;
  }

  /// Maximum number of title text lines the policy exposes at [density].
  static int titleMaxLines(Density density) {
    return switch (density) {
      Density.veryShort => 1,
      Density.short => 1,
      Density.medium => 1,
      Density.tall => 2,
    };
  }

  /// Whether the time row should render at [density].
  ///
  /// The `short` regime keeps the time in the inline title (see
  /// [showTimeInline]) rather than as a separate row, because the
  /// remaining height after title + padding would not reliably
  /// accommodate the time row without exceeding the available block
  /// height (which would surface as a 1-pixel RenderFlex overflow on
  /// ~32 px blocks, e.g. after a minimum-duration resize).
  static bool showTime(Density density) {
    return switch (density) {
      Density.veryShort => false,
      Density.short => false,
      Density.medium => true,
      Density.tall => true,
    };
  }

  /// Whether the time range should be inlined into the title text
  /// for blocks that are too short to host a second text line.
  ///
  /// Owner-correction: short Events (15- and 30-minute) must still
  /// show useful schedule information. The block renders the title
  /// and the time range together on a single line, separated by a
  /// thin gap, with ellipsis applied to the combined text. This
  /// prevents the RenderFlex overflow that would occur if we tried
  /// to host a separate time row inside these compact blocks.
  static bool showTimeInline(Density density) {
    return density == Density.veryShort || density == Density.short;
  }

  /// Whether the compact status icon row should render at [density].
  static bool showStatusIcons(Density density) {
    return switch (density) {
      Density.veryShort => false,
      Density.short => false,
      Density.medium => true,
      Density.tall => true,
    };
  }

  /// Whether the resize handle should render at [density].
  static bool showResizeHandle(Density density, bool interactive) {
    // Resize remains discoverable through the invisible edge hit zones below;
    // the approved timeline surface does not render a visible grip.
    return false;
  }

  /// Minimum height that still admits a meaningful resize affordance.
  static const double minimumInteractiveHeight = 40;

  /// Height of the invisible resize hit area at the bottom of every
  /// interactive Event block. Clamped to the available height so very
  /// short blocks never expose a hit area larger than the block itself.
  ///
  /// Sized to the approved 10–12 logical-pixel edge zone so the surrounding
  /// Event body remains the primary tap and long-press move target.
  static const double resizeHitAreaHeight = 12;

  /// A compact top-edge target that leaves the Event body available for its
  /// existing tap and long-press move behavior.
  static const double topResizeHitAreaHeight = 12;

  /// Top and bottom targets remain distinct once a block is tall enough to
  /// expose both edges without making short blocks gesture-ambiguous.
  static const double topResizeMinimumHeight = 76;
}

/// Applies the approved diagonal backup treatment without changing the
/// Event Type surface or accent. The dark stripe is deliberately near-black,
/// while the adjacent stripe uses the original Event Type accent.
final class PlannerBackupStripeBackground extends StatelessWidget {
  const PlannerBackupStripeBackground({
    required this.accent,
    required this.child,
    super.key,
  });

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _PlannerBackupStripePainter(accent: accent),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

final class _PlannerBackupStripePainter extends CustomPainter {
  const _PlannerBackupStripePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = size.width + size.height;
    final darkPaint = Paint()
      ..color = PlannerEventBlockLayoutPolicy.backupStripeDark
      ..strokeWidth = PlannerEventBlockLayoutPolicy.backupStripeWidth
      ..style = PaintingStyle.stroke;
    final accentPaint = Paint()
      ..color = accent
      ..strokeWidth = PlannerEventBlockLayoutPolicy.backupStripeWidth
      ..style = PaintingStyle.stroke;
    for (
      var offset = -size.height;
      offset <= extent;
      offset += PlannerEventBlockLayoutPolicy.backupStripeSpacing
    ) {
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        darkPaint,
      );
      canvas.drawLine(
        Offset(
          offset + PlannerEventBlockLayoutPolicy.backupStripeWidth + 1,
          size.height,
        ),
        Offset(
          offset +
              size.height +
              PlannerEventBlockLayoutPolicy.backupStripeWidth +
              1,
          0,
        ),
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlannerBackupStripePainter oldDelegate) =>
      oldDelegate.accent != accent;
}

enum Density { veryShort, short, medium, tall }

/// Color policy for the fully-opaque Calendar Event block surface.
///
/// The Planner Day view must fully cover the timeline grid lines
/// beneath the Event. We derive an opaque surface color from the
/// Event Type's base color using the HSL color space so the
/// resulting block stays legible against the dark background
/// regardless of which base color the user picked.
///
/// The policy intentionally avoids low-alpha backgrounds. Backup
/// Backup Events receive their approved grayscale surface and neutral
/// leading strip, and Unreported still receives its approved
/// indicator — those status overlays do not reduce the opacity of
/// the block body itself.
abstract final class PlannerEventBlockColorPolicy {
  /// Returns the fully-opaque surface color derived from [base].
  ///
  /// The lightening is a deterministic shift in HSL space that keeps
  /// saturation high and lifts lightness so dark Event Type colors
  /// remain readable on the dark Planner background.
  static Color surfaceColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    final lightness = (hsl.lightness * 0.6 + 0.32).clamp(0.0, 0.85);
    final saturation = (hsl.saturation * 0.85 + 0.1).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).withSaturation(saturation).toColor();
  }

  /// Returns the border color used to outline the block.
  static Color borderColor(Color base) {
    return base.withValues(alpha: 0.95);
  }

  /// Returns the safer neutral text color for a fully opaque block surface.
  ///
  /// Both candidates are measured rather than selected from a lightness
  /// threshold, so custom bright surfaces switch to dark text without
  /// changing the user's selected colors.
  static Color textColor(Color surface) {
    const darkText = Color(0xFF1B1B1F);
    const lightText = Colors.white;
    final lightContrast = contrastRatio(lightText, surface);
    final darkContrast = contrastRatio(darkText, surface);
    return lightContrast >= darkContrast ? lightText : darkText;
  }

  /// WCAG-style contrast ratio for two opaque colors.
  static double contrastRatio(Color foreground, Color background) {
    final foregroundLuminance = foreground.computeLuminance();
    final backgroundLuminance = background.computeLuminance();
    final lighter = foregroundLuminance > backgroundLuminance
        ? foregroundLuminance
        : backgroundLuminance;
    final darker = foregroundLuminance > backgroundLuminance
        ? backgroundLuminance
        : foregroundLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }
}

/// Adaptive visible-content descriptor for a Calendar Event block.
///
/// The descriptor is computed once per layout pass from the available
/// pixel height. It decides what the block renders so that the
/// [Column] never overflows its parent.
final class PlannerEventBlockContent {
  const PlannerEventBlockContent({
    required this.density,
    required this.titleMaxLines,
    required this.showTime,
    required this.showTimeInline,
    this.showRecurrence = true,
    required this.showStatusIcons,
    required this.showResizeHandle,
  });

  factory PlannerEventBlockContent.forHeight(
    double height, {
    required bool interactive,
  }) {
    final density = PlannerEventBlockLayoutPolicy.classify(height);
    return PlannerEventBlockContent(
      density: density,
      titleMaxLines: PlannerEventBlockLayoutPolicy.titleMaxLines(density),
      showTime: PlannerEventBlockLayoutPolicy.showTime(density),
      // At the actual minimum zoom a 15-minute block can be about 11 px
      // tall. Keep the approved inline schedule for compact blocks that can
      // still contain it, but collapse smaller blocks to title-only and hide
      // the recurrence affordance so it cannot bleed outside the block.
      showTimeInline:
          height >= 15 && PlannerEventBlockLayoutPolicy.showTimeInline(density),
      showRecurrence: height >= 18,
      // A medium block can be only a few pixels taller than the title/time
      // rows. Keep the status row until there is enough room for all three
      // rows and their measured gaps; compact blocks must never rely on
      // clipping to hide an overflow.
      showStatusIcons:
          density == Density.tall ||
          (density == Density.medium && height >= 58),
      showResizeHandle: PlannerEventBlockLayoutPolicy.showResizeHandle(
        density,
        interactive,
      ),
    );
  }

  final Density density;
  final int titleMaxLines;
  final bool showTime;
  final bool showTimeInline;
  final bool showRecurrence;
  final bool showStatusIcons;
  final bool showResizeHandle;
}
