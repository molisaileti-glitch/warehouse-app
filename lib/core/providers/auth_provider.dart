// lib/core/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../network/api_client.dart' show secureStorageProvider;
import '../repositories/auth_repository.dart';
import '../enums/sync_status.dart';
// ── State ─────────────────────────────────────────────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final UserRole? role;
  final String? error;

  const AuthState({
    required this.status,
    this.userId,
    this.role,
    this.error,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);
  const AuthState.authenticated(
      {required String userId, required UserRole role})
      : this(status: AuthStatus.authenticated, userId: userId, role: role);

  bool get isOwner => role == UserRole.owner || role == UserRole.superAdmin;
  bool get isWorker => role == UserRole.worker;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<AuthState> {
  late AuthRepository _repo;

  @override
  Future<AuthState> build() async {
    _repo = ref.watch(authRepositoryProvider);
    return _restoreSession();
  }

  Future<AuthState> _restoreSession() async {
    final session = await _repo.checkSession();
    if (session.isAuthenticated) {
      return AuthState.authenticated(
        userId: session.userId!,
        role: session.role!,
      );
    }
    return const AuthState.unauthenticated();
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.data(AuthState.loading());
    final result = await _repo.login(email: email, password: password);

    if (result.success) {
      state = AsyncValue.data(
          AuthState.authenticated(userId: result.userId!, role: result.role!));
    } else {
      state = AsyncValue.data(AuthState.unauthenticated(error: result.error));
    }
  }

  // ── Register (owner first-time setup) ─────────────────────────────────────

  Future<RegistrationResult> register(Map<String, dynamic> data) async {
    state = const AsyncValue.data(AuthState.loading());
    final result = await _repo.register(data);
    state = AsyncValue.data(
      AuthState.unauthenticated(error: result.success ? null : result.error),
    );
    return result;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    state = const AsyncValue.data(AuthState.loading());
    await _repo.logout();
    state = const AsyncValue.data(AuthState.unauthenticated());
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).valueOrNull?.userId;
});

final currentRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).valueOrNull?.role;
});

final currentUserMcuProvider = FutureProvider<int?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final storedMcuId = await ref.watch(secureStorageProvider).getMcuId();
  if (storedMcuId != null) return storedMcuId;
  final user = await ref.watch(workerDaoProvider).getUserById(userId);
  return user?.mcu;
});
