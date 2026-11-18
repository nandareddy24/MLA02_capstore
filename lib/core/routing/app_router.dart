import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/otp_verification_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/device_selection/presentation/screens/device_selection_screen.dart';
import '../../features/diagnosis/presentation/screens/diagnosis_screen.dart';
import '../../features/fault_reporting/presentation/screens/fault_reporting_screen.dart';
import '../../features/feedback/presentation/screens/feedback_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/onboarding/presentation/controllers/onboarding_controller.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/recommendations/presentation/screens/recommendations_screen.dart';
import '../constants/app_routes.dart';
import '../widgets/app_error_state.dart';
import 'main_navigation_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Bridges Riverpod auth/onboarding state updates into GoRouter's [refreshListenable]
/// without recreating the router instance or resetting navigation stacks.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
    ref.listen<bool>(
      onboardingControllerProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final onboardingDone = ref.read(onboardingControllerProvider);
      final location = state.matchedLocation;

      if (authState.status == AuthStatus.initializing) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (!onboardingDone) {
        return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }

      final isPublicAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.otpVerification ||
          location == AppRoutes.forgotPassword;

      // Prevent any unauthenticated access to protected pages.
      if (!authState.isAuthenticated) {
        return isPublicAuthRoute ? null : AppRoutes.login;
      }

      if (location == AppRoutes.splash ||
          location == AppRoutes.onboarding ||
          isPublicAuthRoute) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        name: AppRoutes.otpVerificationName,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final purpose =
              state.uri.queryParameters['purpose'] ?? 'registration';
          return OtpVerificationScreen(email: email, purpose: purpose);
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: AppRoutes.dashboardName,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.deviceSelection,
                name: AppRoutes.deviceSelectionName,
                builder: (context, state) => const DeviceSelectionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                name: AppRoutes.historyName,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: AppRoutes.profileName,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.faultReporting,
        name: AppRoutes.faultReportingName,
        builder: (context, state) {
          final deviceId = state.uri.queryParameters['deviceId'];
          return FaultReportingScreen(deviceId: deviceId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.diagnosis,
        name: AppRoutes.diagnosisName,
        builder: (context, state) {
          final reportId = state.pathParameters['reportId'] ?? '';
          return DiagnosisScreen(reportId: reportId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.recommendations,
        name: AppRoutes.recommendationsName,
        builder: (context, state) {
          final reportId = state.pathParameters['reportId'] ?? '';
          return RecommendationsScreen(reportId: reportId);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.feedback,
        name: AppRoutes.feedbackName,
        builder: (context, state) {
          final reportId = state.pathParameters['reportId'] ?? '';
          return FeedbackScreen(reportId: reportId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: AppErrorState(
        title: 'Route not found',
        message: 'No screen matches "${state.uri}".',
        retryLabel: 'Return to Dashboard',
        onRetry: () => context.go(AppRoutes.dashboard),
      ),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
