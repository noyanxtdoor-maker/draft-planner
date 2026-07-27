import 'package:flutter/material.dart';

final class ProtectedContentScreen extends StatelessWidget {
  const ProtectedContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_outline, size: 64),
                SizedBox(height: 20),
                Text(
                  'Protected content remains hidden.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'The OS-backed unlock implementation belongs to VS-02 and is '
                  'not presented as complete in VS-01.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
