import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/goals/domain/goal.dart';
import 'package:rmplanner/features/goals/domain/goal_icon_registry.dart';

/// Shared renderer for every production Goal surface.
///
/// The SVG internals are explicitly excluded from semantics so the widget
/// contributes one accessible image node, including when it falls back for a
/// null or unknown ID.
///
/// Light UI Final Polish (POLISH-03): the B3.3 dark plate AND the GI-01
/// 1.06x #181A1E halo are REMOVED.  Light mode renders the raw original
/// two-tone foreground SVG only — no plate, no halo, no artificial black
/// outline, `colorFilter` stays null. The owner prioritizes the clean
/// no-outline direction; text labels accompany Goal Icons so the icon is
/// never the sole information carrier.
///
/// R1 (owner 2026-08-16): Dark mode renders the SAME single asset through a
/// cyan-family-only compensation ([remapDarkCyan]) because the identical raw
/// art composites deeper/royal against the dark card (edge AA + simultaneous
/// contrast). Gold and every other color are untouched; Light mode is never
/// remapped; `colorFilter` stays null in both themes.
///
/// POLISH-06: [spiritual_temple] alone renders at an optical scale of 1.15x
/// via a renderer-only per-ID correction (default 1.0).  Its thin-stroke
/// artwork has the lowest ink density of the family and reads undersized
/// next to peers at the same requested size; the correction is applied by
/// painting the SVG at size / scale and scaling by scale, so the outer
/// [size] geometry stays exact and the caller still requests the same
/// GI-02 size.  No registry identity changes and no SVG edits.
final class GoalIcon extends StatelessWidget {
  const GoalIcon({
    required this.iconId,
    this.size = 32,
    this.semanticLabel,
    this.color = AppTheme.rose,
    this.fallbackIcon,
    super.key,
  });

  final String? iconId;
  final double size;
  final String? semanticLabel;
  final Color color;
  final IconData? fallbackIcon;

  /// Renderer-only optical scale per icon ID (POLISH-06).  Default 1.0;
  /// only the audited outlier is changed.  This is rendering metadata, never
  /// registry identity: IDs/categories/aliases/assets are untouched.
  static const Map<String, double> _opticalScaleById = <String, double>{
    'spiritual_temple': 1.15,
  };

  /// R1 (owner 2026-08-16): Dark-mode-only cyan compensation for the raw
  /// Goal Icon art.
  ///
  /// Forensic audit proof: the SVG art is byte-identical in Light and Dark
  /// (single assetPath, colorFilter null, no palette substitution), but the
  /// edge/AA pixels composite against the card surface — near-white blends in
  /// Light, near-black blends in Dark — so the SAME art reads lighter in Light
  /// and deeper/royal in Dark (measured lossless device deficit g -21, b -15;
  /// owner JPEG dominants up to -30/-23). The owner pre-authorized a
  /// GoalIcon-only Dark-mode cyan compensation layer for this exact case.
  ///
  /// [remapDarkCyan] rewrites ONLY the cyan-family hex values in a goal SVG
  /// string to a lighter first-pass compensation (+dR=20 +dG=28 +dB=34,
  /// derived from the measured deficit at ~60-70%; final value owner-validated
  /// on device). Gold (r > 200) and every other color are untouched by
  /// construction, Light mode never calls this, and no SVG file, palette,
  /// colorFilter, size, or opticalScale changes.
  static const int darkCyanDeltaR = 20;
  static const int darkCyanDeltaG = 28;
  static const int darkCyanDeltaB = 34;

  /// True for the raw-art cyan family (all 43 goal icons use one of these
  /// teal values as their primary fill/stroke).
  static bool _isCyanFamily(int r, int g, int b) =>
      b >= 150 && g >= 130 && r <= 140 && b > r + 20 && g > r + 30;

  /// Returns [source] with every cyan-family `#rrggbb` fill/stroke lightened
  /// by [darkCyanDeltaR]/[darkCyanDeltaG]/[darkCyanDeltaB] (clamped at 255).
  /// All other colors — gold first among them — are left byte-identical.
  @visibleForTesting
  static String remapDarkCyan(String source) {
    return source.replaceAllMapped(
      RegExp(r'#([0-9a-fA-F]{6})'),
      (match) {
        final hex = match.group(1)!;
        final r = int.parse(hex.substring(0, 2), radix: 16);
        final g = int.parse(hex.substring(2, 4), radix: 16);
        final b = int.parse(hex.substring(4, 6), radix: 16);
        if (!_isCyanFamily(r, g, b)) {
          return match.group(0)!;
        }
        final nr = (r + darkCyanDeltaR).clamp(0, 255);
        final ng = (g + darkCyanDeltaG).clamp(0, 255);
        final nb = (b + darkCyanDeltaB).clamp(0, 255);
        final color = '#${nr.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${ng.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${nb.toRadixString(16).padLeft(2, '0').toUpperCase()}';
        return color;
      },
    );
  }

