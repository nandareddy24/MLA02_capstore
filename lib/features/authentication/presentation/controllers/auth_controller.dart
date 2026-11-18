import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/user_profile_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/providers.dart';

enum AuthStatus { initializing, authenticated, unauthenticated }

/// Immutable authentication & session state observed by GoRouter and auth screens.
class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.infoMessage,
    this.sessionExpired = false,
  });

  const AuthState.initializing() : this(status: AuthStatus.initializing);

  final AuthStatus status;
  final UserProfileModel? user;
  final bool isSubmitting;
  final String? errorMessage;
  final String? infoMessage;
  final bool sessionExpired;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    UserProfileModel? user,
    bool clearUser = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
    bool? sessionExpired,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
      sessionExpired: sessionExpired ?? this.sessionExpired,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Wire global 401 unauthorized hook from ApiClient to expire the session cleanly.
    final apiClient = ref.read(apiClientProvider);
    apiClient.onSessionExpired = handleSessionExpired;

    Future.microtask(_restoreSession);
    return const AuthState.initializing();
  }

  Future<void> _restoreSession() async {
    final result = await ref.read(authRepositoryProvider).restoreSession();
    result.when(
      success: (restored) {
        if (restored.user != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: restored.user,
          );
        } else {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            sessionExpired: restored.wasExpired,
            infoMessage: restored.wasExpired
                ? 'Your previous session has expired. Please sign in again.'
                : null,
          );
        }
      },
      failure: (failure) {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: failure.message,
        );
      },
    );
  }

  Future<AuthFlowResult?> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
      sessionExpired: false,
    );

    final result = await ref.read(authRepositoryProvider).signIn(
          email: email,
          password: password,
          rememberMe: rememberMe,
        );

    return result.when(
      success: (flow) {
        if (flow.user != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: flow.user,
          );
        } else {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            infoMessage: flow.message,
          );
        }
        return flow;
      },
      failure: (failure) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<AuthFlowResult?> register({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    final result = await ref.read(authRepositoryProvider).register(
          fullName: fullName,
          email: email,
          password: password,
          acceptedTerms: acceptedTerms,
        );

    return result.when(
      success: (flow) {
        if (flow.user != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: flow.user,
          );
        } else {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            infoMessage: flow.message,
          );
        }
        return flow;
      },
      failure: (failure) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<String?> sendOtp({
    required String email,
    required String purpose,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    final result = await ref.read(authRepositoryProvider).sendOtp(
          email: email,
          purpose: purpose,
        );

    return result.when(
      success: (message) {
        state = state.copyWith(
          isSubmitting: false,
          infoMessage: message,
        );
        return message;
      },
      failure: (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<AuthFlowResult?> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    final result = await ref.read(authRepositoryProvider).verifyOtp(
          email: email,
          code: code,
          purpose: purpose,
        );

    return result.when(
      success: (flow) {
        if (flow.user != null) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: flow.user,
            infoMessage: flow.message,
          );
        } else {
          state = state.copyWith(
            isSubmitting: false,
            infoMessage: flow.message,
          );
        }
        return flow;
      },
      failure: (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<String?> requestPasswordReset({required String email}) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    final result = await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(email: email);

    return result.when(
      success: (message) {
        state = state.copyWith(
          isSubmitting: false,
          infoMessage: message,
        );
        return message;
      },
      failure: (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<String?> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearInfo: true,
    );

    final result = await ref.read(authRepositoryProvider).confirmPasswordReset(
          email: email,
          code: code,
          newPassword: newPassword,
        );

    return result.when(
      success: (message) {
        state = AuthState(
          status: AuthStatus.unauthenticated,
          infoMessage: message,
        );
        return message;
      },
      failure: (failure) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: failure.message,
        );
        return null;
      },
    );
  }

  Future<void> handleSessionExpired() async {
    if (state.status != AuthStatus.authenticated) return;
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      sessionExpired: true,
      infoMessage: 'Your session has expired. Please sign in again.',
    );
  }

  Future<String?> updateProfile({
    required String fullName,
    required String role,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await ref.read(authRepositoryProvider).updateProfile(
          fullName: fullName,
          role: role,
        );
    return result.when(
      success: (updatedUser) {
        state = state.copyWith(
          user: updatedUser,
          isSubmitting: false,
        );
        return null;
      },
      failure: (err) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: err.message,
        );
        return err.message;
      },
    );
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    final result = await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    return result.when(
      success: (_) {
        state = state.copyWith(isSubmitting: false);
        return null;
      },
      failure: (err) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: err.message,
        );
        return err.message;
      },
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    await ref.read(authRepositoryProvider).signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearFeedback() {
    if (state.errorMessage != null || state.infoMessage != null) {
      state = state.copyWith(clearError: true, clearInfo: true);
    }
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
