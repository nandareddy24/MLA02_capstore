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
import '../../../../core/widgets/primary_button.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_banner.dart';
import '../widgets/otp_input_row.dart';

/// Backend-verified six-digit email OTP verification screen with resend cooldown.
///
/// Strictly validates OTPs through the configured authentication server and never
/// generates or verifies codes locally.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.purpose = 'registration',
  });

  final String email;
  final String purpose;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final GlobalKey<OtpInputRowState> _otpKey = GlobalKey<OtpInputRowState>();

  String _code = '';
  String? _validationError;
  Timer? _cooldownTimer;
  int _secondsRemaining = AppConstants.otpResendCooldownSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
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

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    final validation = Validators.otpCode(_code);
    if (validation != null) {
      setState(() => _validationError = validation);
      return;
    }

    setState(() => _validationError = null);

    final result = await ref.read(authControllerProvider.notifier).verifyOtp(
          email: widget.email,
          code: _code,
          purpose: widget.purpose,
        );

    if (!mounted || result == null) return;

    if (result.user != null) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0) return;

    final message = await ref.read(authControllerProvider.notifier).sendOtp(
          email: widget.email,
          purpose: widget.purpose,
        );

    if (!mounted) return;
    if (message != null) {
      _otpKey.currentState?.clear();
      setState(() {
        _code = '';
        _validationError = null;
      });
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasError = _validationError != null || authState.errorMessage != null;

    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verification')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContentContainer(
            maxWidth: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface(theme.brightness),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.buttonRadius,
                            ),
                            border: Border.all(color: colorScheme.outline),
                          ),
                          child: Icon(
                            LucideIcons.lockKeyhole,
                            size: AppSpacing.iconLg,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Verify your email',
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Enter the 6-digit verification code sent to ${widget.email}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (authState.errorMessage != null) ...[
                        AuthMessageBanner(
                          message: authState.errorMessage!,
                          tone: AuthBannerTone.error,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ] else if (authState.infoMessage != null) ...[
                        AuthMessageBanner(
                          message: authState.infoMessage!,
                          tone: AuthBannerTone.success,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      OtpInputRow(
                        key: _otpKey,
                        hasError: hasError,
                        enabled: !authState.isSubmitting,
                        onChanged: (value) {
                          setState(() {
                            _code = value;
                            if (_validationError != null) {
                              _validationError = null;
                            }
                          });
                          ref
                              .read(authControllerProvider.notifier)
                              .clearFeedback();
                        },
                        onCompleted: (_) => _verify(),
                      ),
                      if (_validationError != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _validationError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.dangerous,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: 'Verify Code',
                        icon: LucideIcons.shieldCheck,
                        isLoading: authState.isSubmitting,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: _secondsRemaining > 0
                            ? Text(
                                'Resend code available in ${_secondsRemaining}s',
                                style: theme.textTheme.bodySmall,
                              )
                            : TextButton.icon(
                                onPressed:
                                    authState.isSubmitting ? null : _resendCode,
                                icon: const Icon(
                                  LucideIcons.refreshCw,
                                  size: 16,
                                ),
                                label: const Text('Resend verification code'),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
