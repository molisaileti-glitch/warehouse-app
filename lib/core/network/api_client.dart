// lib/core/network/api_client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/secure_token_storage.dart';
import 'auth_interceptor.dart';
import 'connectivity_interceptor.dart';

const _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://45.77.1.62.nip.io:8096/api/v1',
);

class ApiClient {
  late final Dio dio;

  ApiClient({
    required SecureTokenStorage storage,
    AsyncCallback? onSessionExpired,
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
      ConnectivityInterceptor(),
      AuthInterceptor(
        storage: storage,
        onSessionExpired: onSessionExpired,
      ),
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }
}

class SessionExpiredNotifier extends ChangeNotifier {
  bool _expired = false;

  bool get expired => _expired;

  void expire() {
    if (_expired) return;
    _expired = true;
    notifyListeners();
  }

  void clear() {
    if (!_expired) return;
    _expired = false;
    notifyListeners();
  }
}

final secureStorageProvider = Provider<SecureTokenStorage>(
  (_) => SecureTokenStorage(),
);

final sessionExpiredProvider =
    ChangeNotifierProvider<SessionExpiredNotifier>((ref) {
  return SessionExpiredNotifier();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final sessionExpired = ref.watch(sessionExpiredProvider);
  return ApiClient(
    storage: storage,
    onSessionExpired: () async => sessionExpired.expire(),
  );
});
