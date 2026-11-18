import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/user_profile_model.dart';
import '../services/local_database_service.dart';
import '../services/preferences_service.dart';
import '../services/secure_storage_service.dart';

/// Result returned when restoring an existing authentication session on startup.
class SessionRestoreResult {
  const SessionRestoreResult({
    this.user,
    this.wasExpired = false,
  });

  final UserProfileModel? user;
  final bool wasExpired;
}

/// Result returned by login/registration/OTP verification endpoints.
class AuthFlowResult {
  const AuthFlowResult({
    this.user,
    this.requiresOtpVerification = false,
    this.email,
    this.message,
  });

  final UserProfileModel? user;
  final bool requiresOtpVerification;
  final String? email;
  final String? message;
}

/// Contract for real backend authentication, OTP verification, password reset,
/// and secure token-backed session management.
abstract interface class AuthRepository {
  Future<Result<SessionRestoreResult>> restoreSession();

  Future<Result<AuthFlowResult>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  });

  Future<Result<AuthFlowResult>> register({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  });

  Future<Result<String>> sendOtp({
    required String email,
    required String purpose,
  });

  Future<Result<AuthFlowResult>> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  });

  Future<Result<String>> requestPasswordReset({
    required String email,
  });

  Future<Result<String>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<Result<UserProfileModel>> updateProfile({
    required String fullName,
    required String role,
  });

  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Result<void>> signOut();
}

