import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rmplanner/features/maps/domain/map_coordinate.dart';
import 'package:url_launcher/url_launcher.dart';

/// External navigation handoff for saved map pins (M4).
///
/// Next Transfer hands the coordinates to an installed navigation app and
/// records NOTHING on return — no Activity, no outcome, no Timeline claim.
/// If no compatible app is installed, the user gets a copy fallback.
abstract final class MapExternalNavigation {
  static Uri _googleNavigationUri(MapCoordinate coordinate) {
    return Uri.parse(
      'google.navigation:q=${coordinate.latitude},${coordinate.longitude}',
    );
  }

  static Uri _geoUri(MapCoordinate coordinate, {String? label}) {
    final query = Uri.encodeComponent(
      '${coordinate.latitude},${coordinate.longitude}'
      '${label == null || label.isEmpty ? '' : ' ($label)'}',
    );
    return Uri.parse(
      'geo:${coordinate.latitude},${coordinate.longitude}?q=$query',
    );
  }

  static Future<bool> canLaunch(MapCoordinate coordinate) {
    return canLaunchUrl(_geoUri(coordinate));
  }

  /// Launches the external navigation app for [coordinate].  Returns true
  /// when the platform accepted the handoff.  Never records an outcome.
  static Future<bool> launch(MapCoordinate coordinate, {String? label}) {
    return launchUrl(
      _geoUri(coordinate, label: label),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Prefers Google Maps, falls back to the platform map chooser, then keeps
  /// the user in Next Transfer and copies coordinates when neither launches.
  /// The handoff remains a pure external action with no domain write.
  static Future<bool> launchWithFallback(
    BuildContext context,
    MapCoordinate coordinate, {
    String? label,
  }) async {
    for (final uri in <Uri>[
      _googleNavigationUri(coordinate),
      _geoUri(coordinate, label: label),
    ]) {
      try {
        if (await canLaunchUrl(uri) &&
            await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } on Object {
        // Continue to the next provider, then the local copy fallback.
      }
    }
    if (!context.mounted) {
      return false;
    }
    return copyCoordinates(context, coordinate);
  }

  /// Copy fallback: writes `lat, lng` to the clipboard and reports whether
  /// the copy was accepted.
  static Future<bool> copyCoordinates(
    BuildContext context,
    MapCoordinate coordinate,
  ) async {
    final data = ClipboardData(text: coordinate.description);
    await Clipboard.setData(data);
    if (!context.mounted) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordinates copied. Paste them into your maps app.'),
      ),
    );
    return true;
  }
}
