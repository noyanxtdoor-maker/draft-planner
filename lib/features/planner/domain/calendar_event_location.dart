final class CalendarEventLocationSelection {
  const CalendarEventLocationSelection({
    required this.placeName,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.externalPlaceId,
  });

  final String? placeName;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? externalPlaceId;
}

abstract interface class CalendarEventLocationPicker {
  Future<CalendarEventLocationSelection?> selectLocation({
    CalendarEventLocationSelection? initialValue,
  });
}
