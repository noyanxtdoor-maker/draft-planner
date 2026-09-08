abstract interface class AppClock {
  DateTime nowUtc();
}

final class SystemAppClock implements AppClock {
  const SystemAppClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
