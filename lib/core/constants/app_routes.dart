/// Centralized route names and path definitions for GoRouter.
abstract final class AppRoutes {
  // Public & auth routes
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String otpVerification = '/verify-otp';
  static const String forgotPassword = '/forgot-password';

  // Top-level shell destinations (protected)
  static const String dashboard = '/dashboard';
  static const String deviceSelection = '/devices';
  static const String history = '/history';
  static const String profile = '/profile';

  // Feature workflow routes (protected)
  static const String faultReporting = '/fault-report';
  static const String diagnosis = '/diagnosis/:reportId';
  static const String recommendations = '/recommendations/:reportId';
  static const String feedback = '/feedback/:reportId';

  // Route names
  static const String splashName = 'splash';
  static const String onboardingName = 'onboarding';
  static const String loginName = 'login';
  static const String registerName = 'register';
  static const String otpVerificationName = 'otp-verification';
  static const String forgotPasswordName = 'forgot-password';
  static const String dashboardName = 'dashboard';
  static const String deviceSelectionName = 'device-selection';
  static const String faultReportingName = 'fault-reporting';
  static const String diagnosisName = 'diagnosis';
  static const String recommendationsName = 'recommendations';
  static const String historyName = 'history';
  static const String feedbackName = 'feedback';
  static const String profileName = 'profile';

  /// Helper builders for parameterized paths.
  static String diagnosisPath(String reportId) => '/diagnosis/$reportId';
  static String recommendationsPath(String reportId) =>
      '/recommendations/$reportId';
  static String feedbackPath(String reportId) => '/feedback/$reportId';
  static String faultReportingWithDevice(String deviceId) =>
      '$faultReporting?deviceId=${Uri.encodeQueryComponent(deviceId)}';

  static String otpVerificationPath({
    required String email,
    String purpose = 'registration',
  }) =>
      '$otpVerification?email=${Uri.encodeQueryComponent(email)}&purpose=${Uri.encodeQueryComponent(purpose)}';
}
