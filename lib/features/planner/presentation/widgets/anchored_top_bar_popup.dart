import 'dart:async';

import 'package:flutter/material.dart';

/// Shared controller for anchored top-bar popups.
///
/// Used by the Planner top bar to coordinate a single visible popup at
/// a time. When a second popup is requested while another is visible,
/// the previous one is dismissed first.
final AnchoredTopBarPopupController anchoredTopBarPopupController =
    AnchoredTopBarPopupController._();

/// Controller used by the Planner top bar to programmatically dismiss the
/// current anchored popup (for example when opening another one).
final class AnchoredTopBarPopupController {
  AnchoredTopBarPopupController._();

  OverlayEntry? _active;
  VoidCallback? _activeCloser;

  /// Whether any anchored popup is currently visible.
  bool get isOpen => _active != null;

  /// Programmatically dismiss the active popup (if any).
  void dismiss() {
    _activeCloser?.call();
  }

  void _register(OverlayEntry entry, VoidCallback closer) {
    dismiss();
    _active = entry;
    _activeCloser = closer;
  }

  void _unregister(OverlayEntry entry) {
    if (identical(_active, entry)) {
      _active = null;
      _activeCloser = null;
    }
  }
}

/// Anchors a popup directly beneath the widget identified by [triggerKey].
///
/// The popup:
///   * opens on the next frame so the trigger's RenderBox is available;
///   * renders inside the root [Overlay] above the top bar;
///   * animates downward from the trigger's bottom edge with a
///     fade and a slight scale-from-top-right;
///   * dismisses on outside tap or Android Back;
///   * resizes against the screen edges (collides inward when needed).
///
/// [width] and [maxHeight] are upper bounds; the popup shrinks to
/// content when feasible.
///
/// The function returns a future that completes when the popup is
/// dismissed (either by the user or programmatically).
Future<void> showAnchoredTopBarPopup({
  required BuildContext context,
  required GlobalKey triggerKey,
  required WidgetBuilder builder,
  double width = 280,
  double maxHeight = 360,
  double topGap = 0,
  double borderRadius = 14,
  Duration duration = const Duration(milliseconds: 220),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final renderBox = triggerKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    return;
  }
  final completer = Completer<void>();
  late OverlayEntry entry;
  late VoidCallback closer;
  closer = () {
    if (entry.mounted) {
      entry.remove();
    }
    anchoredTopBarPopupController._unregister(entry);
    if (!completer.isCompleted) {
      completer.complete();
    }
  };
  entry = OverlayEntry(
    builder: (entryContext) {
      return _AnchoredTopBarPopupScaffold(
        triggerBox: renderBox,
        width: width,
        maxHeight: maxHeight,
        topGap: topGap,
        borderRadius: borderRadius,
        duration: duration,
        onDismissRequest: closer,
        child: Builder(builder: builder),
      );
    },
  );
  overlay.insert(entry);
  anchoredTopBarPopupController._register(entry, closer);
  return completer.future;
}

class _AnchoredTopBarPopupScaffold extends StatefulWidget {
  const _AnchoredTopBarPopupScaffold({
    required this.triggerBox,
    required this.width,
    required this.maxHeight,
    required this.topGap,
    required this.borderRadius,
    required this.duration,
    required this.onDismissRequest,
    required this.child,
  });

  final RenderBox triggerBox;
  final double width;
  final double maxHeight;
  final double topGap;
  final double borderRadius;
  final Duration duration;
  final VoidCallback onDismissRequest;
  final Widget child;

  @override
  State<_AnchoredTopBarPopupScaffold> createState() =>
      _AnchoredTopBarPopupScaffoldState();
}

class _AnchoredTopBarPopupScaffoldState
    extends State<_AnchoredTopBarPopupScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_controller.status == AnimationStatus.completed) {
      unawaited(
        _controller.reverse().whenComplete(() {
          if (mounted) {
            widget.onDismissRequest();
          }
        }),
      );
    } else {
      widget.onDismissRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final padding = media.padding;
    final screenSize = media.size;
    final triggerTopLeft = widget.triggerBox.localToGlobal(Offset.zero);
    final triggerSize = widget.triggerBox.size;
    final topY = triggerTopLeft.dy + triggerSize.height + widget.topGap;
    final leftX = triggerTopLeft.dx;

    final maxLeftSpace = screenSize.width - padding.right - 8;
    double resolvedLeft = leftX + triggerSize.width - widget.width;
    if (resolvedLeft < padding.left + 8) {
      resolvedLeft = padding.left + 8;
    }
    if (resolvedLeft + widget.width > maxLeftSpace) {
      resolvedLeft = maxLeftSpace - widget.width;
    }

    final maxAvailableHeight = (screenSize.height - padding.bottom - topY - 12)
        .clamp(96.0, widget.maxHeight);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _dismiss();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: resolvedLeft,
              top: topY,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final t = _animation.value;
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, -8 * (1 - t)),
                      child: Transform.scale(
                        alignment: Alignment.topRight,
                        scale: 0.96 + 0.04 * t,
                        child: child,
                      ),
                    ),
                  );
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: widget.width,
                    maxHeight: maxAvailableHeight.toDouble(),
                  ),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 12,
                    shadowColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
