enum AppEnvironmentName {
  local,
  development,
  staging,
  production;

  static AppEnvironmentName parse(String value) {
    return AppEnvironmentName.values.firstWhere(
      (candidate) => candidate.name == value,
      orElse: () => AppEnvironmentName.local,
    );
  }
}

final class AppEnvironment {
  const AppEnvironment({required this.name, required this.label});

  factory AppEnvironment.fromDartDefines() {
    const rawName = String.fromEnvironment(
      'NEXT_TRANSFER_ENV',
      defaultValue: 'local',
    );
    const rawLabel = String.fromEnvironment(
      'NEXT_TRANSFER_ENV_LABEL',
      defaultValue: 'LOCAL',
    );

    return AppEnvironment(
      name: AppEnvironmentName.parse(rawName),
      label: rawLabel.trim().isEmpty ? rawName.toUpperCase() : rawLabel.trim(),
    );
  }

  final AppEnvironmentName name;
  final String label;

  bool get showDebugBanner => name != AppEnvironmentName.production;
}
