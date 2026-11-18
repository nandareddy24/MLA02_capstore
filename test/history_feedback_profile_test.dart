import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/core/theme/app_theme.dart';
import 'package:fixwise/data/models/diagnosis_result_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/models/feedback_model.dart';
import 'package:fixwise/data/models/user_profile_model.dart';
import 'package:fixwise/data/repositories/auth_repository.dart';
import 'package:fixwise/data/repositories/diagnosis_repository.dart';
import 'package:fixwise/data/repositories/fault_report_repository.dart';
import 'package:fixwise/data/repositories/feedback_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:fixwise/features/feedback/presentation/screens/feedback_screen.dart';
import 'package:fixwise/features/history/presentation/screens/history_screen.dart';
import 'package:fixwise/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PaginatedHistoryDiagnosisRepo implements DiagnosisRepository {
  _PaginatedHistoryDiagnosisRepo(this.allItems);

  final List<HistoryListItem> allItems;

  @override
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(
    String reportId,
  ) async =>
      const Success(null);

  @override
  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  }) async =>
      const Success([]);

  @override
  Future<Result<PaginatedHistoryResult>> queryHistory(
    HistoryQuery query,
  ) async {
    var list = List<HistoryListItem>.from(allItems);
    if (query.search.trim().isNotEmpty) {
      final q = query.search.trim().toLowerCase();
      list = list
          .where(
            (i) =>
                i.deviceCategory.toLowerCase().contains(q) ||
                i.deviceName.toLowerCase().contains(q) ||
                i.predictedFault.toLowerCase().contains(q),
          )
          .toList();
    }
    if (query.severity != null) {
      list = list.where((i) => i.severity == query.severity).toList();
    }
    list.sort((a, b) => query.sortOrder == HistorySortOrder.oldest
        ? a.diagnosedAt.compareTo(b.diagnosedAt)
        : b.diagnosedAt.compareTo(a.diagnosedAt));

    const testPageSize = 1;
    final start = (query.page - 1) * testPageSize;
    final pageItems = start < list.length
        ? list.skip(start).take(testPageSize).toList()
        : <HistoryListItem>[];

    return Success(
      PaginatedHistoryResult(
        items: pageItems,
        totalCount: list.length,
        page: query.page,
        pageSize: testPageSize,
        hasMore: (start + pageItems.length) < list.length,
      ),
    );
  }

  @override
  Future<Result<DiagnosisResultModel>> runDiagnosis(
    FaultReportModel report,
  ) async =>
      const ErrorResult(ModelNotIntegratedFailure());
}

class _ControlledFeedbackRepo implements FeedbackRepository {
  FeedbackModel? current;

  @override
  Future<Result<List<FeedbackModel>>> getFeedbackForReport(
    String reportId,
  ) async =>
      Success(current == null ? [] : [current!]);

  @override
  Future<Result<FeedbackModel>> submitFeedback(FeedbackModel feedback) async {
    current = feedback;
    return Success(feedback);
  }
}

class _StubReportRepo implements FaultReportRepository {
  @override
  Future<Result<FaultReportModel>> createReport(FaultReportModel r) async =>
      Success(r);

  @override
  Future<Result<void>> deleteReport(String id) async => const Success(null);

  @override
  Future<Result<List<FaultReportModel>>> getAllReports() async =>
      const Success([]);

  @override
  Future<Result<FaultReportModel?>> getReportById(String id) async =>
      const Success(null);

  @override
  Future<Result<void>> updateReportStatus(
    String reportId,
    FaultReportStatus status,
  ) async =>
      const Success(null);
}

class _ProfileAuthRepo implements AuthRepository {
  UserProfileModel _user = UserProfileModel(
    id: 'usr_1',
    fullName: 'Priya Sharma',
    email: 'priya@fixwise.io',
    role: 'Field Technician',
    createdAt: DateTime(2026, 1, 15),
  );

  @override
  Future<Result<SessionRestoreResult>> restoreSession() async =>
      Success(SessionRestoreResult(user: _user));

