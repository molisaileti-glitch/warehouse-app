import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  static const noConnectionMessage =
      'No internet connection. Turn on mobile data or Wi-Fi and try again.';
  static const weakConnectionMessage =
      'Connection is weak or the server cannot be reached. Please try again.';
  static const timeoutMessage =
      'Request timed out. Please check your connection and try again.';

  final Connectivity _connectivity;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final results = await _connectivity.checkConnectivity();
    final hasNetwork =
        results.any((result) => result != ConnectivityResult.none);

    if (!hasNetwork) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: noConnectionMessage,
          error: const NoInternetConnectionException(),
        ),
      );
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = switch (err.type) {
      DioExceptionType.connectionError
          when err.error is NoInternetConnectionException =>
        noConnectionMessage,
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        timeoutMessage,
      DioExceptionType.connectionError => weakConnectionMessage,
      _ => err.message,
    };

    if (message == null || message == err.message) {
      return handler.next(err);
    }

    return handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: err.error,
        stackTrace: err.stackTrace,
        message: message,
      ),
    );
  }
}

class NoInternetConnectionException implements Exception {
  const NoInternetConnectionException();
}
