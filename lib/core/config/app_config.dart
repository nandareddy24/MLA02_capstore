import 'package:flutter/foundation.dart';

/// Deployment environment for the FixWise Flutter client.
enum AppEnvironment {
  development,
  production,
}

/// Environment-specific configuration and transport security validator.
///
/// Prevents hardcoded `localhost` or cleartext HTTP endpoints from ever being
/// used in production or release APK builds.
abstract final class AppConfig {
  static const String _rawEnv = String.fromEnvironment(
    'FIXWISE_ENV',
    defaultValue: '',
  );

  /// Compile-time backend API URL injected via:
  /// `flutter build apk --release --dart-define=FIXWISE_ENV=production --dart-define=FIXWISE_API_BASE_URL=https://api.fixwise.example.com`
  static const String compileTimeApiBaseUrl = String.fromEnvironment(
    'FIXWISE_API_BASE_URL',
    defaultValue: '',
  );

  static AppEnvironment get environment {
    final normalized = _rawEnv.trim().toLowerCase();
    if (normalized == 'production' || normalized == 'prod') {
      return AppEnvironment.production;
    }
    if (normalized == 'development' || normalized == 'dev') {
      return AppEnvironment.development;
    }
    // Only enforce production security rules when explicitly configured.
    return (kReleaseMode && _rawEnv.isNotEmpty)
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static bool get isProduction =>
      environment == AppEnvironment.production;

  static const Set<String> _localOnlyHosts = {
    'localhost',
    '127.0.0.1',
    '0.0.0.0',
    '10.0.2.2',
    '::1',
  };

  /// Validates an API base URL for the active build environment.
  /// Returns `null` if valid, or a human-readable security error message.
  static String? validateApiBaseUrl(
    String rawUrl, {
    AppEnvironment? env,
    bool? releaseMode,
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return 'No FixWise backend server URL is configured.';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Invalid FixWise backend URL format.';
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return 'Backend URL must use HTTP or HTTPS.';
    }

    final strictProduction =
        (env ?? environment) == AppEnvironment.production &&
            (releaseMode ?? kReleaseMode);

    if (strictProduction) {
      if (scheme != 'https') {
        return 'Production builds require an HTTPS backend URL.';
      }
      final host = uri.host.toLowerCase();
      if (_localOnlyHosts.contains(host) || host.endsWith('.local')) {
        return 'Localhost or emulator addresses are forbidden in production release builds.';
      }
    }

    return null;
  }
}
