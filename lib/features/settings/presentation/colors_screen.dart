import 'package:flutter/material.dart';
import 'package:rmplanner/features/settings/presentation/planner_event_colors_screen.dart';

/// The single Colors surface is the owner of both Planner Event and Contact
/// Group color settings.  The legacy nested route is retained as a deep-link
/// compatibility path, but it renders this same canonical screen.
final class ColorsScreen extends StatelessWidget {
  const ColorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlannerEventColorsScreen();
  }
}