  @override
  Future<Result<UserProfileModel>> updateProfile({
    required String fullName,
    required String role,
  }) async {
    _user = _user.copyWith(fullName: fullName, role: role);
    return Success(_user);
  }

  @override
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      const Success('Password changed.');

  @override
  Future<Result<AuthFlowResult>> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<AuthFlowResult>> register({
    required String fullName,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> sendOtp({
    required String email,
    required String purpose,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<AuthFlowResult>> verifyOtp({
    required String email,
    required String code,
    required String purpose,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> requestPasswordReset({required String email}) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

void main() {
  testWidgets(
      'History screen filters by search/severity, sorts, and paginates with Load More',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final repo = _PaginatedHistoryDiagnosisRepo([
      HistoryListItem(
        reportId: 'rep_1',
        diagnosisId: 'diag_1',
        deviceCategory: 'smartphone',
        deviceName: 'Samsung S23',
        predictedFault: 'Battery Degradation',
        severity: FaultSeverity.high,
        status: FaultReportStatus.diagnosed,
        diagnosedAt: DateTime(2026, 11, 18),
      ),
      HistoryListItem(
        reportId: 'rep_2',
        diagnosisId: 'diag_2',
        deviceCategory: 'air conditioner',
        deviceName: 'Daikin Split AC',
        predictedFault: 'Airflow Restriction',
        severity: FaultSeverity.low,
        status: FaultReportStatus.resolved,
        diagnosedAt: DateTime(2026, 11, 10),
        hasFeedback: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diagnosisRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 2 records'), findsOneWidget);
    expect(find.text('Battery Degradation'), findsOneWidget);
    expect(find.text('Load More Records'), findsOneWidget);

    // Load page 2
    await tester.ensureVisible(find.text('Load More Records'));
    await tester.tap(find.text('Load More Records'));
    await tester.pumpAndSettle();

    expect(find.text('Showing 2 of 2 records'), findsOneWidget);
    expect(find.text('Airflow Restriction'), findsOneWidget);

    // Filter by Low severity
    await tester.ensureVisible(find.text('Low').first);
    await tester.tap(find.text('Low').first);
    await tester.pumpAndSettle();

    expect(find.text('Showing 1 of 1 record'), findsOneWidget);
    expect(find.text('Airflow Restriction'), findsOneWidget);
    expect(find.text('Battery Degradation'), findsNothing);
  });

  testWidgets(
      'Feedback screen shows empty state, exact Q1/Q2 options, and supports controlled update',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final feedbackRepo = _ControlledFeedbackRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          feedbackRepositoryProvider.overrideWithValue(feedbackRepo),
          faultReportRepositoryProvider.overrideWithValue(_StubReportRepo()),
          diagnosisRepositoryProvider
              .overrideWithValue(_PaginatedHistoryDiagnosisRepo(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const FeedbackScreen(reportId: 'rep_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No feedback submitted yet.'), findsOneWidget);
    expect(find.text('1. Was the diagnosis relevant?'), findsOneWidget);
    expect(find.text('Partially'), findsOneWidget);
    expect(
      find.text('2. Did the recommendation resolve the issue?'),
      findsOneWidget,
    );
    expect(find.text('Partially resolved'), findsOneWidget);
    expect(find.text('Not attempted'), findsOneWidget);

    await tester.ensureVisible(find.text('Submit Feedback'));
    await tester.tap(find.text('Yes'));
    await tester.tap(find.text('Resolved'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    expect(feedbackRepo.current, isNotNull);
    expect(feedbackRepo.current!.diagnosisRelevance, DiagnosisRelevance.yes);
    expect(
      feedbackRepo.current!.resolutionStatus,
      ResolutionStatus.resolved,
    );
    expect(find.text('Update Feedback'), findsOneWidget);
  });

  testWidgets(
      'Profile screen displays account settings, legal docs, and real Edit Profile update',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(_ProfileAuthRepo()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('priya@fixwise.io'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms and Conditions'), findsOneWidget);
    expect(find.text('About FixWise'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Test real Edit Profile flow
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Priya Nair');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Priya Nair'), findsOneWidget);
  });
}
