import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
import '../widgets/password_strength_indicator.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _showTermsError = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() => _showTermsError = !_acceptedTerms);

    if (!formValid || !_acceptedTerms) {
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).register(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          acceptedTerms: _acceptedTerms,
        );

    if (!mounted || result == null) return;

    if (result.requiresOtpVerification) {
      context.push(
        AppRoutes.otpVerificationPath(
          email: result.email ?? _emailController.text.trim(),
          purpose: 'registration',
        ),
      );
      return;
    }

    if (result.user != null) {
      context.go(AppRoutes.dashboard);
    }
  }

  void _showPoliciesDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'FixWise Terms of Use & Privacy Summary:\n\n'
            '1. Account Security: Your credentials and session tokens are transmitted over HTTPS to your configured FixWise authentication server and stored encrypted in device secure storage.\n\n'
            '2. Diagnostic Records: Device inventory, symptom reports, and feedback logs are used solely to perform fault analysis and maintain repair history.\n\n'
            '3. Decision Support Disclaimer: Automated fault rankings and troubleshooting recommendations support technical judgment and do not replace certified safety lockout procedures.',
          ),
        ),
        actions: [
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContentContainer(
            maxWidth: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create your account',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Register with your work email to report faults and track diagnostics.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.contentVertical),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  child: Form(
                    key: _formKey,
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
                          controller: _fullNameController,
                          label: 'Full Name',
                          hint: 'e.g., Priya Sharma',
                          prefixIcon: LucideIcons.userRound,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.minLength(v, 2, fieldName: 'Full name'),
                          onChanged: (_) => ref
                              .read(authControllerProvider.notifier)
                              .clearFeedback(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'technician@organization.com',
                          prefixIcon: LucideIcons.mail,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                          onChanged: (_) => ref
                              .read(authControllerProvider.notifier)
                              .clearFeedback(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Create a strong password',
                          prefixIcon: LucideIcons.lock,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: Validators.strongPassword,
                          onChanged: (_) {
                            setState(() {});
                            ref
                                .read(authControllerProvider.notifier)
                                .clearFeedback();
                          },
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: AppSpacing.iconSm,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        PasswordStrengthIndicator(
                          password: _passwordController.text,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirm Password',
                          hint: 'Re-enter your password',
                          prefixIcon: LucideIcons.shieldCheck,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          validator: (v) => Validators.confirmPassword(
                            v,
                            _passwordController.text,
                          ),
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              );
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: AppSpacing.iconSm,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptedTerms,
                                onChanged: authState.isSubmitting
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _acceptedTerms = value ?? false;
                                          if (_acceptedTerms) {
                                            _showTermsError = false;
                                          }
                                        });
                                      },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'I agree to the ',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _showPoliciesDialog,
                                    child: Text(
                                      'Terms of Service and Privacy Policy',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_showTermsError) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'You must acknowledge the Terms of Service and Privacy Policy to continue.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.dangerous,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        PrimaryButton(
                          label: 'Create Account',
                          icon: LucideIcons.userPlus,
                          isLoading: authState.isSubmitting,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Already have an account?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: authState.isSubmitting
                          ? null
                          : () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .clearFeedback();
                              context.go(AppRoutes.login);
                            },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
