import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:rmplanner/features/contacts/domain/contact.dart';

final class ContactGroupIdentityDot extends StatelessWidget {
  const ContactGroupIdentityDot({required this.colorValue, super.key});

  final ColorValue colorValue;

  @override
  Widget build(BuildContext context) {
    final color = colorValue.isNeutral
        ? const Color(0xFF9CA0A6)
        : Color(colorValue.value);
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

final class QuickFilterChip extends StatelessWidget {
  const QuickFilterChip({
    required this.label,
    required this.summary,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final String label;
  final String summary;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        maximumSize: const Size(double.infinity, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        side: BorderSide(
          color: active ? scheme.primary : AppTheme.outlineOf(context),
        ),
        backgroundColor: active
            ? scheme.primary.withValues(alpha: .12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '$label: $summary',
            style: TextStyle(
              color: active
                  ? scheme.primary
                  : AppTheme.onFillTextOf(context, 1),
              fontSize: 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.keyboard_arrow_down, size: 20, color: scheme.primary),
        ],
      ),
    );
  }
}

/// Contacts Filter action glyph supplied by the owner as an SVG asset.
/// The existing 32x32 wrapper and surrounding button remain unchanged.
final class FilterPlusIcon extends StatelessWidget {
  const FilterPlusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: SvgPicture.asset(
        'assets/icons/filter-svgrepo-com.svg',
        key: const Key('filter-plus-glyph'),
        fit: BoxFit.contain,
      ),
    );
  }
}

final class TriStateMasterCheckbox extends StatelessWidget {
  const TriStateMasterCheckbox({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Checkbox(tristate: true, value: value, onChanged: onChanged),
      ),
    );
  }
}

final class FullWidthSectionDivider extends StatelessWidget {
  const FullWidthSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: double.infinity,
      color: AppTheme.sectionDividerOf(context),
    );
  }
}

/// Major edge-to-edge section band that separates the sort block from the
/// category table and the category table from the lower event toggles.
/// Slightly thicker than a row divider using the SAME neutral section-divider
/// family as the Filter's other structural dividers (never Theme Color).
final class MajorSectionBand extends StatelessWidget {
  const MajorSectionBand({super.key, this.height = 12});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppTheme.sectionDividerOf(context),
    );
  }
}

final class PmgStyleSortField extends StatelessWidget {
  const PmgStyleSortField({
    required this.value,
    required this.onTap,
    this.anchorKey,
    super.key,
  });

  final String value;
  final VoidCallback onTap;
  final GlobalKey? anchorKey;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: AppTheme.outlineOf(context), width: 1),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: SizedBox(
          key: anchorKey,
          height: 52,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Contact List Sort',
              suffixIcon: const Icon(Icons.arrow_drop_down, size: 24),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              labelStyle: AppTypography.micro,
              floatingLabelStyle: AppTypography.micro,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppTheme.onFillTextOf(context, 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showContactLongPressPreview({
  required BuildContext context,
  required ContactSummary summary,
  required VoidCallback onView,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _ContactLongPressPreviewSheet(summary: summary, onView: onView),
  );
}

final class _ContactLongPressPreviewSheet extends StatelessWidget {
  const _ContactLongPressPreviewSheet({
    required this.summary,
    required this.onView,
  });

  final ContactSummary summary;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final address = summary.contact.addressText?.trim();
    final hasAddress = address != null && address.isNotEmpty;
    return Material(
      key: const Key('contact-long-press-preview'),
      color: AppTheme.surfaceOf(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 210),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  key: const Key('contact-preview-handle'),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outlineOf(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      summary.contact.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('contact-preview-view'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onView();
                    },
                    child: const Text('View'),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (hasAddress)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Address',
                            style: TextStyle(
                              color: AppTheme.secondaryTextOf(context),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(address),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('contact-preview-map'),
                      tooltip: 'Map',
                      onPressed: () => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Open the contact profile to manage its map pin.',
                            ),
                          ),
                        ),
                      icon: const Icon(Icons.location_on_outlined),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
