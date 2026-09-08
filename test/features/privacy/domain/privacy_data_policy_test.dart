import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/features/privacy/domain/deletion_impact.dart';
import 'package:rmplanner/features/privacy/domain/permission_summary.dart';
import 'package:rmplanner/features/privacy/domain/privacy_data_policy.dart';

void main() {
  test('AC-W-009,010,012..017,020: sensitive data policy is fail-closed', () {
    for (final rule in PrivacyDataPolicy.sensitiveRules) {
      expect(rule.allowedInDiagnostics, isFalse, reason: rule.label);
      expect(rule.allowedInAnalytics, isFalse, reason: rule.label);
      expect(rule.allowedInOutbox, isFalse, reason: rule.label);
      expect(rule.allowedInBackup, isFalse, reason: rule.label);
    }

    expect(
      PrivacyDataPolicy.privateReflection.storageClass,
      PrivacyStorageClass.localOnly,
    );
    expect(
      PrivacyDataPolicy.authenticationToken.storageClass,
      PrivacyStorageClass.secureDeviceStorage,
    );
    expect(PrivacyDataPolicy.optionalSyncedData.allowedInOutbox, isTrue);
  });

  test(
    'AC-W-016,017: permission purposes exclude broad and background access',
    () {
      expect(OptionalPermissionCatalog.values, hasLength(4));
      expect(
        OptionalPermissionCatalog.values.toSet(),
        hasLength(OptionalPermissionCatalog.values.length),
      );
      final purposes = OptionalPermissionCatalog.values
          .map(OptionalPermissionCatalog.purpose)
          .join(' ');
      expect(purposes, contains('does not request background location'));
      expect(purposes.toLowerCase(), isNot(contains('manage all files')));
    },
  );

  test('AC-W-021: deletion impacts keep copies and source files distinct', () {
    final titles = DeletionImpactCatalog.values
        .map((impact) => impact.title)
        .toSet();
    expect(
      titles,
      containsAll(<String>{
        'Local app data',
        'Optional synced data',
        'Backups',
        'Source files',
      }),
    );
  });
}
