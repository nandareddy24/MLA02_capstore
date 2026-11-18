import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/utilities/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_banner.dart';
import '../widgets/otp_input_row.dart';
import '../widgets/password_strength_indicator.dart';

enum _ResetStep { requestEmail, verifyAndReset, completed }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.requestEmail;
  String _resetCode = '';
  String? _otpValidationError;
  String? _successMessage;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _cooldownTimer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsRemaining = AppConstants.otpResendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  Future<void> _requestReset() async {
    FocusScope.of(context).unfocus();
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    final message = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: _emailController.text);

    if (!mounted || message == null) return;
    setState(() {
      _step = _ResetStep.verifyAndReset;
      _successMessage = message;
      _otpValidationError = null;
    });
    _startCooldown();
  }

  Future<void> _resendResetCode() async {
    if (_secondsRemaining > 0) return;
    final message = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email: _emailController.text);

    if (!mounted || message == null) return;
    setState(() => _successMessage = message);
    _startCooldown();
  }

  Future<void> _confirmReset() async {
    FocusScope.of(context).unfocus();
    final otpError = Validators.otpCode(_resetCode);
    final formValid = _resetFormKey.currentState?.validate() ?? false;
    setState(() => _otpValidationError = otpError);

    if (otpError != null || !formValid) return;

    final message = await ref
        .read(authControllerProvider.notifier)
        .confirmPasswordReset(
          email: _emailController.text,
          code: _resetCode,
          newPassword: _newPasswordController.text,
        );

    if (!mounted || message == null) return;
    setState(() {
      _step = _ResetStep.completed;
      _successMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContentContainer(
            maxWidth: 480,
            child: switch (_step) {
              _ResetStep.requestEmail => _buildEmailStep(theme, authState),
              _ResetStep.verifyAndReset => _buildVerifyStep(theme, authState),
              _ResetStep.completed => _buildCompletedStep(theme),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep(ThemeData theme, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot password', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Enter the email address associated with your FixWise account to request a secure password reset code.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.contentVertical),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Form(
            key: _emailFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (authState.errorMessage != null) ...[
                  AuthMessageBanner(
                    message: authState.errorMessage!,
                    tone: AuthBannerTone.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                AppTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'technician@organization.com',
                  prefixIcon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: Validators.email,
                  onFieldSubmitted: (_) => _requestReset(),
                  onChanged: (_) => ref
                      .read(authControllerProvider.notifier)
                      .clearFeedback(),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Send Reset Code',
                  icon: LucideIcons.send,
                  isLoading: authState.isSubmitting,
                  onPressed: _requestReset,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyStep(ThemeData theme, AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Verify & set new password', style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Enter the 6-digit verification code sent to ${_emailController.text.trim()} and choose a new password.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.contentVertical),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Form(
            key: _resetFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (authState.errorMessage != null) ...[
                  AuthMessageBanner(
                    message: authState.errorMessage!,
                    tone: AuthBannerTone.error,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else if (_successMessage != null) ...[
                  AuthMessageBanner(
                    message: _successMessage!,
                    tone: AuthBannerTone.info,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  'Verification Code',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                OtpInputRow(
                  hasError: _otpValidationError != null,
                  enabled: !authState.isSubmitting,
                  onChanged: (value) {
                    setState(() {
                      _resetCode = value;
                      if (_otpValidationError != null) {
                        _otpValidationError = null;
                      }
                    });
                    ref.read(authControllerProvider.notifier).clearFeedback();
                  },
                ),
                if (_otpValidationError != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    _otpValidationError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.dangerous,
                    ),
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: _secondsRemaining > 0
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            'Resend code in ${_secondsRemaining}s',
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      : TextButton(
                          onPressed:
                              authState.isSubmitting ? null : _resendResetCode,
                          child: const Text('Resend code'),
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hint: 'Create a strong new password',
                  prefixIcon: LucideIcons.lock,
                  obscureText: _obscureNewPassword,
                  textInputAction: TextInputAction.next,
                  validator: Validators.strongPassword,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    tooltip: _obscureNewPassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(
                      () => _obscureNewPassword = !_obscureNewPassword,
                    ),
                    icon: Icon(
                      _obscureNewPassword
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      size: AppSpacing.iconSm,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                PasswordStrengthIndicator(
                  password: _newPasswordController.text,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  hint: 'Re-enter your new password',
                  prefixIcon: LucideIcons.shieldCheck,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.confirmPassword(
                    v,
                    _newPasswordController.text,
                  ),
                  onFieldSubmitted: (_) => _confirmReset(),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmPassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () => setState(
                      () =>
                          _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      size: AppSpacing.iconSm,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Reset Password',
                  icon: LucideIcons.keyRound,
                  isLoading: authState.isSubmitting,
                  onPressed: _confirmReset,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Change Email',
                  onPressed: authState.isSubmitting
                      ? null
                      : () {
                          ref
                              .read(authControllerProvider.notifier)
                              .clearFeedback();
                          setState(() => _step = _ResetStep.requestEmail);
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedStep(ThemeData theme) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.safeSurface(theme.brightness),
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                border: Border.all(
                  color: AppColors.safe.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                LucideIcons.circleCheck,
                size: AppSpacing.iconLg,
                color: AppColors.safe,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Password updated',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _successMessage ??
                'Your password has been updated successfully. Sign in with your new credentials.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Back to Login',
            icon: LucideIcons.logIn,
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
