import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rmplanner/app/router/route_names.dart';

final class LinkRecoveryScreen extends StatelessWidget {
  const LinkRecoveryScreen({required this.attemptedLocation, super.key});

  final String attemptedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link unavailable')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.link_off, size: 64),
              const SizedBox(height: 20),
              Text(
                'This link is invalid, stale, or belongs to a feature that is '
                'not available yet.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'No local record was changed.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                attemptedLocation,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Return to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
