// lib/core/repositories/auth_repository.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/secure_token_storage.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../network/api_client.dart';
import '../enums/sync_status.dart';

class AuthRepository {
  final Dio _dio;
  final SecureTokenStorage _storage;
  final WorkerDao _workerDao;

  AuthRepository({
    required Dio dio,
    required SecureTokenStorage storage,
    required WorkerDao workerDao,
  })  : _dio = dio,
        _storage = storage,
        _workerDao = workerDao;

  // ── Register (owner only) ─────────────────────────────────────────────────

  Future<RegistrationResult> register(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/mcus', data: data);
      final responseData = res.data;
      if (responseData is! Map<String, dynamic>) {
        return RegistrationResult.failure('errorInvalidServerResponse');
      }

      final mcuId = _int(responseData['id']);
      if (mcuId == null || mcuId <= 0) {
        return RegistrationResult.failure('errorInvalidServerResponse');
      }

      return RegistrationResult.success(mcuId: mcuId);
    } on DioException catch (e) {
      return RegistrationResult.failure(_dioMessage(e));
    } catch (_) {
      return RegistrationResult.failure('errorInvalidServerResponse');
    }
  }

  // ── Create worker (owner adds workers from inside the app) ────────────────
  //
  // POST /auth/signup
  // Called from the Add Worker screen inside the owner shell.
  //
  // Field mapping:
  //   fullName     → typed by owner
  //   email        → typed by owner
  //   phoneNumber  → typed by owner
  //   password     → typed by owner
  //   role         → always 'AMCOS_USER' (hardcoded)
  //   mcu          → logged-in owner's numeric ID (derived by caller from currentUserId)
  //   amcos        → amcos ID pulled off the warehouse record the owner selected

  Future<CreateUserResult> createUser({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required int mcu,
    required int amcos,
  }) async {
    try {
      final res = await _dio.post('/auth/signup', data: {
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
        'role': 'AMCOS_USER',
        'mcu': mcu,
        'amcos': amcos,
      });

      final data = res.data as Map<String, dynamic>;
      return CreateUserResult.success(
        message: data['message'] as String? ?? 'User registered successfully',
        email: data['email'] as String? ?? email,
        status: data['status'] as String? ?? 'ACTIVE',
      );
    } on DioException catch (e) {
      return CreateUserResult.failure(_dioMessage(e));
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        'channel': 'MOBILE',
        'deviceId': '1',
        'appVersion': '1',
      });

      final data = res.data;
      if (data is! Map<String, dynamic>) {
        return AuthResult.failure('errorInvalidServerResponse');
      }

      final accessToken = _nullableString(data['token']);
      final refreshToken = _nullableString(data['refreshToken']);
      final userValue = data['user'];
      if (accessToken == null ||
          refreshToken == null ||
          userValue is! Map<String, dynamic>) {
        return AuthResult.failure('errorInvalidServerResponse');
      }

      final user = userValue;
      final userId = _nullableString(user['id']);
      final roleStr = _nullableString(user['role']);
      if (userId == null || roleStr == null) {
        return AuthResult.failure('errorInvalidServerResponse');
      }

      final mcuData = data['mcu'];
      final mcu = mcuData is Map<String, dynamic> ? mcuData : null;
      final mcuId = _int(mcu?['id'] ?? user['mcu']);
      final mcuName = _nullableString(
        mcu?['mcuName'] ?? mcu?['name'] ?? user['mcuName'],
      );
      final mcuAmcosId = _int(
        user['amcos'] ??
            user['amcosId'] ??
            user['amcos_id'] ??
            _assignmentId(mcu?['amcos']),
      );
      final parsedRole = UserRole.fromString(roleStr);
      if ((parsedRole == UserRole.owner || parsedRole == UserRole.superAdmin) &&
          mcuId == null) {
        return AuthResult.failure('errorMissingMcuAssignment');
      }

      final emailValue = _string(user['email'] ?? email);

      await _storage.saveTokens(
          accessToken: accessToken, refreshToken: refreshToken);
      await _storage.saveUserInfo(
        userId: userId,
        role: roleStr,
        mcuId: mcuId,
        mcuName: mcuName,
      );
      await _upsertLoggedInUser(
        user: user,
        userId: userId,
        email: emailValue,
        role: roleStr,
        mcuId: mcuId,
        amcosId: mcuAmcosId,
      );

      return AuthResult.success(
        userId: userId,
        role: parsedRole,
        mcuId: mcuId,
        mcuName: mcuName,
      );
    } on DioException catch (e) {
      return AuthResult.failure(_dioMessage(e));
    } catch (_) {
      return AuthResult.failure('errorInvalidServerResponse');
    }
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  Future<PasswordActionResult> forgotPassword({required String email}) async {
    try {
      final res = await _dio.post('/auth/forgot-password', data: {
        'email': email,
      });
      final data = res.data as Map<String, dynamic>;
      return PasswordActionResult.success(
        message: data['message'] as String? ??
            'Password reset instructions have been sent to your email',
        email: data['email'] as String? ?? email,
      );
    } on DioException catch (e) {
      return PasswordActionResult.failure(_dioMessage(e));
    }
  }

  Future<PasswordActionResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post('/auth/reset-password', data: {
        'token': token,
        'newPassword': newPassword,
      });
      final data = res.data as Map<String, dynamic>;
      return PasswordActionResult.success(
        message: data['message'] as String? ??
            'Password has been reset successfully',
      );
    } on DioException catch (e) {
      return PasswordActionResult.failure(_dioMessage(e));
    }
  }

  Future<PasswordActionResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _dio.post('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      final data = res.data as Map<String, dynamic>;
      return PasswordActionResult.success(
        message: data['message'] as String? ?? 'Password changed successfully',
      );
    } on DioException catch (e) {
      return PasswordActionResult.failure(_dioMessage(e));
    }
  }

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final res = await _dio.post('/auth/refresh-token', data: {
        'refreshToken': refreshToken,
      });

      final responseData = res.data;
      if (responseData is! Map<String, dynamic>) return false;

      final accessToken = responseData['token'];
      final rotatedRefreshToken = responseData['refreshToken'];
      if (accessToken is! String || accessToken.isEmpty) return false;

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken:
            rotatedRefreshToken is String && rotatedRefreshToken.isNotEmpty
                ? rotatedRefreshToken
                : refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } catch (_) {
      // Best-effort server revocation — always clear locally regardless.
    } finally {
      await _storage.clearAll();
    }
  }

  // ── Session check ─────────────────────────────────────────────────────────

  Future<SessionState> checkSession() async {
    final hasTokens = await _storage.hasTokens();
    if (!hasTokens) return SessionState.unauthenticated;

    final userId = await _storage.getUserId();
    final role = await _storage.getUserRole();
    if (userId == null || role == null) return SessionState.unauthenticated;

    return SessionState.authenticated(
      userId: userId,
      role: UserRole.fromString(role),
    );
  }

  // ── Error messages ────────────────────────────────────────────────────────

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      for (final key in const ['detail', 'message', 'error', 'errors']) {
        final value = data[key];
        if (value != null) return value.toString();
      }
    }
    return switch (e.response?.statusCode) {
      400 => 'errorInvalidDetails',
      401 => 'errorIncorrectCredentials',
      403 => 'errorAccountDisabled',
      409 => 'errorEmailExists',
      429 => 'errorTooManyAttempts',
      _ => 'errorNetworkError',
    };
  }

  Future<void> _upsertLoggedInUser({
    required Map<String, dynamic> user,
    required String userId,
    required String email,
    required String role,
    int? mcuId,
    int? amcosId,
  }) async {
    if (userId.isEmpty || email.isEmpty) return;

    final existingById = await _workerDao.getUserById(userId);
    final existingByEmail = await _workerDao.getUserByEmail(email);
    final assignmentSource = existingById ?? existingByEmail;

    final fullName = _string(
      user['fullName'] ??
          user['full_name'] ??
          user['name'] ??
          assignmentSource?.fullName ??
          email,
    );
    final phoneNumber = _string(
      user['phoneNumber'] ??
          user['phone_number'] ??
          assignmentSource?.phoneNumber,
    );
    final warehouseId = _nullableString(
          _assignmentId(
                user['warehouseId'] ??
                    user['warehouse_id'] ??
                    user['collectionCenterId'] ??
                    user['collection_center_id'] ??
                    user['collectionCenter'] ??
                    user['warehouse'],
              ) ??
              assignmentSource?.warehouseId,
        ) ??
        assignmentSource?.warehouseId;
    final mcu = mcuId ?? _int(user['mcu']) ?? assignmentSource?.mcu;
    final userAmcosValue = user['amcos'] ?? user['amcosId'] ?? user['amcos_id'];
    final amcos = _int(userAmcosValue) ??
        _int(_assignmentId(userAmcosValue)) ??
        amcosId ??
        assignmentSource?.amcos;

    if (existingByEmail != null && existingByEmail.id != userId) {
      await _workerDao.deleteUserById(existingByEmail.id);
    }

    await _workerDao.upsertUser(
      UsersCompanion.insert(
        id: userId,
        fullName: fullName.isEmpty ? email : fullName,
        email: email,
        phoneNumber: Value(phoneNumber),
        role: Value(role),
        mcu: Value(mcu),
        amcos: Value(amcos),
        warehouseId: Value(warehouseId),
        isActive: Value(_isActiveStatus(user['status']?.toString())),
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  bool _isActiveStatus(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == null ||
        normalized.isEmpty ||
        normalized == 'active' ||
        normalized == 'enabled';
  }

  int? _int(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _string(Object? value) => value?.toString().trim() ?? '';

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _assignmentId(Object? value) {
    if (value is Map) {
      return _nullableString(
        value['id'] ?? value['warehouseId'] ?? value['collectionCenterId'],
      );
    }
    return _nullableString(value);
  }
}

// ── Value objects ─────────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final String? error;
  final String? userId;
  final UserRole? role;
  final int? mcuId;
  final String? mcuName;

  const AuthResult._({
    required this.success,
    this.error,
    this.userId,
    this.role,
    this.mcuId,
    this.mcuName,
  });

  factory AuthResult.success({
    required String userId,
    required UserRole role,
    int? mcuId,
    String? mcuName,
  }) =>
      AuthResult._(
        success: true,
        userId: userId,
        role: role,
        mcuId: mcuId,
        mcuName: mcuName,
      );

  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);
}

class RegistrationResult {
  final bool success;
  final String? error;
  final int? mcuId;

  const RegistrationResult._({
    required this.success,
    this.error,
    this.mcuId,
  });

  factory RegistrationResult.success({required int mcuId}) =>
      RegistrationResult._(success: true, mcuId: mcuId);

  factory RegistrationResult.failure(String error) =>
      RegistrationResult._(success: false, error: error);
}

class CreateUserResult {
  final bool success;
  final String? error;
  final String? message;
  final String? email;
  final String? status;

  const CreateUserResult._({
    required this.success,
    this.error,
    this.message,
    this.email,
    this.status,
  });

  factory CreateUserResult.success({
    required String message,
    required String email,
    required String status,
  }) =>
      CreateUserResult._(
        success: true,
        message: message,
        email: email,
        status: status,
      );

  factory CreateUserResult.failure(String error) =>
      CreateUserResult._(success: false, error: error);
}

class PasswordActionResult {
  final bool success;
  final String? error;
  final String? message;
  final String? email;

  const PasswordActionResult._({
    required this.success,
    this.error,
    this.message,
    this.email,
  });

  factory PasswordActionResult.success({
    required String message,
    String? email,
  }) =>
      PasswordActionResult._(
        success: true,
        message: message,
        email: email,
      );

  factory PasswordActionResult.failure(String error) =>
      PasswordActionResult._(success: false, error: error);
}

class SessionState {
  final bool isAuthenticated;
  final String? userId;
  final UserRole? role;

  const SessionState._({required this.isAuthenticated, this.userId, this.role});

  static const unauthenticated = SessionState._(isAuthenticated: false);

  factory SessionState.authenticated({
    required String userId,
    required UserRole role,
  }) =>
      SessionState._(isAuthenticated: true, userId: userId, role: role);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(
    dio: client.dio,
    storage: storage,
    workerDao: ref.watch(workerDaoProvider),
  );
});
