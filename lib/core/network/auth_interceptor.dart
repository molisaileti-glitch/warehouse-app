// lib/core/network/auth_interceptor.dart
//
// Attaches Authorization headers. If a protected endpoint returns 401,
// the stored session is cleared so the router can force the user to log in.
// A 403 can also mean "logged in but not allowed", so we keep the session.

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../auth/secure_token_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureTokenStorage _storage;
  final AsyncCallback? _onSessionExpired;

  bool _isInvalidatingSession = false;

  AuthInterceptor({
    required SecureTokenStorage storage,
    AsyncCallback? onSessionExpired,
  })  : _storage = storage,
        _onSessionExpired = onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicAuthEndpoint(options.path)) {
      handler.next(options);
      return;
    }

    final token = await _storage.getAccessToken();
    if (token != null) {
      if (_isExpiredJwt(token)) {
        _log('stored access token is expired; forcing login before request');
        await _forceLogin();
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              statusMessage: 'Session expired',
            ),
            type: DioExceptionType.badResponse,
            error: 'Session expired',
          ),
        );
        return;
      }
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    _log(
      'error status=${err.response?.statusCode} path=${err.requestOptions.path} '
      'forceLogin=${_shouldForceLogin(err)}',
    );

    if (_shouldForceLogin(err) &&
        !_isPublicAuthEndpoint(err.requestOptions.path)) {
      await _forceLogin();
    }

    handler.next(err);
  }

  bool _shouldForceLogin(DioException err) {
    final statusCode = err.response?.statusCode;
    return statusCode == 401 ||
        (statusCode == 403 && _requestUsedExpiredBearer(err.requestOptions));
  }

  bool _isPublicAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password');
  }

  bool _isExpiredJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      final payloadJson = utf8.decode(base64Url.decode(
        base64Url.normalize(parts[1]),
      ));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map<String, dynamic>) return false;

      final exp = payload['exp'];
      final expSeconds = exp is num ? exp.toInt() : int.tryParse('$exp');
      if (expSeconds == null) return false;

      const leewaySeconds = 30;
      final expiresAtMs = (expSeconds - leewaySeconds) * 1000;
      return DateTime.now().millisecondsSinceEpoch >= expiresAtMs;
    } catch (_) {
      return false;
    }
  }

  bool _requestUsedExpiredBearer(RequestOptions options) {
    final authorization = options.headers['Authorization']?.toString();
    const prefix = 'Bearer ';
    if (authorization == null || !authorization.startsWith(prefix)) {
      return false;
    }
    return _isExpiredJwt(authorization.substring(prefix.length).trim());
  }

  Future<void> _forceLogin() async {
    if (_isInvalidatingSession) return;
    _isInvalidatingSession = true;
    try {
      _log('clearing stored session and forcing login');
      await _storage.clearAll();
      await _onSessionExpired?.call();
    } finally {
      _isInvalidatingSession = false;
    }
  }

  void _log(String message) {
    developer.log('[AuthInterceptor] $message', name: 'auth.session');
  }
}
