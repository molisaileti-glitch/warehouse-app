// lib/core/network/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/secure_token_storage.dart';
import 'auth_interceptor.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://45.77.1.62.nip.io:8096/api/v1',
);

class ApiClient {
  late final Dio dio;

  ApiClient({
    required SecureTokenStorage storage,
    required Future<bool> Function() onRefresh,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, storage: storage, onRefresh: onRefresh),
      LogInterceptor(
        requestBody: false, // set true during dev only
        responseBody: false,
        error: true,
      ),
    ]);
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureTokenStorage>(
  (_) => SecureTokenStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    storage: storage,
    onRefresh: () async {
      // Calls the auth repository's refresh — circular dependency avoided
      // by reading the provider lazily at call-time.
      final repo = ref.read(authRepositoryProvider);
      return repo.refreshToken();
    },
  );
});

// Forward declaration — implemented in auth_repository.dart.
// Needed here to break the circular dep between ApiClient ↔ AuthRepository.
late final Provider<dynamic> authRepositoryProvider;