final class DeletionImpact {
  const DeletionImpact({required this.title, required this.explanation});

  final String title;
  final String explanation;
}

abstract final class DeletionImpactCatalog {
  static const List<DeletionImpact> values = <DeletionImpact>[
    DeletionImpact(
      title: 'Local app data',
      explanation:
          'Removing local data affects this device. It is separate from '
          'deleting an account or cloud copy.',
    ),
    DeletionImpact(
      title: 'Optional synced data',
      explanation:
          'Cloud-data deletion is a separate action and will explain its '
          'scope before any destructive request.',
    ),
    DeletionImpact(
      title: 'Backups',
      explanation:
          'Deleting live data does not silently promise that an existing '
          'backup has also been erased.',
    ),
    DeletionImpact(
      title: 'Source files',
      explanation:
          'Deleting imported app records does not delete the original file '
          'you selected from another app or storage provider.',
    ),
  ];
}
