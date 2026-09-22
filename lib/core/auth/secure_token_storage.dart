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
  static const _lastUserIdKey = 'last_user_id';
  static const _lastUserRoleKey = 'last_user_role';
  static const _lastMcuIdKey = 'last_mcu_id';

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
  Future<String?> getLastUserId() => _storage.read(key: _lastUserIdKey);
  Future<String?> getLastUserRole() => _storage.read(key: _lastUserRoleKey);
  Future<int?> getLastMcuId() async {
    final value = await _storage.read(key: _lastMcuIdKey);
    return value == null ? null : int.tryParse(value);
  }

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
      _storage.write(key: _lastUserIdKey, value: userId),
      _storage.write(key: _lastUserRoleKey, value: role),
      if (mcuId == null)
        _storage.delete(key: _mcuIdKey)
      else
        _storage.write(key: _mcuIdKey, value: mcuId.toString()),
      if (mcuId == null)
        _storage.delete(key: _lastMcuIdKey)
      else
        _storage.write(key: _lastMcuIdKey, value: mcuId.toString()),
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

  Future<void> clearCurrentSession() async {
    final currentUserId = await getUserId();
    final currentRole = await getUserRole();
    final currentMcuId = await getMcuId();
    if (currentUserId != null && currentUserId.isNotEmpty) {
      await Future.wait([
        _storage.write(key: _lastUserIdKey, value: currentUserId),
        if (currentRole == null || currentRole.isEmpty)
          _storage.delete(key: _lastUserRoleKey)
        else
          _storage.write(key: _lastUserRoleKey, value: currentRole),
        if (currentMcuId == null)
          _storage.delete(key: _lastMcuIdKey)
        else
          _storage.write(key: _lastMcuIdKey, value: currentMcuId.toString()),
      ]);
    }

    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _userRoleKey),
      _storage.delete(key: _mcuIdKey),
      _storage.delete(key: _mcuNameKey),
    ]);
  }

  // ── Convenience ──────────────────────────────────────────────────────────

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
