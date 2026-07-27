import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

abstract interface class AuthTokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> delete();
}

abstract interface class SecureStorageDriver {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

final class FlutterSecureStorageDriver implements SecureStorageDriver {
  FlutterSecureStorageDriver()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: false,
          storageNamespace: 'next_transfer_auth_tokens',
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

final class SecureAuthTokenStore implements AuthTokenStore {
  const SecureAuthTokenStore(this._storage);

  static const String _tokenBundleKey = 'account_token_bundle';

  final SecureStorageDriver _storage;

  @override
  Future<void> delete() => _storage.delete(key: _tokenBundleKey);

  @override
  Future<AuthTokens?> read() async {
    final encoded = await _storage.read(key: _tokenBundleKey);
    if (encoded == null) {
      return null;
    }
    final value = jsonDecode(encoded);
    if (value is! Map<String, Object?>) {
      throw const FormatException('Secure token bundle is malformed');
    }
    final accessToken = value['access_token'];
    final refreshToken = value['refresh_token'];
    if (accessToken is! String || refreshToken is! String) {
      throw const FormatException('Secure token bundle is incomplete');
    }
    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> write(AuthTokens tokens) {
    final encoded = jsonEncode(<String, String>{
      'access_token': tokens.accessToken,
      'refresh_token': tokens.refreshToken,
    });
    return _storage.write(key: _tokenBundleKey, value: encoded);
  }
}
