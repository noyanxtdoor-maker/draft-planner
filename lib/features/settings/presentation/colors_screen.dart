import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';

final class ColorsScreen extends StatelessWidget {
  const ColorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Colors')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            Card(
              child: ListTile(
                key: const Key('colors-planner-event-colors'),
                leading: const Icon(Icons.event_outlined),
                title: const Text('Planner Event Colors'),
                subtitle: const Text(
                  'Customize the accent and background for each Event Type',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(RoutePaths.plannerEventColors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
