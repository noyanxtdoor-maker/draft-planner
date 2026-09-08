import 'package:flutter/material.dart';
import 'package:rmplanner/features/maps/domain/saved_place.dart';

/// Exact Pass 2 Standard-category glyph concepts shared by the editor and
/// persisted map marker renderer. The nine categories remain visually
/// distinct and retain the authority-locked order from the domain enum.
IconData savedPlaceCategoryIcon(SavedPlaceStandardCategory category) =>
    switch (category) {
      SavedPlaceStandardCategory.information => Icons.info,
      SavedPlaceStandardCategory.avoid => Icons.warning_amber_rounded,
      SavedPlaceStandardCategory.food => Icons.restaurant,
      SavedPlaceStandardCategory.repair => Icons.build,
      SavedPlaceStandardCategory.transit => Icons.directions_bus,
      SavedPlaceStandardCategory.wifi => Icons.wifi,
      SavedPlaceStandardCategory.haircut => Icons.content_cut,
      SavedPlaceStandardCategory.shopping => Icons.shopping_cart,
      SavedPlaceStandardCategory.laundry => Icons.checkroom,
    };

/// One presentation identity for map bitmaps, search results and editor
/// semantics. Persisted colors are not rewritten when the app theme changes.
final class SavedPlaceVisualIdentity {
  const SavedPlaceVisualIdentity._({
    required this.icon,
    required this.emoji,
    required this.color,
    required this.foreground,
  });

  static const warningRed = Color(0xFFD32F2F);
  static const warningRedOnDark = Color(0xFFFF6659);
  final IconData? icon;
  final String? emoji;
  final Color color;
  final Color foreground;

  factory SavedPlaceVisualIdentity.fromPlace(SavedPlace place) =>
      SavedPlaceVisualIdentity.resolve(
        mode: place.markerMode,
        category: place.standardCategory,
        color: Color(place.markerColorArgb),
        emoji: place.customEmoji,
      );

  factory SavedPlaceVisualIdentity.resolve({
    required SavedPlaceMarkerMode mode,
    required SavedPlaceStandardCategory category,
    Color? color,
    String? emoji,
  }) {
    final nativeEmoji = mode == SavedPlaceMarkerMode.custom ? emoji : null;
    // Avoid defaults to semantic red; a deliberate stored custom color is
    // still data, never replaced by a theme or rewritten during rendering.
    final resolved = color ?? Color(category.defaultColorArgb);
    return SavedPlaceVisualIdentity._(
      icon: nativeEmoji == null ? savedPlaceCategoryIcon(category) : null,
      emoji: nativeEmoji,
      color: resolved,
      foreground: resolved.computeLuminance() > .179
          ? Colors.black
          : Colors.white,
    );
  }

  static Color categoryAccent(
    SavedPlaceStandardCategory category,
    Color themeAccent,
    Brightness brightness,
  ) => category == SavedPlaceStandardCategory.avoid
      ? (brightness == Brightness.dark ? warningRedOnDark : warningRed)
      : themeAccent;
}

/// Uses the same colored container/contrast glyph as the native map bitmap.
/// Emoji text has no foreground tint and retains the platform's native colors.
final class SavedPlaceIdentityIcon extends StatelessWidget {
  const SavedPlaceIdentityIcon({
    required this.identity,
    this.size = 32,
    super.key,
  });
  final SavedPlaceVisualIdentity identity;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: identity.emoji ?? 'Saved Place',
    child: SizedBox.square(
      dimension: size,
      child: identity.emoji != null
          ? Center(
              child: Text(
                identity.emoji!,
                style: TextStyle(fontSize: size * .8, height: 1),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: identity.color,
                borderRadius: BorderRadius.circular(size * .15),
              ),
              child: Icon(
                identity.icon,
                size: size * .7,
                color: identity.foreground,
              ),
            ),
    ),
  );
}
