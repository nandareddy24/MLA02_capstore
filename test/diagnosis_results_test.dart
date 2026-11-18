import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/core/theme/app_theme.dart';
import 'package:fixwise/data/models/diagnosis_result_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/repositories/diagnosis_repository.dart';
import 'package:fixwise/data/repositories/fault_report_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:fixwise/features/diagnosis/presentation/screens/diagnosis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SingleReportRepo implements FaultReportRepository {
  _SingleReportRepo(this.report);

  final FaultReportModel report;

  @override
  Future<Result<FaultReportModel>> createReport(FaultReportModel r) async =>
      Success(r);

  @override
  Future<Result<void>> deleteReport(String id) async => const Success(null);

  @override
  Future<Result<List<FaultReportModel>>> getAllReports() async =>
      Success([report]);

  @override
  Future<Result<FaultReportModel?>> getReportById(String id) async =>
      Success(id == report.id ? report : null);

  @override
  Future<Result<void>> updateReportStatus(
    String reportId,
    FaultReportStatus status,
  ) async =>
      const Success(null);
}

class _CachedDiagnosisRepo implements DiagnosisRepository {
  _CachedDiagnosisRepo(this.diagnosis);

  final DiagnosisResultModel diagnosis;

  @override
  Future<Result<DiagnosisResultModel?>> getCachedDiagnosis(
    String reportId,
  ) async =>
      Success(diagnosis);

  @override
  Future<Result<List<RecentDiagnosisRecord>>> getRecentDiagnoses({
    int limit = 3,
  }) async =>
      const Success([]);

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
      Success(diagnosis);
}

void main() {
  testWidgets(
      'Diagnosis Results screen displays primary fault, ranked alternatives, evidence, rule-based severity, uncertainty notice, and View Recommendations CTA',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final report = FaultReportModel(
      id: 'rep_101',
      deviceId: 'cat_smartphone',
      deviceName: 'Samsung Galaxy S23 (Smartphone)',
      title: 'Rapid battery drain',
      description: 'Gets warm during normal use.',
      symptoms: const ['Rapid battery drain', 'Overheating during normal use'],
      severity: FaultSeverity.high,
      status: FaultReportStatus.diagnosed,
      errorCode: 'BAT-02',
      createdAt: DateTime(2026, 11, 18, 10, 30),
    );

    final diagnosis = DiagnosisResultModel(
      id: 'diag_101',
      reportId: 'rep_101',
      deviceName: 'Samsung Galaxy S23 (Smartphone)',
      primaryFault: 'Battery Degradation',
      confidence: 0.62,
      confidenceIsCalibrated: true,
      severity: FaultSeverity.high,
      severityRationale:
          'Classified as High severity by decision-support rules due to overheating risk.',
      summary: 'Symptoms align most closely with Battery Degradation.',
      modelVersion: '1.0.0',
      algorithm: 'RandomForestClassifier',
      processingTimeMs: 14.2,
      analyzedAt: DateTime(2026, 11, 18, 10, 31),
      rankedAlternatives: const [
        AlternativeFaultModel(
          faultCategory: 'Charging IC / Power Management Fault',
          probability: 0.54,
        ),
        AlternativeFaultModel(
          faultCategory: 'Thermal Sensor Fault',
          probability: 0.12,
        ),
      ],
      evidence: const [
        DiagnosticEvidenceModel(
          signalType: 'symptom',
          source: 'Reported Symptom',
          detail: 'Rapid battery drain',
        ),
        DiagnosticEvidenceModel(
          signalType: 'error_code',
          source: 'Device Error Code',
          detail: "Reported code 'BAT-02' included in model feature encoding.",
        ),
      ],
      isUncertain: true,
      uncertaintyMessage:
          'Multiple fault categories show similar likelihood based on the reported symptoms.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          faultReportRepositoryProvider
              .overrideWithValue(_SingleReportRepo(report)),
          diagnosisRepositoryProvider
              .overrideWithValue(_CachedDiagnosisRepo(diagnosis)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DiagnosisScreen(reportId: 'rep_101'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Diagnosis Results'), findsWidgets);
    expect(find.text('Battery Degradation'), findsOneWidget);
    expect(find.text('62.0%'), findsOneWidget);
    expect(
      find.text('Estimated Likelihood (not guaranteed accuracy)'),
      findsOneWidget,
    );
    expect(find.text('Diagnostic Uncertainty Notice'), findsOneWidget);
    expect(
      find.textContaining('not a confirmed physical fault'),
      findsOneWidget,
    );
    expect(find.text('Other Possible Causes'), findsOneWidget);
    expect(
      find.text('Charging IC / Power Management Fault'),
      findsOneWidget,
    );
    expect(find.text('Diagnostic Evidence'), findsOneWidget);
    expect(find.text('Rapid battery drain'), findsOneWidget);
    expect(find.text('Severity Assessment'), findsOneWidget);
    expect(
      find.textContaining('decision-support rules'),
      findsOneWidget,
    );
    expect(find.text('View Recommendations'), findsOneWidget);
  });

  test('DiagnosisResultModel hides probability when model is uncalibrated', () {
    final parsed = DiagnosisResultModel.fromJson(
      {
        'diagnosis_id': 'diag_uncal',
        'report_id': 'rep_1',
        'predicted_fault_category': 'Cooling Fan Fault',
        'confidence': 0.91,
        'confidence_is_calibrated': false,
        'severity': 'high',
        'severity_rationale': 'Rule-based severity.',
        'summary': 'Summary text.',
        'model_version': '0.9.0',
      },
      fallbackReportId: 'rep_1',
    );

    expect(parsed.hasCalibratedConfidence, isFalse);
    expect(parsed.confidence, isNull);
    expect(parsed.isUncertain, isTrue);
  });
}
