import 'package:dio/dio.dart';
import 'package:fixwise/core/errors/app_exception.dart';
import 'package:fixwise/core/errors/error_mapper.dart';
import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/core/theme/app_theme.dart';
import 'package:fixwise/core/utilities/validators.dart';
import 'package:fixwise/data/models/diagnosis_result_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/models/feedback_model.dart';
import 'package:fixwise/data/models/user_profile_model.dart';
import 'package:fixwise/data/repositories/auth_repository.dart';
import 'package:fixwise/data/repositories/diagnosis_repository.dart';
import 'package:fixwise/data/repositories/fault_report_repository.dart';
import 'package:fixwise/data/repositories/feedback_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:fixwise/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:fixwise/features/authentication/presentation/screens/login_screen.dart';
import 'package:fixwise/features/authentication/presentation/screens/register_screen.dart';
import 'package:fixwise/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:fixwise/features/feedback/presentation/screens/feedback_screen.dart';
import 'package:fixwise/features/history/presentation/screens/history_screen.dart';
import 'package:fixwise/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _QaAuthRepo implements AuthRepository {
  _QaAuthRepo({this.user, this.signInFailure});

  final UserProfileModel? user;
  final Failure? signInFailure;

  @override
  Future<Result<SessionRestoreResult>> restoreSession() async =>
      Success(SessionRestoreResult(user: user));

  @override
  Future<Result<AuthFlowResult>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    if (signInFailure != null) return ErrorResult(signInFailure!);
    return Success(AuthFlowResult(user: user));
  }

  @override
  Future<Result<AuthFlowResult>> register({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) async =>
      const ErrorResult(
        AuthFailure('Email already exists.', code: 'EMAIL_EXISTS'),
      );

  @override
  Future<Result<String>> sendOtp({
    required String email,
    required String purpose,
  }) async =>
      const Success('Verification code sent.');

  @override
  Future<Result<AuthFlowResult>> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) async =>
      const ErrorResult(
        AuthFailure('Invalid verification code.', code: 'INVALID_OTP'),
      );

  @override
  Future<Result<String>> requestPasswordReset({required String email}) async =>
      const Success('Reset code sent.');

  @override
  Future<Result<String>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async =>
      const Success('Password reset.');

  @override
  Future<Result<UserProfileModel>> updateProfile({
    required String fullName,
    required String role,
  }) async =>
      Success(user!.copyWith(fullName: fullName, role: role));

  @override
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      const Success('Password updated.');

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

class _QaReportRepo implements FaultReportRepository {
  _QaReportRepo(this.reports);
  final List<FaultReportModel> reports;

  @override
  Future<Result<List<FaultReportModel>>> getAllReports() async =>
      Success(reports);

  @override
  Future<Result<FaultReportModel?>> getReportById(String id) async {
    for (final r in reports) {
      if (r.id == id) return Success(r);
    }
    return const Success(null);
  }

  @override
  Future<Result<FaultReportModel>> createReport(FaultReportModel report) async =>
      Success(report);

  @override
  Future<Result<void>> updateReportStatus(
    String reportId,
    FaultReportStatus status,
  ) async =>
      const Success(null);

  @override
  Future<Result<void>> deleteReport(String id) async => const Success(null);
}

class _QaDiagnosisRepo implements DiagnosisRepository {
  _QaDiagnosisRepo(this.items);
  final List<HistoryListItem> items;

  @override
  Future<Result<DiagnosisResultModel>> runDiagnosis(
    FaultReportModel report,
  ) async =>
      const ErrorResult(ModelNotIntegratedFailure());

  @override
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(
    String reportId,
  ) async =>
      const Success(null);

