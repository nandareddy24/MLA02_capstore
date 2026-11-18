import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/utilities/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/fixwise_brand_mark.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/repositories/providers.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  late bool _rememberMe;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesServiceProvider);
    _rememberMe = prefs.rememberMe;
    _emailController = TextEditingController(
      text: _rememberMe ? (prefs.rememberedEmail ?? '') : '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );

    if (!mounted || result == null) return;

    if (result.requiresOtpVerification) {
      context.push(
        AppRoutes.otpVerificationPath(
          email: result.email ?? _emailController.text.trim(),
          purpose: 'login',
        ),
      );
      return;
    }

    if (result.user != null) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final configuredUrl = ref.watch(profileSettingsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ResponsiveContentContainer(
              maxWidth: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FixWiseBrandMark(
                    size: 48,
                    showWordmark: true,
                    showSubtitle: true,
                    centered: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Welcome back',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Sign in with your verified FixWise account.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (authState.errorMessage != null) ...[
                            AuthMessageBanner(
                              message: authState.errorMessage!,
                              tone: AuthBannerTone.error,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ] else if (authState.infoMessage != null) ...[
                            AuthMessageBanner(
                              message: authState.infoMessage!,
                              tone: authState.sessionExpired
                                  ? AuthBannerTone.info
                                  : AuthBannerTone.success,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
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
                            hint: 'Enter your password',
                            prefixIcon: LucideIcons.lock,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            validator: Validators.password,
                            onFieldSubmitted: (_) => _submit(),
                            onChanged: (_) => ref
                                .read(authControllerProvider.notifier)
                                .clearFeedback(),
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
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                onTap: authState.isSubmitting
                                    ? null
                                    : () => setState(
                                          () => _rememberMe = !_rememberMe,
                                        ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xxs,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: authState.isSubmitting
                                              ? null
                                              : (value) {
                                                  setState(
                                                    () => _rememberMe =
                                                        value ?? true,
                                                  );
                                                },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        'Remember me',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: authState.isSubmitting
                                    ? null
                                    : () {
                                        ref
                                            .read(
                                              authControllerProvider.notifier,
                                            )
                                            .clearFeedback();
                                        context.push(AppRoutes.forgotPassword);
                                      },
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            label: 'Login',
                            icon: LucideIcons.logIn,
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
                        'Do not have an account?',
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
                                context.push(AppRoutes.register);
                              },
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => showAuthServerConfigDialog(context, ref),
                      icon: Icon(
                        configuredUrl.isEmpty
                            ? LucideIcons.settings
                            : LucideIcons.server,
                        size: 16,
                      ),
                      label: Text(
                        configuredUrl.isEmpty
                            ? 'Configure Auth Server URL'
                            : 'Auth Server Configured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
