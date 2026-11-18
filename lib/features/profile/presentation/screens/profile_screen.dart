import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utilities/date_formatter.dart';
import '../../../../core/utilities/responsive_layout.dart';
import '../../../../core/utilities/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../authentication/presentation/widgets/password_strength_indicator.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _endpointFormKey = GlobalKey<FormState>();
  late final TextEditingController _apiUrlController;

  @override
  void initState() {
    super.initState();
    _apiUrlController = TextEditingController(
      text: ref.read(profileSettingsControllerProvider),
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveEndpoint() async {
    FocusScope.of(context).unfocus();
    if (!(_endpointFormKey.currentState?.validate() ?? false)) return;

    await ref
        .read(profileSettingsControllerProvider.notifier)
        .saveApiBaseUrl(_apiUrlController.text);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _apiUrlController.text.trim().isEmpty
                ? 'API endpoint cleared.'
                : 'Backend API endpoint saved.',
          ),
        ),
      );
    }
  }

  Future<void> _showEditProfileDialog() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _EditProfileDialog(
        initialName: user.fullName,
        initialRole: user.role,
        onSave: (name, role) => ref
            .read(authControllerProvider.notifier)
            .updateProfile(fullName: name, role: role),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ChangePasswordDialog(
        onSave: (currentPassword, newPassword) => ref
            .read(authControllerProvider.notifier)
            .changePassword(
              currentPassword: currentPassword,
              newPassword: newPassword,
            ),
      ),
    );
  }

  void _showDocumentDialog({
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Logout',
      message:
          'Log out of your FixWise account? You will need to sign in again to access your diagnosis history.',
      confirmLabel: 'Logout',
      isDangerous: true,
    );

    if (!confirmed || !mounted) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final activeBaseUrl = ref.watch(profileSettingsControllerProvider);
    final user = authState.user;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: ResponsiveContentContainer(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('User Profile', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.contentVertical),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface(theme.brightness),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Icon(
                        LucideIcons.userRound,
                        size: AppSpacing.iconLg,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Technician',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? '',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            children: [
                              StatusBadge(
                                label: user?.role ?? 'Field Technician',
                                tone: BadgeTone.info,
                              ),
                              if (user != null)
                                StatusBadge(
                                  label:
                                      'Joined ${DateFormatter.formatShortDate(user.createdAt)}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Account Settings', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              _SettingsNavTile(
                icon: LucideIcons.pencil,
                title: 'Edit Profile',
                subtitle: 'Update your display name and technician role',
                onTap: _showEditProfileDialog,
              ),
              const SizedBox(height: AppSpacing.xs),
              _SettingsNavTile(
                icon: LucideIcons.keyRound,
                title: 'Change Password',
                subtitle: 'Update your account password securely',
                onTap: _showChangePasswordDialog,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Display', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme Preference', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selection.first);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Backend Connection', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Form(
                  key: _endpointFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.settings,
                            size: AppSpacing.iconSm,
                            color: colorScheme.primary,
                          ),
                          Text(
                            'ML Inference Endpoint',
                            style: theme.textTheme.titleMedium,
                          ),
                          StatusBadge(
                            label: activeBaseUrl.isEmpty
                                ? 'Not Configured'
                                : 'Configured',
                            tone: activeBaseUrl.isEmpty
                                ? BadgeTone.warning
                                : BadgeTone.safe,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _apiUrlController,
                        label: 'API Base URL',
                        hint: 'https://api.fixwise.local',
                        prefixIcon: LucideIcons.link,
                        keyboardType: TextInputType.url,
                        validator: Validators.optionalUrl,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SecondaryButton(
                        label: 'Save Endpoint',
                        icon: LucideIcons.save,
                        onPressed: _saveEndpoint,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Legal & About', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              _SettingsNavTile(
                icon: LucideIcons.shield,
                title: 'Privacy Policy',
                subtitle: 'How FixWise stores and protects your diagnostic data',
                onTap: () => _showDocumentDialog(
                  title: 'Privacy Policy',
                  body:
                      'FixWise associates every device fault report, diagnosis record, and feedback entry strictly with your authenticated account.\n\n'
                      'Authentication tokens are persisted using encrypted platform secure storage (Android Keystore / iOS Keychain). Other users cannot access your diagnostic history or feedback records.',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _SettingsNavTile(
                icon: LucideIcons.fileText,
                title: 'Terms and Conditions',
                subtitle: 'Decision-support scope and safety responsibilities',
                onTap: () => _showDocumentDialog(
                  title: 'Terms and Conditions',
                  body:
                      'FixWise provides AI-assisted fault diagnosis and rule-based decision support for informational troubleshooting.\n\n'
                      'Predicted fault categories are not confirmed physical diagnoses. Always follow manufacturer lockout procedures, never open live electrical equipment, and escalate high-risk faults to a qualified technician or emergency services.',
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _SettingsNavTile(
                icon: LucideIcons.info,
                title: 'About FixWise',
                subtitle:
                    'Version ${AppConstants.appVersion} • ${AppConstants.appTagline}',
                onTap: () => _showDocumentDialog(
                  title: 'About ${AppConstants.appName}',
                  body:
                      '${AppConstants.appName} v${AppConstants.appVersion}\n'
                      '${AppConstants.appFullSubtitle}\n\n'
                      'Built with Flutter, Material 3, Riverpod, GoRouter, SQLite, and a Python scikit-learn Decision Tree / Random Forest diagnosis & reviewed decision-support engine.',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: 'Logout',
                icon: LucideIcons.logOut,
                isDangerous: true,
                isLoading: authState.isSubmitting,
                onPressed: _confirmLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.iconSm, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            size: AppSpacing.iconSm,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialRole,
    required this.onSave,
  });

  final String initialName;
  final String initialRole;
  final Future<String?> Function(String name, String role) onSave;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roleCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _roleCtrl = TextEditingController(text: widget.initialRole);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final error = await widget.onSave(_nameCtrl.text, _roleCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: _nameCtrl,
                label: 'Full Name',
                prefixIcon: LucideIcons.userRound,
                validator: (v) =>
                    Validators.minLength(v, 2, fieldName: 'Full name'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _roleCtrl,
                label: 'Role / Specialization',
                prefixIcon: LucideIcons.briefcase,
                validator: (v) =>
                    Validators.requiredField(v, fieldName: 'Role'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Cancel',
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(
                label: 'Save',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.onSave});

  final Future<String?> Function(String currentPassword, String newPassword)
      onSave;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final error = await widget.onSave(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(
                  controller: _currentCtrl,
                  label: 'Current Password',
                  prefixIcon: LucideIcons.lock,
                  obscureText: _obscure,
                  validator: Validators.password,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _newCtrl,
                  label: 'New Password',
                  prefixIcon: LucideIcons.keyRound,
                  obscureText: _obscure,
                  validator: Validators.strongPassword,
                  onChanged: (_) => setState(() {}),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: AppSpacing.iconSm,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                PasswordStrengthIndicator(password: _newCtrl.text),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Confirm New Password',
                  prefixIcon: LucideIcons.shieldCheck,
                  obscureText: _obscure,
                  validator: (v) =>
                      Validators.confirmPassword(v, _newCtrl.text),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Cancel',
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PrimaryButton(
                label: 'Update',
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
