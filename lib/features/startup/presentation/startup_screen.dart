import 'package:flutter/material.dart';

final class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: 'Opening your local Next Transfer data',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Opening your local planner…'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
