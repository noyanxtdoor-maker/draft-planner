import 'package:flutter/material.dart';

/// Global controller exposed by [MainShell] so descendant screens can open
/// the shared global app drawer from any [BuildContext] without having to
/// resolve the shell's [ScaffoldState] directly.
///
/// Screens that previously called `Scaffold.of(context).openDrawer()` only
/// worked when the inner Scaffold owned the drawer. The shell owns the
/// drawer; descendants must use this controller instead.
final class GlobalDrawerController {
  GlobalDrawerController();

  GlobalKey<ScaffoldState>? _scaffoldKey;

  /// Bind to the shell [Scaffold] that owns the global drawer.
  void attach(GlobalKey<ScaffoldState> scaffoldKey) {
    _scaffoldKey = scaffoldKey;
  }

  /// Release the binding (used on shell disposal).
  void detach() {
    _scaffoldKey = null;
  }

  /// Opens the global drawer if it is attached.
  ///
  /// Returns `true` when the drawer was opened, `false` when no shell
  /// scaffold was attached yet. Callers should treat `false` as a no-op.
  bool open() {
    final scaffoldKey = _scaffoldKey;
    if (scaffoldKey == null) {
      return false;
    }
    final state = scaffoldKey.currentState;
    if (state == null) {
      return false;
    }
    if (state.isDrawerOpen) {
      return true;
    }
    state.openDrawer();
    return true;
  }
}

/// Inherited widget that publishes the [GlobalDrawerController] down the
/// widget tree from [MainShell].
final class GlobalDrawerScope extends InheritedWidget {
  const GlobalDrawerScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final GlobalDrawerController controller;

  static GlobalDrawerController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GlobalDrawerScope>();
    assert(
      scope != null,
      'GlobalDrawerScope was not found. The widget tree must be wrapped in '
      'MainShell.',
    );
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(GlobalDrawerScope oldWidget) =>
      oldWidget.controller != controller;
}
