final class PlannerDate implements Comparable<PlannerDate> {
  const PlannerDate({
    required this.year,
    required this.month,
    required this.day,
  });

  factory PlannerDate.fromDateTime(DateTime value) {
    return PlannerDate(year: value.year, month: value.month, day: value.day);
  }

  factory PlannerDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      throw FormatException('Planner dates must use YYYY-MM-DD');
    }
    final parsed = PlannerDate(
      year: int.parse(parts[0]),
      month: int.parse(parts[1]),
      day: int.parse(parts[2]),
    );
    parsed._validate();
    return parsed;
  }

  final int year;
  final int month;
  final int day;

  DateTime get asLocalDate => DateTime(year, month, day);

  int get weekday => asLocalDate.weekday;

  PlannerDate addDays(int days) {
    return PlannerDate.fromDateTime(asLocalDate.add(Duration(days: days)));
  }

  String get iso8601 {
    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$year-$monthText-$dayText';
  }

  void _validate() {
    final value = asLocalDate;
    if (value.year != year || value.month != month || value.day != day) {
      throw FormatException('Invalid planner date: $iso8601');
    }
  }

  @override
  int compareTo(PlannerDate other) => iso8601.compareTo(other.iso8601);

  @override
  bool operator ==(Object other) {
    return other is PlannerDate &&
        year == other.year &&
        month == other.month &&
        day == other.day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso8601;
}

abstract interface class PlannerDateSource {
  PlannerDate today();
}

final class SystemPlannerDateSource implements PlannerDateSource {
  const SystemPlannerDateSource();

  @override
  PlannerDate today() => PlannerDate.fromDateTime(DateTime.now());
}
