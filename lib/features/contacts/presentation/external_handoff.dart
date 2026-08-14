import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rmplanner/app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Launch helpers for external communication handoff.
///
/// Next Transfer NEVER records an outcome, Timeline claim, or contribution
/// from returning to the app.  The only user-triggered action offered after
/// return is an explicit note the user types themselves.
abstract final class ExternalHandoff {
  /// True when a usable phone or email method exists for a handoff action.
  static bool canLaunch({required String rawValue}) {
    return rawValue.trim().isNotEmpty;
  }

  static String _smsUri(String rawValue) {
    final digits = rawValue.replaceAll(RegExp(r'[^\d+]'), '');
    return 'sms:$digits';
  }

  static String _telUri(String rawValue) {
    final digits = rawValue.replaceAll(RegExp(r'[^\d+]'), '');
    return 'tel:$digits';
  }

  static String _mailUri(String rawValue) {
    return 'mailto:${rawValue.trim()}';
  }

  static Future<bool> launchSms(String rawValue) async {
    return launchUrl(
      Uri.parse(_smsUri(rawValue)),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> launchCall(String rawValue) async {
    return launchUrl(
      Uri.parse(_telUri(rawValue)),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> launchEmail(String rawValue) async {
    return launchUrl(
      Uri.parse(_mailUri(rawValue)),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Mass SMS: one message per selected recipient.
  static Future<bool> launchMassSms(List<String> rawValues) async {
    final phones = <String>[];
    for (final value in rawValues) {
      final digits = value.replaceAll(RegExp(r'[^\d+]'), '');
      if (digits.isNotEmpty && !phones.contains(digits)) {
        phones.add(digits);
      }
    }
    if (phones.isEmpty) {
      return false;
    }
    final uri = Uri.parse('sms:${phones.join(';')}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Shown after any external handoff returns.  States plainly that nothing
  /// was inferred, and offers an optional explicit note.
  static Future<void> showReturnSheet(
    BuildContext context, {
    required String contactDisplayName,
    Future<void> Function(String note)? onAddNote,
  }) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Handoff complete',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Next Transfer did not read the conversation and did not record '
              'anything automatically. Nothing was added to $contactDisplayName\'s '
              'Timeline.',
              style: TextStyle(
                color: AppTheme.secondaryTextOf(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('handoff-note-field'),
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Add a note (optional)',
                hintText: 'Only what you write here is recorded.',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Not now'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    key: const Key('handoff-save-note'),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty && onAddNote != null) {
                        unawaited(onAddNote(text));
                      }
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Save note'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}
