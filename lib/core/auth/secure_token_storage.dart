// lib/core/auth/secure_token_storage.dart
//
// All token read/write goes through this class — never raw SharedPreferences.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userRoleKey = 'user_role';
  static const _mcuIdKey = 'mcu_id';
  static const _mcuNameKey = 'mcu_name';

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
  Future<int?> getMcuId() async {
    final value = await _storage.read(key: _mcuIdKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<String?> getMcuName() => _storage.read(key: _mcuNameKey);

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
    int? mcuId,
    String? mcuName,
  }) async {
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _userRoleKey, value: role),
      if (mcuId == null)
        _storage.delete(key: _mcuIdKey)
      else
        _storage.write(key: _mcuIdKey, value: mcuId.toString()),
      if (mcuName == null || mcuName.isEmpty)
        _storage.delete(key: _mcuNameKey)
      else
        _storage.write(key: _mcuNameKey, value: mcuName),
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