/// Production authentication repository communicating exclusively with the
/// configured FixWise backend API. Never accepts arbitrary local credentials
/// and never generates or validates OTP codes locally.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required ApiClient apiClient,
    required LocalDatabaseService databaseService,
    required PreferencesService preferencesService,
    required SecureStorageService secureStorageService,
  })  : _apiClient = apiClient,
        _databaseService = databaseService,
        _preferencesService = preferencesService,
        _secureStorageService = secureStorageService;

  final ApiClient _apiClient;
  final LocalDatabaseService _databaseService;
  final PreferencesService _preferencesService;
  final SecureStorageService _secureStorageService;

  static const AuthFailure _serviceNotConfiguredFailure = AuthFailure(
    'Authentication service is not configured. Configure your FixWise backend API URL to authenticate.',
    code: 'AUTH_BACKEND_NOT_CONFIGURED',
  );

  @override
  Future<Result<SessionRestoreResult>> restoreSession() async {
    try {
      final token = await _secureStorageService.readAuthToken();
      if (token == null || token.isEmpty) {
        return const Success(SessionRestoreResult());
      }

      // Respect the user's "Remember me" setting across cold app restarts.
      if (!_preferencesService.rememberMe) {
        await _clearLocalSession();
        return const Success(SessionRestoreResult());
      }

      final expiresAt = await _secureStorageService.readTokenExpiresAt();
      final isLocallyExpired =
          expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt);

      if (isLocallyExpired) {
        final refreshed = await _attemptTokenRefresh();
        if (!refreshed) {
          await _clearLocalSession();
          return const Success(SessionRestoreResult(wasExpired: true));
        }
      }

      if (_apiClient.isConfigured) {
        try {
          final response = await _apiClient.get<Map<String, dynamic>>(
            ApiEndpoints.profile,
          );
          final body = response.data ?? const <String, dynamic>{};
          final userJson = body['user'] is Map<String, dynamic>
              ? body['user'] as Map<String, dynamic>
              : body;
          final user = UserProfileModel.fromJson(userJson);
          await _cacheUserProfile(user);
          return Success(SessionRestoreResult(user: user));
        } on DioException catch (e) {
          if (e.response?.statusCode == 401) {
            final refreshed = await _attemptTokenRefresh();
            if (refreshed) {
              final retry = await _apiClient.get<Map<String, dynamic>>(
                ApiEndpoints.profile,
              );
              final retryBody = retry.data ?? const <String, dynamic>{};
              final userJson = retryBody['user'] is Map<String, dynamic>
                  ? retryBody['user'] as Map<String, dynamic>
                  : retryBody;
              final user = UserProfileModel.fromJson(userJson);
              await _cacheUserProfile(user);
              return Success(SessionRestoreResult(user: user));
            }
            await _clearLocalSession();
            return const Success(SessionRestoreResult(wasExpired: true));
          }
          // If offline with a non-expired token, restore cached user profile.
          final cached = await _readCachedActiveUser();
          if (cached != null) {
            return Success(SessionRestoreResult(user: cached));
          }
          return const Success(SessionRestoreResult());
        }
      }

      // No backend configured anymore; cannot verify token validity.
      await _clearLocalSession();
      return const Success(SessionRestoreResult());
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<AuthFlowResult>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        skipAuth: true,
        data: {
          'email': normalizedEmail,
          'password': password,
          'remember_me': rememberMe,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      await _preferencesService.setRememberMe(rememberMe);
      await _preferencesService.setRememberedEmail(
        rememberMe ? normalizedEmail : null,
      );

      if (_requiresOtp(body)) {
        return Success(
          AuthFlowResult(
            requiresOtpVerification: true,
            email: normalizedEmail,
            message: _extractMessage(body) ??
                'A 6-digit verification code has been sent to $normalizedEmail.',
          ),
        );
      }

      final user = await _persistAuthResponse(
        body: body,
        fallbackEmail: normalizedEmail,
      );
      return Success(AuthFlowResult(user: user));
    } on DioException catch (e) {
      return ErrorResult(_mapAuthDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<AuthFlowResult>> register({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.register,
        skipAuth: true,
        data: {
          'full_name': fullName.trim(),
          'email': normalizedEmail,
          'password': password,
          'accepted_terms': acceptedTerms,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      if (_requiresOtp(body) || _extractAccessToken(body) == null) {
        return Success(
          AuthFlowResult(
            requiresOtpVerification: true,
            email: normalizedEmail,
            message: _extractMessage(body) ??
                'Account created. Enter the 6-digit verification code sent to $normalizedEmail.',
          ),
        );
      }

      await _preferencesService.setRememberMe(true);
      await _preferencesService.setRememberedEmail(normalizedEmail);
      final user = await _persistAuthResponse(
        body: body,
        fallbackEmail: normalizedEmail,
      );
      return Success(
        AuthFlowResult(
          user: user,
          message: _extractMessage(body),
        ),
      );
    } on DioException catch (e) {
      return ErrorResult(_mapAuthDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<String>> sendOtp({
    required String email,
    required String purpose,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.sendOtp,
        skipAuth: true,
        data: {
          'email': normalizedEmail,
          'purpose': purpose,
        },
      );

      final message = _extractMessage(response.data) ??
          'A 6-digit verification code has been sent to $normalizedEmail.';
      return Success(message);
    } on DioException catch (e) {
      return ErrorResult(_mapAuthDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<AuthFlowResult>> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.verifyOtp,
        skipAuth: true,
        data: {
          'email': normalizedEmail,
          'otp': code.trim(),
          'code': code.trim(),
          'purpose': purpose,
        },
      );

      final body = response.data ?? const <String, dynamic>{};
      UserProfileModel? user;
      if (_extractAccessToken(body) != null) {
        user = await _persistAuthResponse(
          body: body,
          fallbackEmail: normalizedEmail,
        );
      }

      return Success(
        AuthFlowResult(
          user: user,
          email: normalizedEmail,
          message: _extractMessage(body) ?? 'Email verified successfully.',
        ),
      );
    } on DioException catch (e) {
      return ErrorResult(_mapOtpDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<String>> requestPasswordReset({
    required String email,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.forgotPassword,
        skipAuth: true,
        data: {'email': normalizedEmail},
      );

      final message = _extractMessage(response.data) ??
          'If an account exists for $normalizedEmail, a password reset verification code has been sent.';
      return Success(message);
    } on DioException catch (e) {
      return ErrorResult(_mapAuthDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<String>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.resetPassword,
        skipAuth: true,
        data: {
          'email': normalizedEmail,
          'code': code.trim(),
          'otp': code.trim(),
          'new_password': newPassword,
        },
      );

      final message = _extractMessage(response.data) ??
          'Your password has been reset successfully. You can now sign in.';
      return Success(message);
    } on DioException catch (e) {
      return ErrorResult(_mapOtpDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<UserProfileModel>> updateProfile({
    required String fullName,
    required String role,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    try {
      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.profile,
        data: {
          'full_name': fullName.trim(),
          'role': role.trim(),
        },
      );
      final body = response.data ?? const <String, dynamic>{};
      final userJson = body['user'] is Map<String, dynamic>
          ? body['user'] as Map<String, dynamic>
          : body;
      final updated = UserProfileModel.fromJson(userJson);
      await _cacheUserProfile(updated);
      return Success(updated);
    } on DioException catch (e) {
      return ErrorResult(_mapAuthDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_apiClient.isConfigured) {
      return const ErrorResult(_serviceNotConfiguredFailure);
    }

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.changePassword,
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final message = _extractMessage(response.data) ??
          'Password updated successfully.';
      return Success(message);
    } on DioException catch (e) {
      return ErrorResult(_mapAuthDioError(e));
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      if (_apiClient.isConfigured) {
        final refreshToken = await _secureStorageService.readRefreshToken();
        try {
          await _apiClient.post<void>(
            ApiEndpoints.logout,
            data: {
              if (refreshToken != null) 'refresh_token': refreshToken,
            },
          );
        } catch (_) {
          // Always clear local tokens even if server logout call is unreachable.
        }
      }
      await _clearLocalSession();
      return const Success(null);
    } catch (error) {
      return ErrorResult(ErrorMapper.mapException(error));
    }
  }

  Future<bool> _attemptTokenRefresh() async {
    if (!_apiClient.isConfigured) return false;
    final refreshToken = await _secureStorageService.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.refreshToken,
        skipAuth: true,
        data: {'refresh_token': refreshToken},
      );
      final body = response.data ?? const <String, dynamic>{};
      final newAccess = _extractAccessToken(body);
      if (newAccess == null || newAccess.isEmpty) return false;

      await _secureStorageService.saveSessionTokens(
        accessToken: newAccess,
        refreshToken:
            (body['refresh_token'] as String?) ?? refreshToken,
        expiresAt: _extractExpiresAt(body),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<UserProfileModel> _persistAuthResponse({
    required Map<String, dynamic> body,
    required String fallbackEmail,
  }) async {
    final accessToken = _extractAccessToken(body);
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthFailure(
        'The authentication server did not return a valid session token.',
      );
    }

    final refreshToken = body['refresh_token']?.toString();
    final expiresAt = _extractExpiresAt(body);

    final userJson = body['user'] is Map<String, dynamic>
        ? body['user'] as Map<String, dynamic>
        : <String, dynamic>{
            'id': body['user_id'] ?? body['id'] ?? fallbackEmail,
            'full_name': body['full_name'] ?? body['name'] ?? 'Technician',
            'email': body['email'] ?? fallbackEmail,
            'role': body['role'] ?? 'Field Technician',
          };

    final user = UserProfileModel.fromJson(userJson);

    await _secureStorageService.saveSessionTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      email: user.email,
    );
    await _cacheUserProfile(user);
    return user;
  }

  Future<void> _cacheUserProfile(UserProfileModel user) async {
    final db = await _databaseService.database;
    await db.insert(
      LocalDatabaseService.tableUsers,
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _preferencesService.setActiveUserId(user.id);
  }

  Future<UserProfileModel?> _readCachedActiveUser() async {
    final activeUserId = _preferencesService.activeUserId;
    if (activeUserId == null || activeUserId.isEmpty) return null;
    final db = await _databaseService.database;
    final rows = await db.query(
      LocalDatabaseService.tableUsers,
      where: 'id = ?',
      whereArgs: [activeUserId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfileModel.fromMap(rows.first);
  }

  Future<void> _clearLocalSession() async {
    await _secureStorageService.clearSession();
    await _preferencesService.setActiveUserId(null);
  }

  String? _extractAccessToken(Map<String, dynamic> body) {
    final token = (body['access_token'] ?? body['token'])?.toString();
    return (token == null || token.trim().isEmpty) ? null : token.trim();
  }

  DateTime? _extractExpiresAt(Map<String, dynamic> body) {
    final rawIso = body['expires_at'] as String?;
    if (rawIso != null && rawIso.isNotEmpty) {
      return DateTime.tryParse(rawIso)?.toUtc();
    }
    final expiresIn = body['expires_in'];
    if (expiresIn is num && expiresIn > 0) {
      return DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()));
    }
    return null;
  }

  bool _requiresOtp(Map<String, dynamic> body) {
    return body['requires_verification'] == true ||
        body['requires_otp'] == true ||
        body['otp_sent'] == true;
  }

  String? _extractMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    final candidate = body['message'] ?? body['detail'];
    if (candidate is String && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }
    return null;
  }

  Failure _mapAuthDioError(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final serverMessage = exception.response?.data is Map<String, dynamic>
        ? _extractMessage(exception.response!.data as Map<String, dynamic>)
        : null;

    if (statusCode == 401) {
      return AuthFailure(
        serverMessage ?? 'Invalid email or password. Please try again.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    if (statusCode == 409) {
      return AuthFailure(
        serverMessage ?? 'An account with this email address already exists.',
        code: 'EMAIL_EXISTS',
      );
    }
    if (statusCode == 429) {
      return AuthFailure(
        serverMessage ??
            'Too many attempts. Please wait briefly before trying again.',
        code: 'RATE_LIMITED',
      );
    }
    return ErrorMapper.mapException(exception);
  }

  Failure _mapOtpDioError(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final data = exception.response?.data;
    final serverCode = data is Map<String, dynamic>
        ? data['code']?.toString().toUpperCase()
        : null;
    final serverMessage =
        data is Map<String, dynamic> ? _extractMessage(data) : null;

    if (statusCode == 410 || serverCode == 'OTP_EXPIRED') {
      return AuthFailure(
        serverMessage ??
            'This verification code has expired. Please request a new code.',
        code: 'OTP_EXPIRED',
      );
    }
    if (statusCode == 400 ||
        statusCode == 422 ||
        serverCode == 'INVALID_OTP') {
      return AuthFailure(
        serverMessage ??
            'Invalid verification code. Please check the 6-digit code and try again.',
        code: 'INVALID_OTP',
      );
    }
    return _mapAuthDioError(exception);
  }
}
