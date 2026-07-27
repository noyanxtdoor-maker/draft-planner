enum PrivacyStorageClass { local, synced, localOnly, secureDeviceStorage }

final class PrivacyCategoryRule {
  const PrivacyCategoryRule({
    required this.label,
    required this.storageClass,
    required this.allowedInDiagnostics,
    required this.allowedInAnalytics,
    required this.allowedInOutbox,
    required this.allowedInBackup,
  });

  final String label;
  final PrivacyStorageClass storageClass;
  final bool allowedInDiagnostics;
  final bool allowedInAnalytics;
  final bool allowedInOutbox;
  final bool allowedInBackup;
}

abstract final class PrivacyDataPolicy {
  static const PrivacyCategoryRule ordinaryLocalData = PrivacyCategoryRule(
    label: 'Local planner data',
    storageClass: PrivacyStorageClass.local,
    allowedInDiagnostics: false,
    allowedInAnalytics: false,
    allowedInOutbox: false,
    allowedInBackup: true,
  );

  static const PrivacyCategoryRule optionalSyncedData = PrivacyCategoryRule(
    label: 'Optional synced data',
    storageClass: PrivacyStorageClass.synced,
    allowedInDiagnostics: false,
    allowedInAnalytics: false,
    allowedInOutbox: true,
    allowedInBackup: true,
  );

  static const PrivacyCategoryRule rawCalendarImport = PrivacyCategoryRule(
    label: 'Raw BetterCalendar import',
    storageClass: PrivacyStorageClass.localOnly,
    allowedInDiagnostics: false,
    allowedInAnalytics: false,
    allowedInOutbox: false,
    allowedInBackup: false,
  );

  static const PrivacyCategoryRule privateReflection = PrivacyCategoryRule(
    label: 'Extra Private reflections',
    storageClass: PrivacyStorageClass.localOnly,
    allowedInDiagnostics: false,
    allowedInAnalytics: false,
    allowedInOutbox: false,
    allowedInBackup: false,
  );

  static const PrivacyCategoryRule authenticationToken = PrivacyCategoryRule(
    label: 'Account authentication token',
    storageClass: PrivacyStorageClass.secureDeviceStorage,
    allowedInDiagnostics: false,
    allowedInAnalytics: false,
    allowedInOutbox: false,
    allowedInBackup: false,
  );

  static const List<PrivacyCategoryRule> sensitiveRules = <PrivacyCategoryRule>[
    rawCalendarImport,
    privateReflection,
    authenticationToken,
  ];
}
