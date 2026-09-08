enum OptionalPermission {
  contacts,
  notifications,
  foregroundLocation,
  calendar,
}

enum PermissionState { notRequested, granted, denied, revoked, unavailable }

enum OperatingSystemPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

final class PermissionAudit {
  const PermissionAudit({
    required this.requestedByApp,
    required this.everGranted,
  });

  const PermissionAudit.neverRequested()
    : requestedByApp = false,
      everGranted = false;

  final bool requestedByApp;
  final bool everGranted;
}

final class PermissionSummary {
  const PermissionSummary({
    required this.permission,
    required this.title,
    required this.purpose,
    required this.state,
  });

  final OptionalPermission permission;
  final String title;
  final String purpose;
  final PermissionState state;
}

abstract final class OptionalPermissionCatalog {
  static const List<OptionalPermission> values = <OptionalPermission>[
    OptionalPermission.contacts,
    OptionalPermission.notifications,
    OptionalPermission.foregroundLocation,
    OptionalPermission.calendar,
  ];

  static String title(OptionalPermission permission) {
    return switch (permission) {
      OptionalPermission.contacts => 'Contacts',
      OptionalPermission.notifications => 'Notifications',
      OptionalPermission.foregroundLocation => 'Location while using the app',
      OptionalPermission.calendar => 'Device calendar',
    };
  }

  static String purpose(OptionalPermission permission) {
    return switch (permission) {
      OptionalPermission.contacts =>
        'Used only when you choose a contact-related feature. Core planning '
            'works without contact access.',
      OptionalPermission.notifications =>
        'Used only when you enable reminders. Private content stays hidden '
            'unless you explicitly allow notification previews.',
      OptionalPermission.foregroundLocation =>
        'Used only for a location feature you start while the app is open. '
            'Next Transfer does not request background location.',
      OptionalPermission.calendar =>
        'Used only when you choose an external-calendar feature. Your local '
            'planner works without device-calendar access.',
    };
  }
}
