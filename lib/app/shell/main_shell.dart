import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';

final class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = location.startsWith(RoutePaths.planner)
        ? 1
        : location.startsWith(RoutePaths.more)
        ? 4
        : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
            case 3:
              final label = const <String>[
                'Home',
                'Planner',
                'Pathways',
                'Contacts',
                'More',
              ][index];
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '$label is not available in the current authorized '
                      'build.',
                    ),
                  ),
                );
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
    );
  }
}
