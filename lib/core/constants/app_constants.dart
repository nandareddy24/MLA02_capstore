/// Application-wide constants and environment defaults for FixWise.
abstract final class AppConstants {
  static const String appName = 'FixWise';
  static const String appTagline = 'Device Diagnostics & Decision Support';
  static const String appFullSubtitle =
      'AI-Based Fault Diagnosis & Decision Support';
  static const String appVersion = '1.0.0';

  /// Optional compile-time API base URL supplied via:
  /// `flutter run --dart-define=FIXWISE_API_BASE_URL=https://api.example.com`
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'FIXWISE_API_BASE_URL',
    defaultValue: '',
  );

  // Network timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Authentication & OTP rules
  static const int otpLength = 6;
  static const int otpResendCooldownSeconds = 60;

  // Local SQLite database
  static const String databaseName = 'fixwise_local.db';
  static const int databaseVersion = 5;
  static const int historyPageSize = 20;

  // Fault reporting input bounds
  static const int maxManufacturerLength = 60;
  static const int maxModelLength = 80;
  static const int maxErrorCodeLength = 64;
  static const int maxOperatingConditionsLength = 240;
  static const int maxProblemDescriptionLength = 1000;

  // SharedPreferences keys
  static const String prefOnboardingCompleted = 'onboarding_completed';
  static const String prefThemeMode = 'theme_mode';
  static const String prefApiBaseUrl = 'api_base_url';
  static const String prefActiveUserId = 'active_user_id';
  static const String prefRememberMe = 'auth_remember_me';
  static const String prefRememberedEmail = 'auth_remembered_email';

  // FlutterSecureStorage keys
  static const String secureAuthToken = 'auth_access_token';
  static const String secureRefreshToken = 'auth_refresh_token';
  static const String secureTokenExpiresAt = 'auth_token_expires_at';
  static const String secureUserEmail = 'auth_user_email';
}
