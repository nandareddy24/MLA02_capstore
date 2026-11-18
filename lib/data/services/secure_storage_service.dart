import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';

/// Wraps [FlutterSecureStorage] for persisting encrypted authentication tokens
/// and session metadata in Android Keystore / iOS Keychain.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveSessionTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? email,
  }) async {
    await _storage.write(key: AppConstants.secureAuthToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(
        key: AppConstants.secureRefreshToken,
        value: refreshToken,
      );
    }
    if (expiresAt != null) {
      await _storage.write(
        key: AppConstants.secureTokenExpiresAt,
        value: expiresAt.toUtc().toIso8601String(),
      );
    }
    if (email != null && email.isNotEmpty) {
      await _storage.write(key: AppConstants.secureUserEmail, value: email);
    }
  }

  Future<String?> readAuthToken() async {
    return _storage.read(key: AppConstants.secureAuthToken);
  }

  Future<String?> readRefreshToken() async {
    return _storage.read(key: AppConstants.secureRefreshToken);
  }

  Future<DateTime?> readTokenExpiresAt() async {
    final raw = await _storage.read(key: AppConstants.secureTokenExpiresAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<String?> readSessionEmail() async {
    return _storage.read(key: AppConstants.secureUserEmail);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: AppConstants.secureAuthToken);
    await _storage.delete(key: AppConstants.secureRefreshToken);
    await _storage.delete(key: AppConstants.secureTokenExpiresAt);
    await _storage.delete(key: AppConstants.secureUserEmail);
  }
}
