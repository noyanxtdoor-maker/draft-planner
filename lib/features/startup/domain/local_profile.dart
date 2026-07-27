final class LocalProfile {
  const LocalProfile({
    required this.id,
    required this.localName,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.displayName,
  });

  final String id;
  final String localName;
  final String? displayName;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  String get effectiveName {
    final candidate = displayName?.trim();
    return candidate == null || candidate.isEmpty ? localName : candidate;
  }
}
