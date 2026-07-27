final class LifeIndicatorSeed {
  const LifeIndicatorSeed({
    required this.key,
    required this.label,
    required this.position,
    this.unit = 'count',
  });

  final String key;
  final String label;
  final int position;
  final String unit;
}

const approvedLifeIndicatorSeeds = <LifeIndicatorSeed>[
  LifeIndicatorSeed(
    key: 'job_applications',
    label: 'Job Applications',
    position: 0,
  ),
  LifeIndicatorSeed(
    key: 'scripture_study',
    label: 'Scripture Study',
    position: 1,
  ),
  LifeIndicatorSeed(key: 'exercise', label: 'Exercise', position: 2),
  LifeIndicatorSeed(
    key: 'meaningful_connections',
    label: 'Meaningful Connections',
    position: 3,
  ),
  LifeIndicatorSeed(key: 'budget_review', label: 'Budget Review', position: 4),
  LifeIndicatorSeed(key: 'temple_visit', label: 'Temple Visit', position: 5),
];
