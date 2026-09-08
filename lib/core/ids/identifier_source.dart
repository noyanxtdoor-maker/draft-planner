import 'package:uuid/uuid.dart';

abstract interface class IdentifierSource {
  String nextUuid();
}

final class UuidIdentifierSource implements IdentifierSource {
  const UuidIdentifierSource();

  @override
  String nextUuid() => const Uuid().v4();
}
