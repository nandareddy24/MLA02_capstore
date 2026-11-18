import 'package:fixwise/app.dart';
import 'package:fixwise/core/constants/app_constants.dart';
import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/data/models/device_model.dart';
import 'package:fixwise/data/models/diagnosis_result_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/models/user_profile_model.dart';
import 'package:fixwise/data/repositories/auth_repository.dart';
import 'package:fixwise/data/repositories/device_repository.dart';
import 'package:fixwise/data/repositories/diagnosis_repository.dart';
import 'package:fixwise/data/repositories/fault_report_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedInAuthRepo implements AuthRepository {
  @override
  Future<Result<SessionRestoreResult>> restoreSession() async {
    return Success(
      SessionRestoreResult(
        user: UserProfileModel(
          id: 'usr_sarah',
          fullName: 'Sarah Menon',
          email: 'sarah@fixwise.io',
          role: 'Maintenance Lead',
          createdAt: DateTime(2026),
        ),
      ),
    );
  }

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
  Future<Result<UserProfileModel>> updateProfile({
    required String fullName,
    required String role,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<String>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> signOut() async => const Success(null);
}

class _FakeDiagnosisRepo implements DiagnosisRepository {
  _FakeDiagnosisRepo({
    this.records = const [],
    this.shouldFail = false,
  });

  List<RecentDiagnosisRecord> records;
  bool shouldFail;

  @override
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(
    String reportId,
  ) async =>
      const Success(null);

  @override
  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  }) async {
    if (shouldFail) {
      return const ErrorResult(
        CacheFailure('Unable to query local diagnosis database.'),
      );
    }
    return Success(records.take(limit).toList());
  }

  @override
  Future<Result<PaginatedHistoryResult>> queryHistory(
    HistoryQuery query,
  ) async =>
      Success(
        PaginatedHistoryResult(
          items: const [],
          totalCount: 0,
          page: query.page,
          pageSize: query.pageSize,
          hasMore: false,
        ),
      );

  @override
  Future<Result<DiagnosisResultModel>> runDiagnosis(
    FaultReportModel report,
  ) async =>
      const ErrorResult(ModelNotIntegratedFailure());
}

class _EmptyDeviceRepo implements DeviceRepository {
  @override
  Future<Result<List<DeviceModel>>> getAllDevices() async => const Success([]);

  @override
  Future<Result<DeviceModel?>> getDeviceById(String id) async =>
      const Success(null);

  @override
  Future<Result<DeviceModel>> createDevice(DeviceModel device) async =>
      Success(device);

  @override
  Future<Result<void>> deleteDevice(String id) async => const Success(null);
}

class _EmptyReportRepo implements FaultReportRepository {
  @override
  Future<Result<List<FaultReportModel>>> getAllReports() async =>
      const Success([]);

  @override
  Future<Result<FaultReportModel?>> getReportById(String id) async =>
      const Success(null);

  @override
  Future<Result<FaultReportModel>> createReport(
    FaultReportModel report,
  ) async =>
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

Future<Widget> _buildTestApp({
  required DiagnosisRepository diagnosisRepo,
}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.prefOnboardingCompleted: true,
  });
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(_SignedInAuthRepo()),
      diagnosisRepositoryProvider.overrideWithValue(diagnosisRepo),
      deviceRepositoryProvider.overrideWithValue(_EmptyDeviceRepo()),
      faultReportRepositoryProvider.overrideWithValue(_EmptyReportRepo()),
    ],
    child: const FixWiseApp(),
  );
}

void main() {
  testWidgets(
      'Home dashboard displays greeting, primary CTA, quick access, and empty state on compact Android (360x740)',
      (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final app = await _buildTestApp(diagnosisRepo: _FakeDiagnosisRepo());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('FixWise'), findsOneWidget);
    expect(find.text('SM'), findsOneWidget);
    expect(find.textContaining('Sarah'), findsOneWidget);
    expect(
      find.text('What would you like to diagnose today?'),
      findsOneWidget,
    );
    expect(find.text('Diagnose a Device'), findsOneWidget);
    expect(find.text('Start Diagnosis'), findsOneWidget);

    expect(find.text('New Diagnosis'), findsOneWidget);
    expect(find.text('Diagnosis History'), findsOneWidget);
    expect(find.text('Help & Guidance'), findsOneWidget);

    expect(find.text('No diagnosis records yet.'), findsOneWidget);
    expect(
      find.text('Your completed diagnoses will appear here.'),
      findsOneWidget,
    );

    // Fixed Material 3 NavigationBar with all 4 destinations
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Diagnose'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Help & Guidance sheet works
    await tester.ensureVisible(find.text('Help & Guidance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & Guidance'));
    await tester.pumpAndSettle();
    expect(find.text('Help & Diagnostic Guidance'), findsOneWidget);
    await tester.ensureVisible(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Bottom navigation switches tabs cleanly
    await tester.tap(find.text('Diagnose'));
    await tester.pumpAndSettle();
    expect(find.text('Select Your Device'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No diagnosis records available.'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnose a Device'), findsOneWidget);
  });

  testWidgets(
      'Home dashboard displays latest 3 completed diagnosis records on standard Android (412x915)',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeDiagnosisRepo(
      records: [
        RecentDiagnosisRecord(
          diagnosisId: 'd1',
          reportId: 'r1',
          deviceName: 'Chiller Unit A1',
          predictedFault: 'Condenser Fan Motor Bearing Wear',
          severity: FaultSeverity.high,
          confidence: 0.87,
          diagnosedAt: DateTime(2026, 11, 18),
        ),
        RecentDiagnosisRecord(
          diagnosisId: 'd2',
          reportId: 'r2',
          deviceName: 'Pump Station B4',
          predictedFault: 'Intake Valve Pressure Loss',
          severity: FaultSeverity.critical,
          confidence: 0.91,
          diagnosedAt: DateTime(2026, 11, 17),
        ),
        RecentDiagnosisRecord(
          diagnosisId: 'd3',
          reportId: 'r3',
          deviceName: 'Backup Inverter C2',
          predictedFault: 'Thermal Sensor Calibration Drift',
          severity: FaultSeverity.low,
          confidence: 0.78,
          diagnosedAt: DateTime(2026, 11, 16),
        ),
      ],
    );

    final app = await _buildTestApp(diagnosisRepo: repo);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.text('Chiller Unit A1'), findsOneWidget);
    expect(find.text('Condenser Fan Motor Bearing Wear'), findsOneWidget);
    expect(find.text('Pump Station B4'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);
    expect(find.text('Backup Inverter C2'), findsOneWidget);
    expect(find.text('View details'), findsNWidgets(3));
  });

  testWidgets(
      'Home dashboard shows error state with working retry and adapts to Android tablet (840x1080)',
      (tester) async {
    tester.view.physicalSize = const Size(840, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeDiagnosisRepo(shouldFail: true);
    final app = await _buildTestApp(diagnosisRepo: repo);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Wide Android tablet uses NavigationRail
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Unable to load recent diagnoses'), findsOneWidget);

    // Retry recovers cleanly
    repo.shouldFail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('No diagnosis records yet.'), findsOneWidget);
  });
}
