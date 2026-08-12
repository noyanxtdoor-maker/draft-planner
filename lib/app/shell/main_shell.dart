import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';
import 'package:rmplanner/app/shell/global_drawer_controller.dart';
import 'package:rmplanner/features/shell/global_app_drawer.dart';

final class MainShell extends StatefulWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  State<MainShell> createState() => _MainShellState();
}

final class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalDrawerController _controller = GlobalDrawerController();

  @override
  void initState() {
    super.initState();
    _controller.attach(_scaffoldKey);
  }

  @override
  void dispose() {
    _controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = location.startsWith(RoutePaths.planner)
        ? 1
        : location.startsWith(RoutePaths.contacts)
        ? 3
        : location.startsWith(RoutePaths.more)
        ? 4
        : 0;
    final isGoalIconPicker = location.endsWith('/icon');
    // Pack 2 root Back policy (B1 + B7).  Child pages are popped by the
    // shell's own navigator before this PopScope is ever consulted, so a
    // pushed page always returns to its logical parent.  This PopScope only
    // sees a pop that reached the shell page itself, i.e. a root tab or a
    // child page that was entered directly and has no parent beneath it:
    //   Home            -> pop flows on; the platform exits the app;
    //   Planner/More    -> reveal the existing Home root;
    //   direct /planner -> Planner root;
    //   direct /more    -> More root;
    //   anything else   -> Home root.
    // Root-level routes pushed above the shell (tasks, events, privacy, ...)
    // are popped by the root navigator before this route is consulted.
    final isHomeRoot = location == RoutePaths.home;
    // Root tabs are exactly `/planner` and `/more`; anything deeper under
    // those prefixes is a direct-entered child page that needs a root
    // fallback.
    final isPlannerChild = location.startsWith('${RoutePaths.planner}/');
    final isMoreChild = location.startsWith('${RoutePaths.more}/');
    final isContactsChild = location.startsWith('${RoutePaths.contacts}/');

    return GlobalDrawerScope(
      controller: _controller,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const GlobalAppDrawer(),
        drawerEdgeDragWidth: 24,
        body: PopScope<void>(
          canPop: isHomeRoot,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            // Pack 3: an open drawer is popped before any route fallback, so
            // Android Back closes the drawer first from every root (never
            // double-Back, never exit-while-open, never discard edits behind
            // it).  On Home the open drawer pops through the normal path and
            // never reaches here; this branch covers non-Home roots where the
            // shell PopScope intercepts the pop before the inner navigator
            // would dismiss the drawer.
            final scaffold = _scaffoldKey.currentState;
            if (scaffold != null && scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
              return;
            }
            // Only non-Home locations reach here with the drawer closed.
            // Reveal the existing logical root; `go` replaces the current
            // page, so no duplicate Home route or tab-history stack is ever
            // created.
            //   Planner/More root tabs -> Home;
            //   direct /planner child   -> Planner root;
            //   direct /more child      -> More root;
            //   everything else         -> Home root.
            if (isPlannerChild) {
              context.go(RoutePaths.planner);
            } else if (isContactsChild) {
              context.go(RoutePaths.contacts);
            } else if (isMoreChild) {
              context.go(RoutePaths.more);
            } else {
              context.go(RoutePaths.home);
            }
          },
          child: widget.child,
        ),
        bottomNavigationBar: isGoalIconPicker
            ? null
            : NavigationBar(
                key: const Key('main-bottom-navigation'),
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  switch (index) {
                    case 0:
                      context.go(RoutePaths.home);
                      return;
                    case 1:
                      context.go(RoutePaths.planner);
                      return;
                    case 2:
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Pathways is not available in the current '
                              'authorized build.',
                            ),
                          ),
                        );
                      return;
                    case 3:
                      context.go(RoutePaths.contacts);
                      return;
                    case 4:
                      context.go(RoutePaths.more);
                      return;
                  }
                },
                destinations: const <NavigationDestination>[
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Planner',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.layers_outlined),
                    selectedIcon: Icon(Icons.layers),
                    label: 'Pathways',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    selectedIcon: Icon(Icons.people),
                    label: 'Contacts',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    selectedIcon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
              ),
      ),
    );
  }
}
