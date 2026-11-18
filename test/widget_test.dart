import 'package:fixwise/app.dart';
import 'package:fixwise/core/constants/app_constants.dart';
import 'package:fixwise/core/constants/app_routes.dart';
import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/core/routing/app_router.dart';
import 'package:fixwise/core/theme/app_colors.dart';
import 'package:fixwise/core/theme/app_spacing.dart';
import 'package:fixwise/core/theme/app_theme.dart';
import 'package:fixwise/core/theme/app_typography.dart';
import 'package:fixwise/core/utilities/validators.dart';
import 'package:fixwise/core/widgets/app_confirmation_dialog.dart';
import 'package:fixwise/core/widgets/device_card.dart';
import 'package:fixwise/core/widgets/primary_button.dart';
import 'package:fixwise/core/widgets/secondary_button.dart';
import 'package:fixwise/core/widgets/severity_indicator.dart';
import 'package:fixwise/core/widgets/symptom_chip.dart';
import 'package:fixwise/data/models/device_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/models/user_profile_model.dart';
import 'package:fixwise/data/repositories/auth_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:fixwise/features/authentication/presentation/screens/otp_verification_screen.dart';
import 'package:fixwise/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestBackendAuthRepository implements AuthRepository {
  _TestBackendAuthRepository({
    this.wasExpired = false,
  });

  final bool wasExpired;
  int resendCount = 0;

  @override
  Future<Result<SessionRestoreResult>> restoreSession() async {
    return Success(
      SessionRestoreResult(wasExpired: wasExpired),
    );
  }

  @override
  Future<Result<AuthFlowResult>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    return Success(
      AuthFlowResult(
        user: UserProfileModel(
          id: 'usr_1',
          fullName: 'Priya Sharma',
          email: email,
          role: 'Field Technician',
          createdAt: DateTime(2026),
        ),
      ),
    );
  }

  @override
  Future<Result<AuthFlowResult>> register({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async {
    return Success(
      AuthFlowResult(
        requiresOtpVerification: true,
        email: email,
        message: 'Verification code sent.',
      ),
    );
  }

  @override
  Future<Result<String>> sendOtp({
    required String email,
    required String purpose,
  }) async {
    resendCount += 1;
    return const Success('A new verification code has been sent.');
  }

  @override
  Future<Result<AuthFlowResult>> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async {
    if (code == '000000') {
      return const ErrorResult(
        AuthFailure(
          'This verification code has expired. Please request a new code.',
          code: 'OTP_EXPIRED',
        ),
      );
    }
    return Success(
      AuthFlowResult(
        user: UserProfileModel(
          id: 'usr_verified',
          fullName: 'Verified Technician',
          email: email,
          role: 'Field Technician',
          createdAt: DateTime(2026),
        ),
        message: 'Email verified successfully.',
      ),
    );
  }

  @override
  Future<Result<String>> requestPasswordReset({required String email}) async {
    return Success('Reset code sent to $email.');
  }

  @override
  Future<Result<String>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return const Success('Password updated successfully.');
  }

  @override
  Future<Result<UserProfileModel>> updateProfile({
    required String fullName,
    required String role,
  }) async =>
      Success(
        UserProfileModel(
          id: 'usr_1',
          fullName: fullName,
          email: 'tech@fixwise.io',
          role: role,
          createdAt: DateTime(2026),
        ),
      );

  @override
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      const Success('Password changed.');

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

void main() {
  test('Design system exposes exact FixWise palette, Inter font, and dimensions',
      () {
    expect(AppColors.primary, const Color(0xFF123B46));
    expect(AppColors.secondary, const Color(0xFF176B68));
    expect(AppColors.background, const Color(0xFFF5F7F7));
    expect(AppColors.cardBackground, const Color(0xFFFFFFFF));
    expect(AppColors.primaryText, const Color(0xFF172B32));
    expect(AppColors.secondaryText, const Color(0xFF66767B));
    expect(AppColors.border, const Color(0xFFE3E9E9));
    expect(AppColors.disabled, const Color(0xFFAAB5B8));
    expect(AppColors.safe, const Color(0xFF27845B));
    expect(AppColors.warning, const Color(0xFFC58A27));
    expect(AppColors.dangerous, const Color(0xFFC74747));
    expect(AppColors.information, const Color(0xFF3978AD));

    final light = AppTheme.light;
    expect(light.textTheme.headlineMedium?.fontFamily, AppTypography.primaryFontFamily);
    expect(light.textTheme.headlineMedium?.fontFamilyFallback, const ['Roboto']);
    expect(light.textTheme.headlineMedium?.fontSize, 26);
    expect(light.textTheme.titleLarge?.fontSize, 18);
    expect(light.textTheme.titleMedium?.fontSize, 16);
    expect(light.textTheme.bodyMedium?.fontSize, 14);
    expect(light.textTheme.bodySmall?.fontSize, 12);
    expect(light.textTheme.labelLarge?.fontSize, 15);
    expect(AppSpacing.screenHorizontal, 20);
    expect(AppSpacing.cardRadius, 14);
    expect(AppSpacing.inputRadius, 10);
    expect(AppSpacing.primaryButtonHeight, 52);
    expect(AppSpacing.secondaryButtonHeight, 48);
    expect(AppSpacing.inputHeight, 54);
  });

  testWidgets('Splash screen displays logo, title, subtitle, and #F5F7F7 bg', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, const Color(0xFFF5F7F7));
    expect(find.text('FixWise'), findsOneWidget);
    expect(find.text('Device Diagnostics & Decision Support'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Three-step onboarding completes and transitions to Login screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider
              .overrideWithValue(_TestBackendAuthRepository()),
        ],
        child: const FixWiseApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Report Your Device Problem'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Understand Possible Faults'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Get Recommended Actions'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets(
      'Unauthenticated users cannot navigate directly to protected Dashboard',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefOnboardingCompleted: true,
    });
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(
          _TestBackendAuthRepository(wasExpired: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FixWiseApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Your previous session has expired. Please sign in again.'),
      findsOneWidget,
    );

    container.read(appRouterProvider).go(AppRoutes.dashboard);
    await tester.pumpAndSettle();

    // Guard forces redirect back to Login.
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('OTP verification displays 6-digit boxes and handles expired code',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefOnboardingCompleted: true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider
              .overrideWithValue(_TestBackendAuthRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OtpVerificationScreen(email: 'tech@fixwise.io'),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.textContaining('Resend code available in'), findsOneWidget);

    // Paste an expired code into the first digit box.
    await tester.enterText(find.byType(TextField).first, '000000');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This verification code has expired. Please request a new code.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Core design system components render and respond to actions', (
    tester,
  ) async {
    var symptomSelected = false;
    var dialogConfirmed = false;

    final device = DeviceModel(
      id: 'dev_1',
      name: 'Chiller Unit A1',
      category: DeviceCategory.hvac,
      manufacturer: 'Carrier',
      modelNumber: 'XR-900',
      location: 'Plant 2',
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    DeviceCard(device: device, onTap: () {}),
                    const SizedBox(height: 12),
                    const SeverityIndicator(severity: FaultSeverity.critical),
                    const SizedBox(height: 12),
                    SymptomChip(
                      label: 'Overheating',
                      selected: symptomSelected,
                      onSelected: (v) => setState(() => symptomSelected = v),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Open Dialog',
                      onPressed: () async {
                        dialogConfirmed = await AppConfirmationDialog.show(
                          context,
                          title: 'Delete Case',
                          message: 'Confirm permanent deletion.',
                          confirmLabel: 'Delete',
                          isDangerous: true,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(label: 'Secondary', onPressed: () {}),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.text('Chiller Unit A1'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);

    await tester.tap(find.text('Overheating'));
    await tester.pumpAndSettle();
    expect(symptomSelected, isTrue);

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Case'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(dialogConfirmed, isTrue);
  });

  test(
      'Real AuthRepository rejects login without configured backend (no fake auth)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(authRepositoryProvider).signIn(
          email: 'any@user.com',
          password: 'Password1!',
          rememberMe: true,
        );

    expect(result.isFailure, isTrue);
    result.when(
      success: (_) => fail('Must not authenticate without a backend service'),
      failure: (failure) {
        expect(failure, isA<AuthFailure>());
        expect(failure.code, 'AUTH_BACKEND_NOT_CONFIGURED');
      },
    );
  });

  test('Diagnosis repository refuses to fabricate predictions when unconfigured',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final report = FaultReportModel(
      id: 'rep_1',
      deviceId: 'dev_1',
      deviceName: 'Compressor Unit',
      title: 'Overheating during load',
      description: 'Unit shuts down after 15 minutes at high load.',
      symptoms: const ['Overheating'],
      severity: FaultSeverity.high,
      status: FaultReportStatus.pendingDiagnosis,
      createdAt: DateTime(2026),
    );

    final result =
        await container.read(diagnosisRepositoryProvider).runDiagnosis(report);

    expect(result.isFailure, isTrue);
    result.when(
      success: (_) => fail('Should not return fabricated diagnosis'),
      failure: (failure) => expect(failure, isA<ModelNotIntegratedFailure>()),
    );
  });

  test('Validators enforce email, strong password, OTP, and URL rules', () {
    expect(Validators.email('not-an-email'), isNotNull);
    expect(Validators.email('tech@fixwise.io'), isNull);

    expect(Validators.strongPassword('weak'), isNotNull);
    expect(Validators.strongPassword('alllowercase1!'), isNotNull);
    expect(Validators.strongPassword('NoNumber!'), isNotNull);
    expect(Validators.strongPassword('NoSpecial1'), isNotNull);
    expect(Validators.strongPassword('StrongP@ss1'), isNull);

    expect(Validators.otpCode('12345'), isNotNull);
    expect(Validators.otpCode('12345a'), isNotNull);
    expect(Validators.otpCode('123456'), isNull);

    expect(Validators.optionalUrl('ftp://invalid'), isNotNull);
    expect(Validators.optionalUrl('https://api.fixwise.io'), isNull);
    expect(Validators.optionalUrl(''), isNull);
  });
}
