import 'package:flutter_test/flutter_test.dart';
import 'package:rmplanner/core/security/auth_token_store.dart';

import '../../support/test_dependencies.dart';

void main() {
  test('AC-W-011: tokens round-trip only through secure storage', () async {
    final driver = MemorySecureStorageDriver();
    final store = SecureAuthTokenStore(driver);

    await store.write(
      const AuthTokens(
        accessToken: 'access-secret',
        refreshToken: 'refresh-secret',
      ),
    );
    final restored = await store.read();

    expect(restored?.accessToken, 'access-secret');
    expect(restored?.refreshToken, 'refresh-secret');
    expect(driver.values.values.single, contains('access-secret'));

    await store.delete();
    expect(await store.read(), isNull);
  });

  test('AC-W-011: secure-storage failure has no insecure fallback', () async {
    final driver = MemorySecureStorageDriver()
      ..writeFailure = StateError('Injected secure storage failure');
    final store = SecureAuthTokenStore(driver);

    await expectLater(
      store.write(
        const AuthTokens(accessToken: 'access', refreshToken: 'refresh'),
      ),
      throwsStateError,
    );

    expect(driver.values, isEmpty);
  });
}