  /// Testable per-ID optical scale; 1.0 for every icon without a correction.
  @visibleForTesting
  static double opticalScaleFor(String? iconId) {
    final definition = GoalIconRegistry.instance.findById(iconId);
    if (definition == null) {
      return 1.0;
    }
    return _opticalScaleById[definition.id] ?? 1.0;
  }

  /// Resolved dark-mode remapped SVG strings (R1). Once an asset has been
  /// loaded once, every later build renders it SYNCHRONOUSLY via
  /// [SvgPicture.string] — no async gap on warm builds (a FutureBuilder fed
  /// an already-completed future can lag a frame in widget tests). The remap
  /// is deterministic, so one entry per asset serves every surface.
  static final Map<String, String> _darkSvgStrings = <String, String>{};

  /// In-flight loads, so concurrent builds share one future per asset.
  static final Map<String, Future<String>> _darkSvgLoads =
      <String, Future<String>>{};

  /// The resolved dark-mode SVG string for [assetPath], or null if it has
  /// not been loaded yet.
  @visibleForTesting
  static String? darkSvgStringFor(String assetPath) =>
      _darkSvgStrings[assetPath];

  /// Loads and caches the dark-mode remapped SVG for [assetPath]. Completes
  /// immediately when already resolved.
  @visibleForTesting
  static Future<String> loadDarkSvg(String assetPath) {
    final cached = _darkSvgStrings[assetPath];
    if (cached != null) {
      return Future<String>.value(cached);
    }
    return _darkSvgLoads.putIfAbsent(
      assetPath,
      () async {
        final source = await rootBundle.loadString(assetPath);
        final remapped = remapDarkCyan(source);
        _darkSvgStrings[assetPath] = remapped;
        return remapped;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final definition = GoalIconRegistry.instance.findById(iconId);
    final label = semanticLabel ?? definition?.semanticsLabel ?? 'Goal icon';
    final Widget child;
    if (definition == null) {
      child = Icon(
        fallbackIcon ?? _fallbackForRole(null),
        size: size,
        color: color,
      );
    } else {
      final dark = Theme.of(context).brightness == Brightness.dark;
      final opticalScale = _opticalScaleById[definition.id] ?? 1.0;
      // R1: in Dark mode the raw art is rendered through the cyan-family
      // compensation (same pixels, compensated cyan, gold untouched); Light
      // keeps the raw single asset. colorFilter stays null in both. Warm
      // builds use the resolved string synchronously; only the very first
      // dark build of an asset waits for the load.
      final Widget svg = dark
          ? _DarkGoalSvg(
              assetPath: definition.assetPath,
              width: size * opticalScale,
              height: size * opticalScale,
            )
          : SvgPicture.asset(
              definition.assetPath,
              width: size * opticalScale,
              height: size * opticalScale,
              fit: BoxFit.contain,
              colorFilter: null,
              excludeFromSemantics: true,
            );
      if (opticalScale == 1.0) {
        child = ExcludeSemantics(child: svg);
      } else {
        // Optical scale: paint the SVG at size * scale and shrink it by
        // 1 / scale, so the painted viewBox lands EXACTLY at `size` while
        // the artwork inside renders `scale`-times larger (its transparent
        // viewBox padding is cropped, never the outer box stretched).  The
        // caller still requests the same GI-02 size and nothing overflows.
        child = Center(
          child: Transform.scale(
            scale: 1 / opticalScale,
            alignment: Alignment.center,
            child: ExcludeSemantics(child: svg),
          ),
        );
      }
    }
    return Semantics(
      image: true,
      label: label,
      child: SizedBox.square(dimension: size, child: child),
    );
  }

  static IconData _fallbackForRole(GoalRole? role) => switch (role) {
    GoalRole.dailyWeekly => Icons.today_outlined,
    GoalRole.weekly => Icons.flag_outlined,
    GoalRole.weeklyMonthly => Icons.calendar_month_outlined,
    null => Icons.flag_outlined,
  };
}

IconData goalIconFallbackForRole(GoalRole? role) => switch (role) {
  GoalRole.dailyWeekly => Icons.today_outlined,
  GoalRole.weekly => Icons.flag_outlined,
  GoalRole.weeklyMonthly => Icons.calendar_month_outlined,
  null => Icons.flag_outlined,
};

/// R1 dark-mode Goal Icon SVG. Renders the resolved compensated string
/// synchronously when cached (warm builds never wait); the very first dark
/// build of an asset shows the same transient empty state the raw asset
/// loader would, then paints the compensated art.
final class _DarkGoalSvg extends StatelessWidget {
  const _DarkGoalSvg({
    required this.assetPath,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cached = GoalIcon.darkSvgStringFor(assetPath);
    if (cached != null) {
      return SvgPicture.string(
        cached,
        width: width,
        height: height,
        fit: BoxFit.contain,
        colorFilter: null,
        excludeFromSemantics: true,
      );
    }
    return FutureBuilder<String>(
      future: GoalIcon.loadDarkSvg(assetPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return SvgPicture.string(
          snapshot.data!,
          width: width,
          height: height,
          fit: BoxFit.contain,
          colorFilter: null,
          excludeFromSemantics: true,
        );
      },
    );
  }
}
