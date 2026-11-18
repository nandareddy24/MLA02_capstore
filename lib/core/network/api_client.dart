import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/preferences_service.dart';
import '../../data/services/secure_storage_service.dart';
import '../config/app_config.dart';
import '../constants/app_constants.dart';
import '../errors/app_exception.dart';

/// Configured Dio HTTP client with environment-safe base URL resolution,
/// HTTPS enforcement in production builds, signed Bearer JWT injection,
/// and expired-session notification hooks.
class ApiClient {
  ApiClient({
    required PreferencesService preferencesService,
    required SecureStorageService secureStorageService,
    Dio? dio,
  })  : _preferencesService = preferencesService,
        _secureStorageService = secureStorageService,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: AppConstants.connectTimeout,
                receiveTimeout: AppConstants.receiveTimeout,
                sendTimeout: AppConstants.sendTimeout,
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _configureInterceptors();
  }

  final PreferencesService _preferencesService;
  final SecureStorageService _secureStorageService;
  final Dio _dio;

  /// Optional callback invoked when a protected endpoint responds with HTTP 401.
  VoidCallback? onSessionExpired;

  /// Resolves the active API base URL.
  ///
  /// In production/release builds, runtime overrides are ignored if they violate
  /// HTTPS / non-localhost transport rules.
  String get baseUrl {
    final runtimeOverride = _preferencesService.apiBaseUrl;
    if (runtimeOverride != null && runtimeOverride.trim().isNotEmpty) {
      final normalized = _normalizeBaseUrl(runtimeOverride);
      if (!AppConfig.isProduction ||
          AppConfig.validateApiBaseUrl(normalized) == null) {
        return normalized;
      }
    }
    return _normalizeBaseUrl(
      AppConfig.compileTimeApiBaseUrl.isNotEmpty
          ? AppConfig.compileTimeApiBaseUrl
          : AppConstants.defaultApiBaseUrl,
    );
  }

  bool get isConfigured =>
      baseUrl.isNotEmpty && AppConfig.validateApiBaseUrl(baseUrl) == null;

  void _configureInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final currentBaseUrl = baseUrl;
          final validationError = AppConfig.validateApiBaseUrl(currentBaseUrl);
          if (validationError != null && !options.path.startsWith('http')) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: ServiceUnavailableException(validationError),
                message: validationError,
              ),
            );
            return;
          }

          if (currentBaseUrl.isNotEmpty) {
            options.baseUrl = currentBaseUrl;
          }

          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth) {
            final token = await _secureStorageService.readAuthToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) {
          final statusCode = error.response?.statusCode;
          final skipAuth = error.requestOptions.extra['skipAuth'] == true;
          if (statusCode == 401 && !skipAuth) {
            onSessionExpired?.call();
          }

          if (kDebugMode) {
            debugPrint(
              '[ApiClient] ${error.requestOptions.method} '
              '${error.requestOptions.uri} -> ${error.type}: ${error.message}',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) async {
    _ensureConfigured();
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) async {
    _ensureConfigured();
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) async {
    _ensureConfigured();
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) async {
    _ensureConfigured();
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    bool skipAuth = false,
  }) async {
    _ensureConfigured();
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: Options(extra: {'skipAuth': skipAuth}),
    );
  }

  void _ensureConfigured() {
    final validationError = AppConfig.validateApiBaseUrl(baseUrl);
    if (validationError != null) {
      throw ServiceUnavailableException(
        '$validationError Configure a valid FixWise backend server URL.',
      );
    }
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
