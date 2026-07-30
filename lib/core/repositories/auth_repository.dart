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
  })
      : _dio = dio,
        _storage = storage,
        _workerDao = workerDao;

  // ── Register (owner only) ─────────────────────────────────────────────────

  Future<AuthResult> register(Map<String, dynamic> data) async {
    try {
      final res = await _dio.post('/mcus', data: data);

      final responseData = res.data as Map<String, dynamic>;
      final accessToken = responseData['token'] as String? ?? 'mock-register-token';
      final refreshToken = responseData['refreshToken'] as String? ?? 'mock-register-refresh-token';
      final userId = (responseData['id'] ?? '4').toString();
      const userRole = 'owner';

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      await _storage.saveUserInfo(
        userId: userId,
        role: userRole,
      );

      return AuthResult.success(
        userId: userId,
        role: UserRole.fromString(userRole),
      );
    } on DioException catch (e) {
      return AuthResult.failure(_dioMessage(e));
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

      final data = res.data as Map<String, dynamic>;

      final accessToken = data['token'] as String;
      final refreshToken = data['refreshToken'] as String;
      final user = data['user'] as Map<String, dynamic>;
      final userId = (user['id'] ?? '').toString();
      final roleStr = user['role'] as String;
      final emailValue = _string(user['email'] ?? email);

      await _storage.saveTokens(
          accessToken: accessToken, refreshToken: refreshToken);
      await _storage.saveUserInfo(
        userId: userId,
        role: roleStr,
      );
      await _upsertLoggedInUser(
        user: user,
        userId: userId,
        email: emailValue,
        role: roleStr,
      );

      return AuthResult.success(
        userId: userId,
        role: UserRole.fromString(roleStr),
      );
    } on DioException catch (e) {
      return AuthResult.failure(_dioMessage(e));
    }
  }

  // ── Refresh token ─────────────────────────────────────────────────────────

  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final res = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final data = res.data as Map<String, dynamic>;
      await _storage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
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
          user['warehouseId'] ??
              user['warehouse_id'] ??
              user['warehouse'] ??
              assignmentSource?.warehouseId,
        ) ??
        assignmentSource?.warehouseId;
    final mcu = _int(user['mcu']) ?? assignmentSource?.mcu;
    final amcos = _int(user['amcos']) ?? assignmentSource?.amcos;

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
}

// ── Value objects ─────────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final String? error;
  final String? userId;
  final UserRole? role;

  const AuthResult._({
    required this.success,
    this.error,
    this.userId,
    this.role,
  });

  factory AuthResult.success({required String userId, required UserRole role}) =>
      AuthResult._(success: true, userId: userId, role: role);

  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);
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
