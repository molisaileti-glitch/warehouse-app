// lib/core/network/auth_interceptor.dart
//
// Attaches Authorization header on every request.
// On 401: pauses queue, refreshes token, replays all queued requests.

import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/secure_token_storage.dart';

class AuthInterceptor extends Interceptor {
  final Dio _dio;
  final SecureTokenStorage _storage;
  final Future<bool> Function() _onRefresh;

  // Prevents multiple simultaneous refresh calls.
  bool _isRefreshing = false;
  final List<_PendingRequest> _queue = [];

  AuthInterceptor({
    required Dio dio,
    required SecureTokenStorage storage,
    required Future<bool> Function() onRefresh,
  })  : _dio = dio,
        _storage = storage,
        _onRefresh = onRefresh;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    // Skip refresh loop for the refresh endpoint itself.
    if (err.requestOptions.path.contains('/auth/refresh')) {
      handler.next(err);
      return;
    }

    if (_isRefreshing) {
      // Queue request until refresh completes.
      final completer = Completer<Response>();
      _queue.add(_PendingRequest(err.requestOptions, completer));
      try {
        handler.resolve(await completer.future);
      } catch (e) {
        handler.next(err);
      }
      return;
    }

    _isRefreshing = true;
    final success = await _onRefresh();

    if (success) {
      // Replay the failed request with the new token.
      final newToken = await _storage.getAccessToken();

      // Resolve all queued requests.
      for (final pending in _queue) {
        pending.options.headers['Authorization'] = 'Bearer $newToken';
        try {
          final response = await _dio.fetch(pending.options);
          pending.completer.complete(response);
        } catch (e) {
          pending.completer.completeError(e);
        }
      }
      _queue.clear();
      _isRefreshing = false;

      // Replay original request.
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      try {
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
      } catch (e) {
        handler.next(err);
      }
    } else {
      // Refresh failed — reject all queued requests.
      for (final pending in _queue) {
        pending.completer.completeError(err);
      }
      _queue.clear();
      _isRefreshing = false;
      handler.next(err);
    }
  }
}

class _PendingRequest {
  final RequestOptions options;
  final Completer<Response> completer;
  _PendingRequest(this.options, this.completer);
}
