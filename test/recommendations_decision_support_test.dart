import 'package:fixwise/core/errors/failure.dart';
import 'package:fixwise/core/theme/app_theme.dart';
import 'package:fixwise/data/models/decision_support_plan_model.dart';
import 'package:fixwise/data/models/diagnosis_result_model.dart';
import 'package:fixwise/data/models/fault_report_model.dart';
import 'package:fixwise/data/models/feedback_model.dart';
import 'package:fixwise/data/models/recommendation_model.dart';
import 'package:fixwise/data/repositories/diagnosis_repository.dart';
import 'package:fixwise/data/repositories/feedback_repository.dart';
import 'package:fixwise/data/repositories/providers.dart';
import 'package:fixwise/features/recommendations/presentation/screens/recommendations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubDiagnosisWithPlanRepo implements DiagnosisRepository {
  _StubDiagnosisWithPlanRepo(this.diagnosis);

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

class _CapturingFeedbackRepo implements FeedbackRepository {
  final List<FeedbackModel> saved = [];

  @override
  Future<Result<List<FeedbackModel>>> getFeedbackForReport(
    String reportId,
  ) async =>
      Success(saved);

  @override
  Future<Result<FeedbackModel>> submitFeedback(FeedbackModel feedback) async {
    saved.add(feedback);
    return Success(feedback);
  }
}

void main() {
  testWidgets(
      'Recommended Actions displays safe plan with unchecked checkboxes and saves feedback against diagnosis ID',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const step1 = RecommendationModel(
      id: 'chk_1',
      stepNumber: 1,
      title: 'Verify thermostat mode',
      description: 'Confirm unit is set to Cool mode.',
      priority: 'low',
      riskLevel: RecommendationRiskLevel.safe,
      isCheckable: true,
      estimatedMinutes: 2,
    );
    const step2 = RecommendationModel(
      id: 'step_2',
      stepNumber: 2,
      title: 'Schedule HVAC service',
      description: 'Contact a licensed HVAC technician if issue persists.',
      priority: 'medium',
      riskLevel: RecommendationRiskLevel.caution,
      isCheckable: false,
      estimatedMinutes: 45,
    );

    const plan = DecisionSupportPlanModel(
      diagnosisId: 'diag_ac_100',
      reportId: 'rep_ac_100',
      predictedFault: 'Airflow Restriction or Low Cooling Efficiency',
      deviceCategory: 'air_conditioner',
      deviceName: 'Daikin Split AC',
      severity: DecisionSeverityLevel.safe,
      severityRationale: 'Low-risk checks are appropriate.',
      isDangerousFault: false,
      likelyCause: 'Clogged return air filter or thermostat mode mismatch.',
      firstRecommendedCheck: step1,
      recommendations: [step1, step2],
      safetyWarnings: ['Turn unit off before rinsing removable filter.'],
      escalation: EscalationGuidanceModel(
        requiresTechnician: false,
        stopUsingDevice: false,
        whenToEscalate: 'Contact a licensed HVAC technician if coils ice up.',
      ),
      expertReviewStatus: 'reviewed',
      knowledgeBaseRecordId: 'kb_ac_airflow_cooling',
    );

    final diagnosis = DiagnosisResultModel(
      id: 'diag_ac_100',
      reportId: 'rep_ac_100',
      primaryFault: plan.predictedFault,
      summary: 'Reviewed summary.',
      modelVersion: '1.0.0',
      analyzedAt: DateTime(2026),
      recommendations: plan.recommendations,
      decisionSupportPlan: plan,
    );

    final feedbackRepo = _CapturingFeedbackRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diagnosisRepositoryProvider
              .overrideWithValue(_StubDiagnosisWithPlanRepo(diagnosis)),
          feedbackRepositoryProvider.overrideWithValue(feedbackRepo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RecommendationsScreen(reportId: 'rep_ac_100'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recommended Actions'), findsWidgets);
    expect(find.text('Likely Cause'), findsOneWidget);
    expect(find.text('First Recommended Check'), findsOneWidget);
    expect(find.text('Step-by-Step Guidance'), findsOneWidget);
    expect(find.text('Safety Information'), findsOneWidget);
    expect(find.text('When to Contact a Qualified Technician'), findsOneWidget);

    // Safe step checkbox must NOT be auto-completed
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.isNotEmpty, isTrue);
    expect(checkboxes.every((cb) => cb.value == false), isTrue);

    // Manually check off step 1
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).value,
      isTrue,
    );

    // Answer feedback questions & submit
    await tester.ensureVisible(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    final yesChips = find.text('Yes');
    final noChips = find.text('No');
    await tester.tap(yesChips.at(0));
    await tester.tap(yesChips.at(1));
    await tester.tap(noChips.at(2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit Feedback'));
    await tester.pumpAndSettle();

    expect(feedbackRepo.saved.length, 1);
    expect(feedbackRepo.saved.first.diagnosisId, 'diag_ac_100');
    expect(feedbackRepo.saved.first.wasHelpful, isTrue);
    expect(feedbackRepo.saved.first.wasIssueResolved, isTrue);
    expect(feedbackRepo.saved.first.stillNeedsProfessionalAssistance, isFalse);
  });

  testWidgets(
      'Dangerous fault shows warning banner and exposes zero DIY completion checkboxes',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const safetyStep = RecommendationModel(
      id: 'safety_1',
      stepNumber: 1,
      title: 'Stop using the device immediately',
      description: 'Unplug safely and isolate on a non-flammable surface.',
      priority: 'high',
      riskLevel: RecommendationRiskLevel.high,
      isCheckable: false,
    );

    const plan = DecisionSupportPlanModel(
      diagnosisId: 'diag_hazard_1',
      reportId: 'rep_hazard_1',
      predictedFault: 'Swollen Battery Hazard',
      deviceCategory: 'smartphone',
      deviceName: 'Smartphone',
      severity: DecisionSeverityLevel.high,
      severityRationale: 'Elevated to High risk by safety rules.',
      isDangerousFault: true,
      immediateSafetyBanner:
          'High-Risk Safety Warning: Stop using this device immediately.',
      likelyCause: 'Internal lithium-ion gas buildup.',
      firstRecommendedCheck: safetyStep,
      recommendations: [safetyStep],
      safetyWarnings: ['Do not puncture or press the swollen battery.'],
      escalation: EscalationGuidanceModel(
        requiresTechnician: true,
        stopUsingDevice: true,
        whenToEscalate: 'Immediate qualified technician intervention required.',
        emergencyGuidance:
            'If smoking or hissing, evacuate and contact emergency services.',
      ),
      expertReviewStatus: 'reviewed',
    );

    final diagnosis = DiagnosisResultModel(
      id: 'diag_hazard_1',
      reportId: 'rep_hazard_1',
      primaryFault: plan.predictedFault,
      summary: 'High-risk hazard.',
      modelVersion: '1.0.0',
      analyzedAt: DateTime(2026),
      recommendations: plan.recommendations,
      decisionSupportPlan: plan,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diagnosisRepositoryProvider
              .overrideWithValue(_StubDiagnosisWithPlanRepo(diagnosis)),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RecommendationsScreen(reportId: 'rep_hazard_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('High-Risk Safety Warning'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('emergency services'), findsWidgets);
  });
}
