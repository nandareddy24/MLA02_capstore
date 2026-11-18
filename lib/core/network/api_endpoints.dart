/// Centralized REST API endpoints for the FixWise backend and ML inference service.
abstract final class ApiEndpoints {
  static const String health = '/api/v1/health';

  // Authentication & session endpoints
  static const String login = '/api/v1/auth/login';
  static const String register = '/api/v1/auth/register';
  static const String logout = '/api/v1/auth/logout';
  static const String refreshToken = '/api/v1/auth/refresh';
  static const String profile = '/api/v1/auth/me';

  // Email OTP verification endpoints
  static const String sendOtp = '/api/v1/auth/otp/send';
  static const String verifyOtp = '/api/v1/auth/otp/verify';

  // Password reset & change endpoints
  static const String forgotPassword = '/api/v1/auth/password/forgot';
  static const String resetPassword = '/api/v1/auth/password/reset';
  static const String changePassword = '/api/v1/auth/password/change';

  // User-scoped device management endpoints
  static const String devices = '/api/v1/devices';
  static String deviceById(String deviceId) => '/api/v1/devices/$deviceId';

  // Diagnosis & decision-support endpoints (ML backend integration target)
  static const String diagnosticCatalog = '/api/v1/catalog/devices';
  static const String analyzeFault = '/api/v1/diagnosis/analyze';
  static const String decisionSupportRecommend =
      '/api/v1/decision-support/recommend';
  static const String history = '/api/v1/history';
  static String historyDetail(String reportId) => '/api/v1/history/$reportId';
  static String diagnosisByReport(String reportId) =>
      '/api/v1/diagnosis/$reportId';
  static String recommendationsByReport(String reportId) =>
      '/api/v1/diagnosis/$reportId/recommendations';

  // Feedback endpoint for model improvement loop
  static const String submitFeedback = '/api/v1/feedback';
}
