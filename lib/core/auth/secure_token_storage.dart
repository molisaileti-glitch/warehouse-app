// lib/core/auth/secure_token_storage.dart
//
// All token read/write goes through this class — never raw SharedPreferences.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';

  final FlutterSecureStorage _storage;

  SecureTokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
          ),
        );

  // ── Accessors ────────────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);
  Future<String?> getUserId() => _storage.read(key: _userIdKey);
  Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  // ── Writers ──────────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  Future<void> saveUserInfo({
    required String userId,
    required String role,
  }) async {
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _userRoleKey, value: role),
    ]);
  }

  Future<void> updateAccessToken(String accessToken) =>
      _storage.write(key: _accessKey, value: accessToken);

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();

  // ── Convenience ──────────────────────────────────────────────────────────

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}