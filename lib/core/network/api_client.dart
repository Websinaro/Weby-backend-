import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

/// Centralized HTTP client for every backend call the app makes.
///
/// Responsibilities:
///  - attaches the Authorization header automatically
///  - transparently refreshes an expired access token and retries the
///    original request exactly once
///  - queues concurrent requests that hit a 401 at the same time so they
///    all wait for a single in-flight refresh instead of firing N refreshes
///  - normalizes every error into an [ApiException]
///  - logs requests only in debug builds, and never logs the
///    Authorization header even then
class ApiClient {
  ApiClient(this._secureStorage, {this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          // Never print headers - avoids ever printing Authorization,
          // even accidentally, in development logs.
          requestHeader: false,
          responseHeader: false,
        ),
      );
    }
  }

  late final Dio _dio;
  final SecureStorageService _secureStorage;

  /// Called when the refresh token itself is invalid/expired - the app
  /// should clear local session state and route back to login.
  final VoidCallback? onSessionExpired;

  bool _isRefreshing = false;
  final List<Completer<void>> _refreshWaiters = [];

  Dio get raw => _dio;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!options.extra.containsKey('noAuth')) {
      final token = await _secureStorage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final response = error.response;
    final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
    final alreadyRetried = error.requestOptions.extra['retried'] == true;

    if (response?.statusCode == 401 && !isAuthEndpoint && !alreadyRetried) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        try {
          final retryResponse = await _retry(error.requestOptions);
          return handler.resolve(retryResponse);
        } catch (_) {
          // fall through to normal error handling below
        }
      } else {
        onSessionExpired?.call();
      }
    }

    return handler.next(error);
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    requestOptions.extra['retried'] = true;
    return _dio.fetch(requestOptions);
  }

  /// Ensures only ONE refresh call is ever in flight, even if several
  /// requests fail with 401 at the same moment. Everyone else awaits it.
  Future<bool> _refreshAccessToken() async {
    if (_isRefreshing) {
      final completer = Completer<void>();
      _refreshWaiters.add(completer);
      await completer.future;
      return (await _secureStorage.getAccessToken()) != null;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'noAuth': true}),
      );

      final data = response.data['data'];
      await _secureStorage.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );
      return true;
    } catch (_) {
      await _secureStorage.clearTokens();
      return false;
    } finally {
      _isRefreshing = false;
      for (final waiter in _refreshWaiters) {
        if (!waiter.isCompleted) waiter.complete();
      }
      _refreshWaiters.clear();
    }
  }

  /// Unwraps { success, data } / { success, error } and throws a typed
  /// [ApiException] on failure, so callers only ever deal with plain data
  /// or a catchable exception - never raw Dio/HTTP details.
  Future<T> request<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data) parse,
  ) async {
    try {
      final response = await call();
      final body = response.data;
      if (body is Map && body['success'] == true) {
        return parse(body['data']);
      }
      throw ApiException(
        message: body?['error']?['message'] ?? 'Unexpected response from server',
        code: body?['error']?['code'] ?? 'UNKNOWN_ERROR',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final errorBody = e.response?.data;
      if (errorBody is Map && errorBody['error'] != null) {
        throw ApiException(
          message: errorBody['error']['message'] ?? 'Something went wrong',
          code: errorBody['error']['code'] ?? 'UNKNOWN_ERROR',
          statusCode: e.response?.statusCode,
        );
      }
      throw ApiException(
        message: e.type == DioExceptionType.connectionTimeout ||
                e.type == DioExceptionType.receiveTimeout
            ? 'Could not reach Weby. Check your connection and try again.'
            : (e.message ?? 'Network error'),
        code: 'NETWORK_ERROR',
      );
    }
  }
}
