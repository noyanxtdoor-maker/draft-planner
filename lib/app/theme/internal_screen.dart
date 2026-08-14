import 'package:flutter/material.dart';

/// Scoped density system for internal/child screens only.
///
/// Root/main screens (Home, Planner, the Planning main Goal list, Pathways,
/// Contacts, More, and the bottom navigation) keep the approved
/// `AppTypography`/`AppTheme` sizes.  This file intentionally defines smaller
/// tokens and components that internal forms, details, archives, histories,
/// pickers, and settings screens opt into — it never touches the global
/// `ThemeData` in a way that would shrink a root screen.
abstract final class InternalScreen {
  // App bar -------------------------------------------------------------
  /// Visual height of internal app bars (approved range 56-64 dp).
  static const double appBarHeight = 60;
  static const TextStyle appBarTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w500,
  );

  // Page padding --------------------------------------------------------
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 24);

  // Typography ----------------------------------------------------------
  /// Section heading for internal screens (16-18 sp, semibold).
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  /// Primary body text for internal screens (14-15 sp).
  static const TextStyle body = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  /// Secondary/metadata text for internal screens (13-14 sp).
  static const TextStyle label = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  /// Input/floating label style for internal screens.
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    height: 17 / 13,
    fontWeight: FontWeight.w400,
  );

  /// Compact primary button label (14-16 sp).
  static const TextStyle button = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
  );

  // Spacing -------------------------------------------------------------
  /// Gap between major sections (18-24 dp).
  static const double sectionGap = 18;

  /// Gap between normal fields/cards (10-14 dp).
  static const double fieldGap = 10;

  /// Gap between a label and its control (6-8 dp).
  static const double labelToControlGap = 6;
}

/// Compact app bar for internal/child screens (60 dp visual height, 22 sp
/// title, 48 x 48 leading/action hit targets preserved).  Root screens keep
/// their own app bars and the global app-bar theme untouched.
final class InternalAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const InternalAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.surfaceTintColor,
    this.backgroundColor,
    this.scrolledUnderElevation,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Color? surfaceTintColor;

  /// Optional pinned base color.  Null keeps the theme/M3 default, which in
  /// Material 3 swaps to `surfaceContainer` once content scrolls under the
  /// app bar.  Consumers that must hold the same surface while scrolling
  /// (e.g. Choose Icon, A8) pass [AppTheme.surface] explicitly.
  final Color? backgroundColor;

  /// Optional scrolled-under elevation.  Null keeps the M3 default of 3.0;
  /// consumers that must not lift when scrolled under pass 0 (A8).
  final double? scrolledUnderElevation;

  @override
  Size get preferredSize => Size.fromHeight(
    InternalScreen.appBarHeight + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: InternalScreen.appBarHeight,
      titleTextStyle: InternalScreen.appBarTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      surfaceTintColor: surfaceTintColor,
      backgroundColor: backgroundColor,
      scrolledUnderElevation: scrolledUnderElevation,
    );
  }
}
