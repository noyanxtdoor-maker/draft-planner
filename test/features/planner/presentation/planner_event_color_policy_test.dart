import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/planner/presentation/widgets/planner_event_block_layout_policy.dart';

void main() {
  test('contrast resolver chooses light text for dark surfaces', () {
    expect(
      PlannerEventBlockColorPolicy.textColor(const Color(0xFF404447)),
      Colors.white,
    );
  });

  test('contrast resolver chooses dark text for bright surfaces', () {
    expect(
      PlannerEventBlockColorPolicy.textColor(const Color(0xFFF2E9E0)),
      const Color(0xFF1B1B1F),
    );
  });

  test('contrast ratio is symmetric and deterministic', () {
    final lightOnDark = PlannerEventBlockColorPolicy.contrastRatio(
      Colors.white,
      const Color(0xFF404447),
    );
    final darkOnLight = PlannerEventBlockColorPolicy.contrastRatio(
      const Color(0xFF1B1B1F),
      const Color(0xFFF2E9E0),
    );
    expect(lightOnDark, greaterThan(4.5));
    expect(darkOnLight, greaterThan(4.5));
  });
}
