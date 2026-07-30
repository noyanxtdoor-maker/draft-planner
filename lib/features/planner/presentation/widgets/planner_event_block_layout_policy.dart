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
  static bool showTime(Density density) {
    return switch (density) {
      Density.veryShort => false,
      Density.short => true,
      Density.medium => true,
      Density.tall => true,
    };
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
    return interactive && density == Density.tall;
  }

  /// Minimum height that still admits a meaningful resize affordance.
  static const double minimumInteractiveHeight = 40;
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
/// Events still receive their approved black/dark stripe on the
/// leading edge, and Awaiting Report still receives its approved
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
    return hsl
        .withLightness(lightness)
        .withSaturation(saturation)
        .toColor();
  }

  /// Returns the border color used to outline the block.
  static Color borderColor(Color base) {
    return base.withValues(alpha: 0.95);
  }

  /// Returns the readable text color for the block surface.
  ///
  /// On a dark background, the block surface derived from
  /// [surfaceColor] is still in the mid-lightness range, so plain
  /// white text remains legible.
  static Color textColor(Color base) {
    final luminance = base.computeLuminance();
    if (luminance < 0.45) {
      return Colors.white;
    }
    return const Color(0xFF1B1B1F);
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
    required this.showStatusIcons,
    required this.showResizeHandle,
  });

  factory PlannerEventBlockContent.forHeight(double height,
      {required bool interactive}) {
    final density = PlannerEventBlockLayoutPolicy.classify(height);
    return PlannerEventBlockContent(
      density: density,
      titleMaxLines: PlannerEventBlockLayoutPolicy.titleMaxLines(density),
      showTime: PlannerEventBlockLayoutPolicy.showTime(density),
      showStatusIcons: PlannerEventBlockLayoutPolicy.showStatusIcons(density),
      showResizeHandle: PlannerEventBlockLayoutPolicy.showResizeHandle(
        density,
        interactive,
      ),
    );
  }

  final Density density;
  final int titleMaxLines;
  final bool showTime;
  final bool showStatusIcons;
  final bool showResizeHandle;
}