  @override
  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  }) async {
    return Success(
      items
          .take(limit)
          .map(
            (i) => RecentDiagnosisRecord(
              diagnosisId: i.diagnosisId ?? 'diag_${i.reportId}',
              reportId: i.reportId,
              deviceName: i.deviceName,
              predictedFault: i.predictedFault,
              severity: i.severity,
              diagnosedAt: i.diagnosedAt,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<Result<PaginatedHistoryResult>> queryHistory(
    HistoryQuery query,
  ) async {
    const pageSize = 20;
    final start = (query.page - 1) * pageSize;
    final pageItems = start < items.length
        ? items.skip(start).take(pageSize).toList()
        : <HistoryListItem>[];
    return Success(
      PaginatedHistoryResult(
        items: pageItems,
        totalCount: items.length,
        page: query.page,
        pageSize: pageSize,
        hasMore: (start + pageItems.length) < items.length,
      ),
    );
  }
}

class _FailingFeedbackRepo implements FeedbackRepository {
  @override
  Future<Result<List<FeedbackModel>>> getFeedbackForReport(
    String reportId,
  ) async =>
      const Success([]);

  @override
  Future<Result<FeedbackModel>> submitFeedback(FeedbackModel feedback) async =>
      const ErrorResult(
        NetworkFailure('Unable to reach server while submitting feedback.'),
      );
}

void main() {
  final sampleUser = UserProfileModel(
    id: 'usr_qa_01',
    fullName: 'QA Engineer',
    email: 'qa@fixwise.io',
    role: 'Field Technician',
    createdAt: DateTime(2026, 1, 1),
  );

  group('QA Section 3: Error Mapping & Recovery Matrix', () {
    test(
      'maps internet disconnect, timeout, backend unavailable, 401, and 503 accurately',
      () {
        final req = RequestOptions(path: '/api/v1/diagnosis/analyze');

        final offline = ErrorMapper.mapException(
          DioException(
            requestOptions: req,
            type: DioExceptionType.connectionError,
          ),
        );
        expect(offline, isA<NetworkFailure>());
        expect(offline.code, 'CONNECTION_ERROR');

        final timeout = ErrorMapper.mapException(
          DioException(
            requestOptions: req,
            type: DioExceptionType.receiveTimeout,
          ),
        );
        expect(timeout, isA<NetworkFailure>());
        expect(timeout.code, 'TIMEOUT');

        final expired = ErrorMapper.mapException(
          DioException(
            requestOptions: req,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req, statusCode: 401),
          ),
        );
        expect(expired, isA<AuthFailure>());
        expect(expired.code, 'HTTP_401');

        final unavailable = ErrorMapper.mapException(
          const ServiceUnavailableException('Backend unreachable.'),
        );
        expect(unavailable, isA<ModelNotIntegratedFailure>());
      },
    );

    test('validates malformed error codes and empty form inputs', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.password(''), isNotNull);
      expect(Validators.strongPassword('weak'), isNotNull);
      expect(Validators.otpCode('12ab'), isNotNull);
      expect(Validators.optionalErrorCode('A' * 100), isNotNull);
      expect(Validators.optionalErrorCode('<script>alert(1)</script>'), isNotNull);
      expect(Validators.optionalErrorCode('E-404_BAT'), isNull);
    });

    testWidgets(
      'empty Login, Register, and Forgot Password render cleanly on compact 320x640',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(
                _QaAuthRepo(
                  signInFailure: const AuthFailure(
                    'Invalid email or password.',
                    code: 'INVALID_CREDENTIALS',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const LoginScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Login'));
        await tester.tap(find.text('Login'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Email address'), findsWidgets);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(_QaAuthRepo()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const RegisterScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(_QaAuthRepo()),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const ForgotPasswordScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed feedback submission preserves user input and displays recovery error',
      (tester) async {
        SharedPreferences.setMockInitialValues({'active_user_id': sampleUser.id});
        final prefs = await SharedPreferences.getInstance();

        await tester.binding.setSurfaceSize(const Size(360, 780));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              feedbackRepositoryProvider.overrideWithValue(_FailingFeedbackRepo()),
              diagnosisRepositoryProvider.overrideWithValue(_QaDiagnosisRepo([])),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const FeedbackScreen(reportId: 'rep_fail_01'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Yes'));
        await tester.tap(find.text('Yes'));
        await tester.ensureVisible(find.text('Not resolved'));
        await tester.tap(find.text('Not resolved'));
        await tester.ensureVisible(find.byType(TextFormField));
        await tester.enterText(
          find.byType(TextFormField),
          'Still overheating after basic checks.',
        );
        await tester.ensureVisible(find.text('Submit Feedback'));
        await tester.tap(find.text('Submit Feedback'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Unable to reach server'), findsOneWidget);
        expect(
          find.text('Still overheating after basic checks.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('QA Sections 2 & 4: Dark Mode, Small-Screen & Large History Performance', () {
    testWidgets(
      'Dark mode renders Dashboard, History (120 paginated records), and Profile cleanly',
      (tester) async {
        SharedPreferences.setMockInitialValues({'active_user_id': sampleUser.id});
        final prefs = await SharedPreferences.getInstance();

        final now = DateTime(2026, 6, 1, 12, 0);
        final largeItems = List.generate(
          120,
          (i) => HistoryListItem(
            reportId: 'rep_perf_$i',
            diagnosisId: 'diag_perf_$i',
            deviceName: i.isEven ? 'ThinkPad T14 #$i' : 'Galaxy S23 #$i',
            deviceCategory: i.isEven ? 'laptop' : 'smartphone',
            predictedFault: i.isEven
                ? 'Thermal Management Fault'
                : 'Battery Degradation',
            severity: i % 3 == 0 ? FaultSeverity.high : FaultSeverity.low,
            status: FaultReportStatus.diagnosed,
            diagnosedAt: now.subtract(Duration(hours: i)),
            hasFeedback: false,
          ),
        );

        await tester.binding.setSurfaceSize(const Size(360, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 1. Dark Mode Dashboard
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(
                _QaAuthRepo(user: sampleUser),
              ),
              faultReportRepositoryProvider.overrideWithValue(
                _QaReportRepo([]),
              ),
              diagnosisRepositoryProvider.overrideWithValue(
                _QaDiagnosisRepo(largeItems),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.dark,
              home: const DashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Diagnose a Device'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // 2. Dark Mode History with 120 items (lazy paginated rendering)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(
                _QaAuthRepo(user: sampleUser),
              ),
              faultReportRepositoryProvider.overrideWithValue(
                _QaReportRepo([]),
              ),
              diagnosisRepositoryProvider.overrideWithValue(
                _QaDiagnosisRepo(largeItems),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.dark,
              home: const HistoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Showing 20 of 120 records'), findsOneWidget);
        expect(find.text('Thermal Management Fault'), findsWidgets);
        expect(tester.takeException(), isNull);

        // 3. Dark Mode Profile
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('dark-profile-scope'),
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(
                _QaAuthRepo(user: sampleUser),
              ),
              faultReportRepositoryProvider.overrideWithValue(
                _QaReportRepo([]),
              ),
              diagnosisRepositoryProvider.overrideWithValue(
                _QaDiagnosisRepo(largeItems),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.dark,
              home: const ProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('QA Engineer'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
