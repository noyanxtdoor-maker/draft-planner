import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/internal_screen.dart';

/// Honest local Messages shell (Pack 3, locked policy 1).
///
/// Both the Home bell and the drawer Messages destination open this one
/// canonical screen.  It performs no remote fetch, creates no backend,
/// claims no unread count, and never routes to Android notification
/// permissions.  When there are no local messages it shows a truthful
/// empty state and nothing more.
final class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: InternalAppBar(title: const Text('Messages')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.chat_bubble_outline,
                  size: 44,
                  color: Colors.white38,
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet.',
                  key: const Key('messages-empty-title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    height: 22 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'There are no local messages.',
                  key: const Key('messages-empty-body'),
                  textAlign: TextAlign.center,
                  style: InternalScreen.label.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
